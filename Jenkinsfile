pipeline {

    agent any

    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"
    }

    stages {

        stage('Checkout') {
            steps {
                echo "========================================"
                echo "Repository checked out successfully."
                echo "========================================"

                sh '''
                    set -e

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

                    JENKINS_CONTAINER="$(docker ps -q -f name=^jenkins$)"

                    if [ -z "$JENKINS_CONTAINER" ]; then
                        echo "ERROR: Jenkins container not found."
                        exit 1
                    fi

                    echo "Jenkins container: $JENKINS_CONTAINER"
                    echo "Jenkins workspace: $WORKSPACE"

                    echo "Starting temporary Python container..."

                    docker run --rm \
                        --user 0:0 \
                        --volumes-from "$JENKINS_CONTAINER" \
                        -w "$WORKSPACE" \
                        python:3.14-slim \
                        sh -c '
                            set -eu

                            echo "Installing development dependencies..."

                            pip install --no-cache-dir \
                                -r app/requirements-dev.txt

                            echo "Running Ruff..."

                            ruff check app/

                            echo "Running pytest..."

                            cd app
                            pytest -v

                            echo "Local checks inside container passed."
                        '

                    echo "========================================"
                    echo "Local checks passed."
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

                        echo "Workspace: ${WORKSPACE}"
                        echo "SonarQube URL: ${SONAR_HOST_URL}"
                        echo "Project: devops-lab-app"

                        echo "========================================"

                        # Remove previous scanner output.
                        rm -rf "${WORKSPACE}/.scannerwork"
                        rm -f "${WORKSPACE}/report-task.txt"

                        JENKINS_CONTAINER="$(docker ps -q -f name=^jenkins$)"

                        if [ -z "$JENKINS_CONTAINER" ]; then
                            echo "ERROR: Jenkins container not found."
                            exit 1
                        fi

                        echo "Jenkins container: $JENKINS_CONTAINER"

                        echo "Starting temporary SonarScanner container..."

                        docker run --rm \
                            --user 0:0 \
                            --network devops-lab_default \
                            --volumes-from "$JENKINS_CONTAINER" \
                            -w "$WORKSPACE" \
                            -e SONAR_HOST_URL="$SONAR_HOST_URL" \
                            -e SONAR_TOKEN="$SONAR_AUTH_TOKEN" \
                            sonarsource/sonar-scanner-cli:latest \
                            sh -c '
                                set -eu

                                echo "========================================"
                                echo "SonarScanner started"
                                echo "========================================"

                                echo "SonarQube URL: $SONAR_HOST_URL"

                                sonar-scanner \
                                    -Dsonar.projectKey=devops-lab-app \
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

                            echo "report-task.txt found:"
                            cat "${WORKSPACE}/.scannerwork/report-task.txt"

                        elif [ -f "${WORKSPACE}/report-task.txt" ]; then

                            echo "report-task.txt found:"
                            cat "${WORKSPACE}/report-task.txt"

                        else

                            echo "ERROR: report-task.txt was not created."
                            echo "SonarQube scanner did not complete successfully."
                            exit 1

                        fi

                        echo "========================================"
                        echo "SonarQube analysis completed successfully."
                        echo "Temporary SonarScanner container was removed."
                        echo "========================================"
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

                            echo "Logging into Docker Hub..."

                            echo "$DOCKERHUB_PASS" | docker login \
                                -u "$DOCKERHUB_USER" \
                                --password-stdin
                        '''

                        sh """
                            echo "Pushing image..."

                            docker push ${IMAGE_NAME}:${TAG}
                        """
                    }

                    echo "========================================"
                    echo "Docker image pushed successfully."
                    echo "========================================"

                    echo "Cleaning unused Docker build cache..."

                    sh '''
                        docker builder prune -f
                    '''
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

                            echo "Deploying to $APP_HOST"
                        '''

                        sh """
                            set -eu

                            ssh \
                                -o StrictHostKeyChecking=no \
                                -i "\$SSH_KEY" \
                                ec2-user@${APP_HOST} '

                                    set -eu

                                    echo "========================================"
                                    echo "Logging into Docker Hub..."
                                    echo "========================================"

                                    echo "${DOCKERHUB_PASS}" | docker login \
                                        -u "${DOCKERHUB_USER}" \
                                        --password-stdin

                                    echo "========================================"
                                    echo "Stopping old application..."
                                    echo "========================================"

                                    docker stop devops-lab-app 2>/dev/null || true
                                    docker rm devops-lab-app 2>/dev/null || true

                                    echo "========================================"
                                    echo "Pulling image from Docker Hub..."
                                    echo "========================================"

                                    docker pull ${IMAGE_NAME}:${TAG}

                                    echo "========================================"
                                    echo "Starting application container..."
                                    echo "========================================"

                                    docker run -d \
                                        --name devops-lab-app \
                                        --restart unless-stopped \
                                        -p 5000:5000 \
                                        ${IMAGE_NAME}:${TAG}

                                    echo "========================================"
                                    echo "Waiting for application..."
                                    echo "========================================"

                                    sleep 5

                                    echo "========================================"
                                    echo "Checking application health..."
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

                                        docker logs devops-lab-app

                                        exit 1

                                    fi

                                    echo "========================================"
                                    echo "Cleaning unused containers..."
                                    echo "========================================"

                                    docker container prune -f

                                    echo "Deployment completed successfully."

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