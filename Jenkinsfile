pipeline {

    agent any

    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"
        SONAR_URL  = "http://sonarqube:9000/sonar"
    }

    stages {

        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Checkout') {
            steps {
                echo "========================================"
                echo "Preparing workspace..."
                echo "Workspace: ${WORKSPACE}"
                echo "========================================"
            }
        }

        stage('Local Check') {
            steps {
                sh '''
                    set -e

                    WORKSPACE_HOST="/var/lib/docker/volumes/devops-lab_jenkins_home/_data/workspace/$(basename "$WORKSPACE")"

                    echo "Running local checks..."
                    echo "Workspace: $WORKSPACE_HOST"

                    docker run --rm \
                      -v "$WORKSPACE_HOST:/workspace" \
                      -w /workspace \
                      python:3.14-slim \
                      sh -c '
                        set -e
                        pip install --no-cache-dir -r app/requirements-dev.txt
                        ruff check app/
                        cd app
                        pytest -v
                      '
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {

                withCredentials([
                    string(
                        credentialsId: 'SONAR_TOKEN',
                        variable: 'SONAR_TOKEN'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "========================================"
                        echo "Running SonarQube analysis..."
                        echo "========================================"

                        echo "Workspace: ${WORKSPACE}"
                        echo "SonarQube URL: ${SONAR_URL}"
                        echo "Project: devops-lab-app"

                        rm -rf "${WORKSPACE}/.scannerwork"
                        rm -f "${WORKSPACE}/report-task.txt"

                        echo "Starting SonarScanner..."

                        JENKINS_CONTAINER_ID="$(docker ps -q -f name=^jenkins$)"

                        if [ -z "$JENKINS_CONTAINER_ID" ]; then
                            echo "ERROR: Jenkins container was not found."
                            exit 1
                        fi

                        docker run --rm \
                          --user 0:0 \
                          --network devops-lab_default \
                          --volumes-from "$JENKINS_CONTAINER_ID" \
                          -w "${WORKSPACE}" \
                          -e SONAR_TOKEN="$SONAR_TOKEN" \
                          sonarsource/sonar-scanner-cli:latest \
                          -Dsonar.projectKey=devops-lab-app \
                          -Dsonar.sources=app \
                          -Dsonar.tests=app/tests \
                          -Dsonar.exclusions=app/tests/** \
                          -Dsonar.host.url="$SONAR_URL" \
                          -Dsonar.token="$SONAR_TOKEN" \
                          -Dsonar.python.version=3.14

                        echo "========================================"
                        echo "SonarQube analysis completed."
                        echo "========================================"

                        if [ ! -f "${WORKSPACE}/report-task.txt" ]; then
                            echo "ERROR: report-task.txt was not created."
                            exit 1
                        fi

                        echo "report-task.txt found."
                        echo "SonarQube report:"
                        cat "${WORKSPACE}/report-task.txt"
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build & Push') {
            steps {

                script {

                    def TAG = env.BRANCH_NAME == 'main' ? 'latest' : 'dev'

                    echo "========================================"
                    echo "Building Docker image"
                    echo "Image: ${IMAGE_NAME}:${TAG}"
                    echo "========================================"

                    sh """
                        docker build \
                          -t ${IMAGE_NAME}:${TAG} \
                          ./app
                    """

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-creds',
                            usernameVariable: 'DOCKERHUB_USER',
                            passwordVariable: 'DOCKERHUB_PASS'
                        )
                    ]) {

                        sh '''
                            echo "$DOCKERHUB_PASS" | docker login \
                                -u "$DOCKERHUB_USER" \
                                --password-stdin
                        '''

                        sh """
                            docker push ${IMAGE_NAME}:${TAG}
                        """
                    }
                }
            }
        }

        stage('Deploy') {
            steps {

                script {

                    def TAG = env.BRANCH_NAME == 'main' ? 'latest' : 'dev'

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-creds',
                            usernameVariable: 'DOCKERHUB_USER',
                            passwordVariable: 'DOCKERHUB_PASS'
                        ),

                        sshUserPrivateKey(
                            credentialsId: 'APP_SSH_KEY',
                            keyFileVariable: 'SSH_KEY'
                        )
                    ]) {

                        sh '''
                            set -e

                            mkdir -p ~/.ssh
                            chmod 700 ~/.ssh
                            chmod 600 "$SSH_KEY"

                            ssh-keyscan -H "$APP_HOST" \
                                >> ~/.ssh/known_hosts 2>/dev/null || true

                            echo "Deploying to $APP_HOST"
                        '''

                        sh """
                            ssh \
                                -o StrictHostKeyChecking=no \
                                -i "\$SSH_KEY" \
                                ec2-user@${APP_HOST} '

                                    set -e

                                    echo "========================================"
                                    echo "Logging into Docker Hub..."
                                    echo "========================================"

                                    echo "${DOCKERHUB_PASS}" | docker login \
                                        -u "${DOCKERHUB_USER}" \
                                        --password-stdin

                                    echo "Stopping old container..."

                                    docker stop devops-lab-app 2>/dev/null || true
                                    docker rm devops-lab-app 2>/dev/null || true

                                    echo "Pulling new image..."

                                    docker pull ${IMAGE_NAME}:${TAG}

                                    echo "Starting new container..."

                                    docker run -d \
                                        --name devops-lab-app \
                                        --restart unless-stopped \
                                        -p 5000:5000 \
                                        ${IMAGE_NAME}:${TAG}

                                    echo "Waiting for application..."

                                    sleep 5

                                    echo "Checking application health..."

                                    if curl -sf http://localhost:5000/health; then
                                        echo
                                        echo "========================================"
                                        echo "Deploy OK"
                                        echo "========================================"
                                    else
                                        echo
                                        echo "========================================"
                                        echo "Deploy FAILED"
                                        echo "========================================"

                                        docker logs devops-lab-app

                                        exit 1
                                    fi
                                '
                        """
                    }
                }
            }
        }
    }

    post {

        always {
            cleanWs()
        }

        success {
            echo "========================================"
            echo "Pipeline succeeded!"
            echo "========================================"
        }

        failure {
            echo "========================================"
            echo "Pipeline failed!"
            echo "========================================"
        }
    }
}