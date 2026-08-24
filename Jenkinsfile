pipeline {

    agent any

    environment {

        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"

        // Valid image tag verified on your EC2 host
        SONAR_SCANNER_IMAGE = "sonarsource/sonar-scanner-cli:12.1.0.3233_8.0.1"
    }

    stages {

        stage('Checkout') {

            steps {

                echo "========================================"
                echo "Checking out source code..."
                echo "========================================"

                checkout scm

                sh '''
                    set -eu

                    echo "Branch: ${BRANCH_NAME}"
                    echo "Commit: ${GIT_COMMIT}"
                    echo "Workspace: ${WORKSPACE}"
                '''
            }
        }


        stage('Local Check') {

            steps {

                sh '''
                    set -eu

                    echo "========================================"
                    echo "Running local checks..."
                    echo "========================================"

                    JENKINS_CONTAINER=$(docker ps -q -f name=^jenkins$)

                    if [ -z "$JENKINS_CONTAINER" ]; then
                        echo "ERROR: Jenkins container not found."
                        exit 1
                    fi

                    echo "Jenkins container: $JENKINS_CONTAINER"

                    docker run --rm \
                        --user 0:0 \
                        --volumes-from "$JENKINS_CONTAINER" \
                        -w "$WORKSPACE" \
                        python:3.14-slim \
                        sh -c '
                            set -eu

                            echo "Installing test dependencies..."

                            pip install --no-cache-dir \
                                -r app/requirements-dev.txt

                            echo "Running Ruff..."

                            ruff check app/

                            echo "Running pytest..."

                            cd app

                            pytest -v

                            echo "Local checks passed."
                        '

                    echo "========================================"
                    echo "Local checks completed successfully."
                    echo "Temporary Python container was removed."
                    echo "========================================"
                '''
            }
        }


        stage('SonarQube Analysis') {

            steps {

                withSonarQubeEnv('SonarQube') {

                    sh '''
                        set -eu

                        echo "========================================"
                        echo "Running SonarQube analysis..."
                        echo "========================================"

                        JENKINS_CONTAINER=$(docker ps -q -f name=^jenkins$)

                        if [ -z "$JENKINS_CONTAINER" ]; then
                            echo "ERROR: Jenkins container not found."
                            exit 1
                        fi

                        echo "Jenkins container: $JENKINS_CONTAINER"

                        # Remove accidental whitespace/newlines
                        SONAR_URL=$(printf '%s' "$SONAR_HOST_URL" | tr -d '[:space:]')

                        if [ -z "$SONAR_URL" ]; then
                            echo "ERROR: SONAR_HOST_URL is empty."
                            exit 1
                        fi

                        echo "SonarQube URL: $SONAR_URL"
                        echo "Project: devops-lab-app"

                        rm -rf "${WORKSPACE}/.scannerwork"
                        rm -f "${WORKSPACE}/report-task.txt"

                        echo "========================================"
                        echo "Testing SonarQube connectivity..."
                        echo "========================================"

                        docker run --rm \
                            --network devops-lab_default \
                            curlimages/curl:latest \
                            curl -fsS \
                                "http://sonarqube:9000/sonar/api/system/status"

                        echo
                        echo "SonarQube connectivity OK."

                        echo "========================================"
                        echo "Starting temporary SonarScanner container..."
                        echo "========================================"

                        docker run --rm \
                            --user 0:0 \
                            --network devops-lab_default \
                            --volumes-from "$JENKINS_CONTAINER" \
                            -w "$WORKSPACE" \
                            -e "SONAR_HOST_URL=$SONAR_URL" \
                            -e "SONAR_TOKEN=$SONAR_AUTH_TOKEN" \
                            "$SONAR_SCANNER_IMAGE" \
                            sh -c '
                                set -eu

                                echo "========================================"
                                echo "SonarScanner started"
                                echo "========================================"

                                echo "SonarQube URL: $SONAR_HOST_URL"

                                echo "Scanner version:"
                                sonar-scanner --version

                                echo "Running analysis..."

                                sonar-scanner \
                                    -Dsonar.projectKey=devops-lab-app \
                                    -Dsonar.projectName=devops-lab-app \
                                    -Dsonar.sources=app \
                                    -Dsonar.tests=app/tests \
                                    -Dsonar.test.inclusions="app/tests/**/*.py" \
                                    -Dsonar.exclusions="app/tests/**" \
                                    -Dsonar.host.url="$SONAR_HOST_URL" \
                                    -Dsonar.token="$SONAR_TOKEN" \
                                    -Dsonar.python.version=3.14

                                echo "========================================"
                                echo "SonarScanner finished successfully"
                                echo "========================================"
                            '

                        echo "========================================"
                        echo "Checking SonarQube report..."
                        echo "========================================"

                        if [ -f "${WORKSPACE}/.scannerwork/report-task.txt" ]; then

                            echo "report-task.txt found."

                            cat "${WORKSPACE}/.scannerwork/report-task.txt"

                        else

                            echo "ERROR: report-task.txt was not created."
                            exit 1

                        fi

                        echo "========================================"
                        echo "SonarQube analysis completed."
                        echo "Temporary SonarScanner container was removed."
                        echo "========================================"
                    '''
                }
            }
        }


        stage('Quality Gate') {

            steps {

                echo "========================================"
                echo "Waiting for SonarQube Quality Gate..."
                echo "========================================"

                timeout(time: 5, unit: 'MINUTES') {

                    waitForQualityGate abortPipeline: false
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
                            set -eu

                            echo "$DOCKERHUB_PASS" | docker login \
                                -u "$DOCKERHUB_USER" \
                                --password-stdin
                        '''

                        sh """
                            docker push ${IMAGE_NAME}:${TAG}
                        """
                    }

                    echo "========================================"
                    echo "Docker image pushed successfully."
                    echo "========================================"
                }
            }
        }


        stage('Remove Local Build Image') {

            steps {

                script {

                    def TAG = env.BRANCH_NAME == 'main' ? 'latest' : 'dev'

                    sh """
                        echo "========================================"
                        echo "Removing local build image..."
                        echo "========================================"

                        docker image rm ${IMAGE_NAME}:${TAG} 2>/dev/null || true

                        echo "Local application image removed."
                    """
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
                            set -eu

                            mkdir -p ~/.ssh

                            chmod 700 ~/.ssh
                            chmod 600 "$SSH_KEY"

                            ssh-keyscan -H "$APP_HOST" \
                                >> ~/.ssh/known_hosts 2>/dev/null || true
                        '''

                        sh """

                            ssh \
                                -o StrictHostKeyChecking=no \
                                -i "\$SSH_KEY" \
                                ec2-user@${APP_HOST} '

                                    set -eu

                                    echo "========================================"
                                    echo "Deploying application..."
                                    echo "========================================"

                                    echo "Docker Hub login..."

                                    echo "${DOCKERHUB_PASS}" | docker login \
                                        -u "${DOCKERHUB_USER}" \
                                        --password-stdin


                                    echo "Stopping old container..."

                                    docker stop devops-lab-app 2>/dev/null || true


                                    echo "Removing old container..."

                                    docker rm devops-lab-app 2>/dev/null || true


                                    echo "Removing old application image..."

                                    docker image rm \
                                        ${IMAGE_NAME}:${TAG} \
                                        2>/dev/null || true


                                    echo "Pulling new image..."

                                    docker pull ${IMAGE_NAME}:${TAG}


                                    echo "Starting application container..."

                                    docker run -d \
                                        --name devops-lab-app \
                                        --restart unless-stopped \
                                        -p 5000:5000 \
                                        ${IMAGE_NAME}:${TAG}


                                    echo "Waiting for application..."

                                    sleep 5


                                    echo "Checking application health..."

                                    if curl -fsS \
                                        http://localhost:5000/health; then

                                        echo
                                        echo "========================================"
                                        echo "DEPLOY OK"
                                        echo "========================================"

                                    else

                                        echo
                                        echo "========================================"
                                        echo "DEPLOY FAILED"
                                        echo "========================================"

                                        docker logs devops-lab-app

                                        exit 1

                                    fi


                                    echo "========================================"
                                    echo "Cleaning unused Docker resources..."
                                    echo "========================================"

                                    docker container prune -f
                                    docker image prune -f

                                    echo "Cleanup completed."

                                '
                        """
                    }
                }
            }
        }
    }


    post {

        always {

            echo "========================================"
            echo "Cleaning Jenkins workspace..."
            echo "========================================"

            cleanWs()
        }


        success {

            echo "========================================"
            echo "PIPELINE SUCCEEDED"
            echo "========================================"
        }


        failure {

            echo "========================================"
            echo "PIPELINE FAILED"
            echo "========================================"
        }
    }
}