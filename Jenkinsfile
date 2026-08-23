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

                    echo "========================================"
                    echo "Running local checks..."
                    echo "Workspace: $WORKSPACE"
                    echo "========================================"

                    docker run --rm \
                      --volumes-from "$HOSTNAME" \
                      -w "$WORKSPACE" \
                      python:3.14-slim \
                      sh -c '
                        pip install --no-cache-dir \
                          -r app/requirements-dev.txt &&
                        ruff check app/ &&
                        cd app &&
                        pytest -v
                      '

                    echo "========================================"
                    echo "Local checks passed."
                    echo "========================================"
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

                            echo "========================================"
                            echo "Running SonarQube analysis..."
                            echo "Workspace: $WORKSPACE"
                            echo "SonarQube URL: $SONAR_HOST_URL"
                            echo "========================================"

                            # Remove previous scanner data
                            rm -rf "$WORKSPACE/.scannerwork"

                            # Run SonarScanner inside a container that shares
                            # Jenkins' /var/jenkins_home volume.
                            docker run --rm \
                              --user 0:0 \
                              --network devops-lab_default \
                              --volumes-from "$HOSTNAME" \
                              -w "$WORKSPACE" \
                              -e SONAR_HOST_URL="$SONAR_HOST_URL" \
                              -e SONAR_TOKEN="$SONAR_TOKEN" \
                              sonarsource/sonar-scanner-cli:latest \
                              -Dsonar.projectKey=devops-lab-app \
                              -Dsonar.sources=app \
                              -Dsonar.host.url="$SONAR_HOST_URL" \
                              -Dsonar.token="$SONAR_TOKEN" \
                              -Dsonar.python.version=3.14 \
                              -Dsonar.tests=app/tests

                            echo ""
                            echo "========================================"
                            echo "Checking SonarQube report..."
                            echo "========================================"

                            if [ -f "$WORKSPACE/.scannerwork/report-task.txt" ]; then
                                echo "SUCCESS: SonarQube report-task.txt created."
                                echo ""
                                echo "Report:"
                                cat "$WORKSPACE/.scannerwork/report-task.txt"
                            else
                                echo "ERROR: SonarQube report-task.txt was NOT created."
                                echo ""
                                echo "Workspace contents:"
                                ls -la "$WORKSPACE"
                                echo ""
                                echo "Scanner workspace:"
                                ls -la "$WORKSPACE/.scannerwork" 2>/dev/null || true
                                exit 1
                            fi

                            echo ""
                            echo "========================================"
                            echo "SonarQube analysis completed successfully."
                            echo "========================================"
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

                            echo "$DOCKERHUB_PASS" | docker login \
                                -u "$DOCKERHUB_USER" \
                                --password-stdin
                        '''

                        sh """
                            docker push ${IMAGE_NAME}:${TAG}
                        """
                    }

                    echo "Docker image pushed successfully."
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
                            set -e

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

                                    echo "========================================"
                                    echo "Stopping old container..."
                                    echo "========================================"

                                    docker stop devops-lab-app 2>/dev/null || true
                                    docker rm devops-lab-app 2>/dev/null || true

                                    echo "========================================"
                                    echo "Pulling new image..."
                                    echo "========================================"

                                    docker pull ${IMAGE_NAME}:${TAG}

                                    echo "========================================"
                                    echo "Starting new container..."
                                    echo "========================================"

                                    docker run -d \
                                        --name devops-lab-app \
                                        --restart unless-stopped \
                                        -p 5000:5000 \
                                        ${IMAGE_NAME}:${TAG}

                                    echo "Waiting for application..."
                                    sleep 5

                                    echo "========================================"
                                    echo "Checking application health..."
                                    echo "========================================"

                                    if curl -sf http://localhost:5000/health; then
                                        echo
                                        echo "Deploy OK"
                                    else
                                        echo
                                        echo "Deploy FAILED"
                                        docker logs devops-lab-app
                                        exit 1
                                    fi

                                    echo "========================================"
                                    echo "Deployment completed successfully."
                                    echo "========================================"
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