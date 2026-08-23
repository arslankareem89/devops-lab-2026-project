pipeline {

    agent any

    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"

        // IMPORTANT:
        // No spaces before or after this URL.
        SONAR_URL = "http://sonarqube:9000/sonar"
    }

    stages {

        // ============================================================
        // CHECKOUT
        // ============================================================

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


        // ============================================================
        // LOCAL CHECKS
        // Temporary Python container
        // ============================================================

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
                    echo "Starting temporary Python container..."

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

                            echo "Temporary Python container completed."
                        '

                    echo "========================================"
                    echo "Local checks passed."
                    echo "Temporary Python container was removed."
                    echo "========================================"
                '''
            }
        }


        // ============================================================
        // SONARQUBE ANALYSIS
        // Temporary SonarScanner container
        // ============================================================

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

                        # IMPORTANT:
                        # Do NOT use SONAR_HOST_URL supplied by Jenkins
                        # because your current Jenkins configuration contains
                        # whitespace around the URL.
                        #
                        # We explicitly use the clean internal Docker URL.

                        SONAR_URL="http://sonarqube:9000/sonar"

                        echo "SonarQube URL: $SONAR_URL"
                        echo "Project: devops-lab-app"

                        # Remove previous scanner files.
                        rm -rf "$WORKSPACE/.scannerwork"
                        rm -f "$WORKSPACE/report-task.txt"

                        echo "========================================"
                        echo "Testing SonarQube connectivity..."
                        echo "========================================"

                        docker run --rm \
                            --network devops-lab_default \
                            --volumes-from "$JENKINS_CONTAINER" \
                            -w "$WORKSPACE" \
                            curlimages/curl:latest \
                            sh -c "
                                set -eu

                                echo 'Testing SonarQube...'

                                curl -fsS \
                                    '$SONAR_URL/api/system/status'

                                echo
                                echo 'SonarQube connectivity OK.'
                            "

                        echo "========================================"
                        echo "Starting temporary SonarScanner container..."
                        echo "========================================"

                        docker run --rm \
                            --user 0:0 \
                            --network devops-lab_default \
                            --volumes-from "$JENKINS_CONTAINER" \
                            -w "$WORKSPACE" \
                            -e SONAR_HOST_URL="$SONAR_URL" \
                            -e SONAR_TOKEN="$SONAR_AUTH_TOKEN" \
                            sonarsource/sonar-scanner-cli:8.1.0.6389 \
                            sh -c '
                                set -eu

                                echo "========================================"
                                echo "SonarScanner started"
                                echo "========================================"

                                echo "SonarQube URL: $SONAR_HOST_URL"

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

                        if [ -f "$WORKSPACE/.scannerwork/report-task.txt" ]; then

                            echo "report-task.txt found."

                            cat "$WORKSPACE/.scannerwork/report-task.txt"

                        else

                            echo "ERROR: report-task.txt was not created."

                            echo "SonarScanner did not complete successfully."

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


        // ============================================================
        // QUALITY GATE
        // ============================================================

        stage('Quality Gate') {

            steps {

                timeout(time: 5, unit: 'MINUTES') {

                    waitForQualityGate(
                        abortPipeline: true
                    )
                }
            }
        }


        // ============================================================
        // BUILD + PUSH
        // ============================================================

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


        // ============================================================
        // DEPLOY
        // ============================================================

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
                                    echo "Removing old application image..."
                                    echo "========================================"

                                    docker image rm \
                                        ${IMAGE_NAME}:${TAG} \
                                        2>/dev/null || true

                                    echo "========================================"
                                    echo "Pulling new image..."
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

                                    echo "Checking application health..."

                                    if curl -fsS \
                                        http://localhost:5000/health
                                    then

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
                                    echo "Cleaning unused Docker resources..."
                                    echo "========================================"

                                    docker container prune -f

                                    echo "Deployment completed."

                                '
                        """
                    }
                }
            }
        }
    }


    // ================================================================
    // POST
    // ================================================================

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