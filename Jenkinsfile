pipeline {
    agent any
    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"
        SONAR_URL  = "http://sonarqube:9000/sonar"
    }
    stages {
        stage('Checkout SCM') { steps { checkout scm } }
        stage('Checkout') {
            steps {
                echo "Repository checked out successfully."
                sh 'echo "Branch: ${BRANCH_NAME} Commit: ${GIT_COMMIT}"'
            }
        }
        stage('Local Check') {
            steps {
                sh '''
                    set -e
                    WORKSPACE_HOST="/var/lib/docker/volumes/devops-lab_jenkins_home/_data/workspace/$(basename "$WORKSPACE")"
                    docker run --rm -v "$WORKSPACE_HOST:/workspace" -w /workspace python:3.14-slim sh -c '
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
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        set -e
                        rm -rf "${WORKSPACE}/.scannerwork"

                        JENKINS_CONTAINER=$(docker ps -q -f name=^jenkins$)

                        docker run --rm \
                          --user 0:0 \
                          --network devops-lab_default \
                          --volumes-from "$JENKINS_CONTAINER" \
                          -w "${WORKSPACE}" \
                          -e SONAR_HOST_URL \
                          -e SONAR_SCANNER_OPTS="-Dsonar.working.directory=${WORKSPACE}/.scannerwork" \
                          -e SONAR_TOKEN=$SONAR_AUTH_TOKEN \
                          sonarsource/sonar-scanner-cli:latest \
                          -Dsonar.projectKey=devops-lab-app \
                          -Dsonar.sources=app \
                          -Dsonar.tests=app/tests \
                          -Dsonar.test.inclusions=app/tests/**/*.py \
                          -Dsonar.exclusions=app/tests/** \
                          -Dsonar.host.url="${SONAR_URL}" \
                          -Dsonar.python.version=3.14

                        echo "--- Checking report-task.txt ---"
                        ls -lh "${WORKSPACE}/.scannerwork/" || true
                        cat "${WORKSPACE}/.scannerwork/report-task.txt" || cat "${WORKSPACE}/report-task.txt" || echo "NOT FOUND"
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
                    sh "docker build -t ${IMAGE_NAME}:${TAG} ./app"
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
                        sh 'echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin'
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    def TAG = env.BRANCH_NAME == 'main' ? 'latest' : 'dev'
                    withCredentials([
                        usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS'),
                        sshUserPrivateKey(credentialsId: 'APP_SSH_KEY', keyFileVariable: 'SSH_KEY')
                    ]) {
                        sh """
                            ssh -o StrictHostKeyChecking=no -i "\\$SSH_KEY" ec2-user@${APP_HOST} '
                                echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin
                                docker stop devops-lab-app || true
                                docker rm devops-lab-app || true
                                docker pull ${IMAGE_NAME}:${TAG}
                                docker run -d --name devops-lab-app --restart unless-stopped -p 5000:5000 ${IMAGE_NAME}:${TAG}
                                sleep 5
                                curl -sf http://localhost:5000/health
                            '
                        """
                    }
                }
            }
        }
    }
    post { always { cleanWs() } }
}