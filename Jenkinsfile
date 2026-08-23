```groovy
pipeline {

    agent any

    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"
    }

    stages {

        // =========================================================
        // 1. CHECKOUT
        // =========================================================

        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Checkout Verification') {
            steps {

                echo "Repository checked out successfully."

                sh '''
                    set -e

                    echo "========================================"
                    echo "Git Information"
                    echo "========================================"

                    echo "Branch:"
                    echo "${BRANCH_NAME}"

                    echo "Commit:"
                    git rev-parse HEAD

                    echo "Commit message:"
                    git log -1 --oneline

                    echo "Remote:"
                    git remote -v
                '''
            }
        }


        // =========================================================
        // 2. LOCAL CHECKS
        // =========================================================

        stage('Local Check') {
            steps {

                sh '''
                    set -e

                    echo "========================================"
                    echo "Running local checks..."
                    echo "========================================"

                    WORKSPACE_HOST="/var/lib/docker/volumes/devops-lab_jenkins_home/_data/workspace/$(basename "$WORKSPACE")"

                    docker run --rm \
                        -v "$WORKSPACE_HOST:/workspace" \
                        -w /workspace \
                        python:3.14-slim \
                        sh -c '
                            set -e

                            echo "Installing development dependencies..."

                            pip install \
                                --no-cache-dir \
                                -r app/requirements-dev.txt

                            echo "========================================"
                            echo "Running Ruff"
                            echo "========================================"

                            ruff check app/

                            echo "========================================"
                            echo "Running Pytest"
                            echo "========================================"

                            cd app

                            pytest -v
                        '

                    echo "========================================"
                    echo "Local checks passed."
                    echo "========================================"
                '''
            }
        }


        // =========================================================
        // 3. SONARQUBE ANALYSIS
        // =========================================================

        stage('SonarQube Analysis') {
            steps {

                withSonarQubeEnv('sonarqube') {

                    withCredentials([
                        string(
                            credentialsId: 'SONAR_TOKEN',
                            variable: 'SONAR_TOKEN'
                        )
                    ]) {

                        script {

                            /*
                             * IMPORTANT:
                             *
                             * This name MUST exactly match:
                             *
                             * Manage Jenkins
                             * → Tools
                             * → SonarQube Scanner installations
                             *
                             * Name:
                             * SonarQube Scanner
                             */

                            def scannerHome = tool 'SonarQube Scanner'

                            echo "========================================"
                            echo "SonarQube Configuration"
                            echo "========================================"

                            echo "Scanner:"
                            echo "${scannerHome}"

                            echo "SonarQube URL:"
                            echo "${SONAR_HOST_URL}"

                            sh """
                                set -e

                                echo "========================================"
                                echo "SonarScanner Version"
                                echo "========================================"

                                ${scannerHome}/bin/sonar-scanner \
                                    --version

                                echo "========================================"
                                echo "Running SonarQube Analysis"
                                echo "========================================"

                                ${scannerHome}/bin/sonar-scanner \
                                    -Dsonar.projectKey=devops-lab-app \
                                    -Dsonar.sources=app \
                                    -Dsonar.tests=app/tests \
                                    -Dsonar.exclusions=app/tests/** \
                                    -Dsonar.host.url="\$SONAR_HOST_URL" \
                                    -Dsonar.token="\$SONAR_TOKEN" \
                                    -Dsonar.python.version=3.14

                                echo "========================================"
                                echo "SonarQube Analysis Completed"
                                echo "========================================"
                            """
                        }
                    }
                }
            }
        }


        // =========================================================
        // 4. QUALITY GATE
        // =========================================================

        stage('Quality Gate') {
            steps {

                timeout(
                    time: 5,
                    unit: 'MINUTES'
                ) {

                    echo "========================================"
                    echo "Waiting for SonarQube Quality Gate..."
                    echo "========================================"

                    waitForQualityGate(
                        abortPipeline: true
                    )

                    echo "========================================"
                    echo "QUALITY GATE PASSED"
                    echo "========================================"
                }
            }
        }


        // =========================================================
        // 5. DOCKER BUILD + PUSH
        // =========================================================

        stage('Docker Build & Push') {
            steps {

                script {

                    def TAG =
                        env.BRANCH_NAME == 'main'
                            ? 'latest'
                            : 'dev'

                    echo "========================================"
                    echo "Docker Build"
                    echo "========================================"

                    echo "Image:"
                    echo "${IMAGE_NAME}:${TAG}"

                    sh """
                        set -e

                        docker build \
                            -t ${IMAGE_NAME}:${TAG} \
                            ./app
                    """

                    echo "Docker image built successfully."


                    // ---------------------------------------------
                    // Docker Hub Login
                    // ---------------------------------------------

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-creds',
                            usernameVariable: 'DOCKERHUB_USER',
                            passwordVariable: 'DOCKERHUB_PASS'
                        )
                    ]) {

                        sh '''
                            set -e

                            echo "========================================"
                            echo "Docker Hub Login"
                            echo "========================================"

                            echo "$DOCKERHUB_PASS" | \
                                docker login \
                                    -u "$DOCKERHUB_USER" \
                                    --password-stdin

                            echo "Docker Hub login successful."
                        '''

                        sh """
                            set -e

                            echo "========================================"
                            echo "Pushing Docker Image"
                            echo "========================================"

                            docker push \
                                ${IMAGE_NAME}:${TAG}

                            echo "Docker image pushed successfully."
                        """
                    }
                }
            }
        }


        // =========================================================
        // 6. DEPLOY TO EC2
        // =========================================================

        stage('Deploy') {
            steps {

                script {

                    def TAG =
                        env.BRANCH_NAME == 'main'
                            ? 'latest'
                            : 'dev'


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


                        // -----------------------------------------
                        // Prepare SSH
                        // -----------------------------------------

                        sh '''
                            set -e

                            echo "========================================"
                            echo "Preparing SSH"
                            echo "========================================"

                            mkdir -p ~/.ssh

                            chmod 700 ~/.ssh

                            chmod 600 "$SSH_KEY"

                            ssh-keyscan -H "$APP_HOST" \
                                >> ~/.ssh/known_hosts \
                                2>/dev/null || true

                            echo "Target:"
                            echo "$APP_HOST"
                        '''


                        // -----------------------------------------
                        // Remote Deployment
                        // -----------------------------------------

                        sh """
                            set -e

                            echo "========================================"
                            echo "Connecting to Application EC2"
                            echo "========================================"

                            ssh \
                                -o StrictHostKeyChecking=no \
                                -i "\$SSH_KEY" \
                                ec2-user@${APP_HOST} '

                                    set -e

                                    echo "========================================"
                                    echo "Connected to EC2"
                                    echo "========================================"

                                    echo "Hostname:"
                                    hostname

                                    echo "Private IP:"
                                    hostname -I


                                    echo "========================================"
                                    echo "Docker Hub Login"
                                    echo "========================================"

                                    echo "${DOCKERHUB_PASS}" | \
                                        docker login \
                                            -u "${DOCKERHUB_USER}" \
                                            --password-stdin


                                    echo "========================================"
                                    echo "Stopping Old Container"
                                    echo "========================================"

                                    docker stop devops-lab-app \
                                        2>/dev/null || true

                                    docker rm devops-lab-app \
                                        2>/dev/null || true


                                    echo "========================================"
                                    echo "Pulling New Image"
                                    echo "========================================"

                                    docker pull \
                                        ${IMAGE_NAME}:${TAG}


                                    echo "========================================"
                                    echo "Starting New Container"
                                    echo "========================================"

                                    docker run -d \
                                        --name devops-lab-app \
                                        --restart unless-stopped \
                                        -p 5000:5000 \
                                        ${IMAGE_NAME}:${TAG}


                                    echo "========================================"
                                    echo "Waiting for Application"
                                    echo "========================================"

                                    sleep 5


                                    echo "========================================"
                                    echo "Health Check"
                                    echo "========================================"

                                    if curl -sf \
                                        http://localhost:5000/health
                                    then

                                        echo
                                        echo "========================================"
                                        echo "DEPLOY OK"
                                        echo "========================================"

                                    else

                                        echo
                                        echo "========================================"
                                        echo "DEPLOY FAILED"
                                        echo "========================================"

                                        echo "Container logs:"

                                        docker logs \
                                            devops-lab-app

                                        exit 1
                                    fi
                                '
                        """
                    }
                }
            }
        }
    }


    // =============================================================
    // POST ACTIONS
    // =============================================================

    post {

        always {
            echo "========================================"
            echo "Pipeline completed."
            echo "========================================"
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
```
