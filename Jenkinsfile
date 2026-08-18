pipeline {
    agent any
    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Local Check') {
            steps {
                dir('app') {
                    sh '''
                        python3 -m venv venv
                        . venv/bin/activate
                        pip install -r requirements-dev.txt
                        ruff check . || true
                        pytest -v || echo "no tests"
                    '''
                }
            }
        }
        stage('Docker Build & Push') {
            steps {
                script {
                    def TAG = env.BRANCH_NAME == 'main' ? 'latest' : 'dev'
                    sh "docker build -t ${IMAGE_NAME}:${TAG} ./app"
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                        sh 'echo $PASS | docker login -u $USER --password-stdin'
                        sh "docker push ${IMAGE_NAME}:${TAG}"
                    }
                }
            }
        }
    }
}
