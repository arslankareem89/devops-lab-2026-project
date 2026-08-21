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

                    echo "Running local checks..."
                    echo "Workspace: $WORKSPACE_HOST"

                    docker run --rm \
                      -v "$WORKSPACE_HOST:/workspace" \
                      -w /workspace \
                      python:3.14-slim \
                      sh -c 'pip install -r app/requirements-dev.txt && ruff check app/ && cd app && pytest -v'
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

                            # SonarQube runs behind the /sonar web context on the devops-lab_default network
                            SONAR_HOST_URL="http://sonarqube:9000/sonar"

                            echo "Workspace: $WORKSPACE_HOST"
                            echo "SonarQube URL: $SONAR_HOST_URL"

                            docker run --rm \
                              --network devops-lab_default \
                              -v "$WORKSPACE_HOST:/workspace" \
                              -w /workspace \
                              -e SONAR_HOST_URL="$SONAR_HOST_URL" \
                              -e SONAR_TOKEN="$SONAR_TOKEN" \
                              sonarsource/sonar-scanner-cli:latest \
                              -Dsonar.sources=app \
                              -Dsonar.projectKey=devops-lab-app \
                              -Dsonar.host.url="$SONAR_HOST_URL" \
                              -Dsonar.token="$SONAR_TOKEN" \
                              -Dsonar.scanner.reportTaskPath=/workspace/report-task.txt

                            echo "--- locate report-task.txt (global) ---"
                            find / -name 'report-task.txt' 2>/dev/null || true

                            # withSonarQubeEnv / waitForQualityGate expect report-task.txt
                            # in the Jenkins $WORKSPACE, so copy it there explicitly.
                            cp /workspace/report-task.txt "$WORKSPACE/" 2>/dev/null \
                              && echo "Copied report-task.txt to \$WORKSPACE" \
                              || echo "WARN: report-task.txt not found in /workspace"
                            ls -la "$WORKSPACE/report-task.txt" 2>/dev/null || true
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

                    echo "Building Docker image:"
                    echo "${IMAGE_NAME}:${TAG}"

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

                            ssh-keyscan -H "$APP_HOST" >> ~/.ssh/known_hosts 2>/dev/null || true

                            echo "Deploying to $APP_HOST"
                        '''

                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i "$SSH_KEY" \
                                ec2-user@${APP_HOST} '
                                    echo "Logging into Docker Hub..."

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

                                    sleep 5

                                    echo "Checking application health..."

                                    if curl -sf http://localhost:5000/health; then
                                        echo "Deploy OK"
                                    else
                                        echo "Deploy FAILED"
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
            echo "Pipeline succeeded!"
        }

        failure {
            echo "Pipeline failed!"
        }
    }
}