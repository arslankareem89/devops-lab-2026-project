pipeline {
    agent any
    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
        APP_HOST   = "10.0.2.126"
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        
        stage('Local Check') {
            steps {
                sh '''
                    docker run --rm -v "$WORKSPACE:/workspace" -w /workspace python:3.14-slim sh -c \
                    "pip install -r app/requirements-dev.txt && ruff check app/ && cd app && pytest -v"
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    dir('app') { sh 'sonar-scanner' }
                }
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'MINUTES') {
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
                        sh 'echo $DOCKERHUB_PASS | docker login -u $DOCKERHUB_USER --password-stdin'
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
                        sshUserPrivateKey(credentialsId: 'APP_SSH_KEY', keyVariable: 'APP_SSH_KEY')
                    ]) {
                        sh """
                            mkdir -p ~/.ssh
                            echo "$APP_SSH_KEY" > ~/.ssh/app_key
                            chmod 600 ~/.ssh/app_key
                            ssh -o StrictHostKeyChecking=no -i ~/.ssh/app_key ec2-user@${APP_HOST} "
                                echo '$DOCKERHUB_PASS' | docker login -u '$DOCKERHUB_USER' --password-stdin 2>/dev/null
                                docker stop devops-lab-app 2>/dev/null || true
                                docker rm devops-lab-app 2>/dev/null || true
                                docker run -d --name devops-lab-app --restart unless-stopped -p 5000:5000 ${IMAGE_NAME}:${TAG}
                                sleep 2
                                curl -sf http://localhost:5000/health && echo 'Deploy OK' || echo 'Deploy FAILED'
                            "
                        """
                    }
                }
            }
        }
    }
    post {
        always { cleanWs() }
        success { echo "Pipeline succeeded!" }
        failure { echo "Pipeline failed" }
    }
}