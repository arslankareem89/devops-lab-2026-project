pipeline {

    agent any

    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Local Check') {
            steps {
                sh '''
                    set -e

                    WORKSPACE_HOST="/var/lib/docker/volumes/devops-lab_jenkins_home/_data/workspace/$(basename "$WORKSPACE")"

                    echo "========================================"
                    echo "Running local checks..."
                    echo "Workspace: $WORKSPACE_HOST"
                    echo "========================================"

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

                withSonarQubeEnv('sonarqube') {

                    withCredentials([
                        string(
                            credentialsId: 'SONAR_TOKEN',
                            variable: 'SONAR_TOKEN'
                        )
                    ]) {

                        sh '''
                            set -e

                            WORKSPACE_HOST="/var/lib/docker/volumes/devops-lab_jenkins_home/_data/workspace/$(basename "$WORKSPACE")"
                            SONAR_HOST_URL="http://sonarqube:9000/sonar"

                            echo "========================================"
                            echo "Running SonarQube analysis..."
                            echo "Workspace: $WORKSPACE_HOST"
                            echo "SonarQube URL: $SONAR_HOST_URL"
                            echo "========================================"

                            rm -f "$WORKSPACE_HOST/report-task.txt"

                            docker run --rm \
                              --user 0:0 \
                              --network devops-lab_default \
                              -v "$WORKSPACE_HOST:/workspace" \
                              -w /workspace \
                              -e SONAR_HOST_URL="$SONAR_HOST_URL" \
                              -e SONAR_TOKEN="$SONAR_TOKEN" \
                              sonarsource/sonar-scanner-cli:latest \
                              -Dsonar.projectKey=devops-lab-app \
                              -Dsonar.sources=app \
                              -Dsonar.host.url="$SONAR_HOST_URL" \
                              -Dsonar.token="$SONAR_TOKEN" \
                              -Dsonar.scanner.metadataFilePath=/workspace/report-task.txt

                            echo
                            echo "Checking SonarQube report file..."

                            if [ -f "$WORKSPACE_HOST/report-task.txt" ]; then

                                echo "SUCCESS: report-task.txt was created."
                                echo
                                echo "===== report-task.txt ====="
                                cat "$WORKSPACE_HOST/report-task.txt"
                                echo "============================"
                                echo

                            else

                                echo "ERROR: report-task.txt was NOT created."
                                echo "SonarQube analysis cannot continue to Quality Gate."
                                exit 1

                            fi

                            echo "SonarQube analysis completed successfully."
                        '''
                    }
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
                    echo "${IMAGE_NAME}:${TAG}"
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
                            set -e

                            echo "Logging into Docker Hub..."

                            echo "$DOCKERHUB_PASS" | docker login \
                                -u "$DOCKERHUB_USER" \
                                --password-stdin
                        '''

                        sh """
                            set -e

                            echo "Pushing image..."

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

                            echo "Preparing SSH..."

                            mkdir -p ~/.ssh
                            chmod 700 ~/.ssh
                            chmod 600 "$SSH_KEY"

                            ssh-keyscan -H "$APP_HOST" \
                                >> ~/.ssh/known_hosts 2>/dev/null || true

                            echo "Deploying to $APP_HOST"
                        '''

                        sh """
                            set -e

                            ssh \
                                -o StrictHostKeyChecking=no \
                                -i "\$SSH_KEY" \
                                ec2-user@${APP_HOST} '

                                    set -e

                                    echo "========================================"
                                    echo "Docker Hub login"
                                    echo "========================================"

                                    echo "${DOCKERHUB_PASS}" | docker login \
                                        -u "${DOCKERHUB_USER}" \
                                        --password-stdin

                                    echo "========================================"
                                    echo "Stopping old application"
                                    echo "========================================"

                                    docker stop devops-lab-app 2>/dev/null || true
                                    docker rm devops-lab-app 2>/dev/null || true

                                    echo "========================================"
                                    echo "Pulling new image"
                                    echo "${IMAGE_NAME}:${TAG}"
                                    echo "========================================"

                                    docker pull ${IMAGE_NAME}:${TAG}

                                    echo "========================================"
                                    echo "Starting application"
                                    echo "========================================"

                                    docker run -d \
                                        --name devops-lab-app \
                                        --restart unless-stopped \
                                        -p 5000:5000 \
                                        ${IMAGE_NAME}:${TAG}

                                    echo "Waiting for application..."
                                    sleep 5

                                    echo "========================================"
                                    echo "Checking application health"
                                    echo "========================================"

                                    if curl -sf http://localhost:5000/health; then

                                        echo
                                        echo "========================================"
                                        echo "DEPLOY OK"
                                        echo "========================================"

                                    else

                                        echo
                                        echo "========================================"
                                        echo "DEPLOY FAILED"
                                        echo "========================================"

                                        docker logs devops-lab-app || true

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
            echo "Cleaning Jenkins workspace..."
            cleanWs()
        }

        success {
            echo "========================================"
            echo "PIPELINE SUCCEEDED!"
            echo "========================================"
        }

        failure {
            echo "========================================"
            echo "PIPELINE FAILED!"
            echo "========================================"
        }
    }
}