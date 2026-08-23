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

                echo "========================================"
                echo "Repository checked out successfully."
                echo "========================================"

                sh '''
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

                    WORKSPACE_HOST="/var/lib/docker/volumes/devops-lab_jenkins_home/_data/workspace/$(basename "$WORKSPACE")"

                    if [ ! -d "$WORKSPACE_HOST" ]; then
                        echo "ERROR: Workspace mount does not exist:"
                        echo "$WORKSPACE_HOST"
                        exit 1
                    fi

                    echo "Workspace mount:"
                    echo "$WORKSPACE_HOST"

                    docker run --rm \
                        --user 0:0 \
                        -v "$WORKSPACE_HOST:/workspace" \
                        -w /workspace \
                        python:3.14-slim \
                        sh -c '
                            set -eu

                            echo "Installing test dependencies..."
                            pip install --no-cache-dir -r app/requirements-dev.txt

                            echo "Running Ruff..."
                            ruff check app/

                            echo "Running pytest..."
                            cd app
                            pytest -v

                            echo "Local checks completed successfully."
                        '

                    echo "========================================"
                    echo "Local checks passed."
                    echo "Temporary test container removed."
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

                        # Remove files from previous scanner runs.
                        rm -rf "${WORKSPACE}/.scannerwork"
                        rm -f "${WORKSPACE}/report-task.txt"

                        # Jenkins container must be running because the
                        # scanner container uses the Jenkins workspace volume.
                        JENKINS_CONTAINER="$(docker ps -q -f name=^jenkins$)"

                        if [ -z "$JENKINS_CONTAINER" ]; then
                            echo "ERROR: Jenkins container not found."
                            exit 1
                        fi

                        echo "Jenkins container: $JENKINS_CONTAINER"

                        # Remove a possible trailing slash.
                        SONAR_URL="${SONAR_HOST_URL%/}"

                        echo "Using SonarQube URL: $SONAR_URL"

                        echo "========================================"
                        echo "Starting temporary SonarScanner container..."
                        echo "========================================"

                        docker run --rm \
                            --user 0:0 \
                            --network devops-lab_default \
                            --volumes-from "$JENKINS_CONTAINER" \
                            -w "${WORKSPACE}" \
                            -e SONAR_TOKEN="$SONAR_AUTH_TOKEN" \
                            -e SONAR_URL="$SONAR_URL" \
                            --entrypoint sh \
                            sonarsource/sonar-scanner-cli:latest \
                            -c '
                                set -eu

                                echo "SonarScanner started"
                                echo "SonarQube URL: $SONAR_URL"

                                sonar-scanner \
                                    -Dsonar.projectKey=devops-lab-app \
                                    -Dsonar.sources=app \
                                    -Dsonar.tests=app/tests \
                                    -Dsonar.test.inclusions="app/tests/**/*.py" \
                                    -Dsonar.exclusions="app/tests/**" \
                                    -Dsonar.host.url="$SONAR_URL" \
                                    -Dsonar.token="$SONAR_TOKEN" \
                                    -Dsonar.python.version=3.14

                                echo "SonarScanner finished successfully"
                            '

                        echo "========================================"
                        echo "SonarQube scanner completed."
                        echo "Temporary SonarScanner container removed."
                        echo "========================================"

                        if [ ! -f "${WORKSPACE}/.scannerwork/report-task.txt" ]; then
                            echo "ERROR: report-task.txt was not created."
                            echo "The SonarScanner did not complete successfully."
                            exit 1
                        fi

                        echo "report-task.txt found."

                        cat "${WORKSPACE}/.scannerwork/report-task.txt"

                        echo "========================================"
                        echo "SonarQube analysis completed successfully."
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
                                    echo "Stopping old application container..."
                                    echo "========================================"

                                    docker stop devops-lab-app 2>/dev/null || true
                                    docker rm devops-lab-app 2>/dev/null || true

                                    echo "========================================"
                                    echo "Pulling new image..."
                                    echo "========================================"

                                    docker pull ${IMAGE_NAME}:${TAG}

                                    echo "========================================"
                                    echo "Starting application..."
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

                                    echo "========================================"
                                    echo "Removing unused Docker images..."
                                    echo "========================================"

                                    docker image prune -f

                                    echo "Deployment completed."
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