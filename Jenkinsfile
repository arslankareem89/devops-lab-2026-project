pipeline {

    agent any

    environment {
        IMAGE_NAME = "arslankareem89/cloud-devops-app"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Create Python Environment') {
            steps {
                dir('app') {
                    sh '''
                        python3 -m venv venv
                    '''
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                dir('app') {
                    sh '''
                        . venv/bin/activate

                        pip install --upgrade pip
                        pip install -r requirements.txt
                        pip install -r requirements-dev.txt
                    '''
                }
            }
        }

        stage('Ruff') {
            steps {
                dir('app') {
                    sh '''
                        . venv/bin/activate
                        ruff check .
                    '''
                }
            }
        }

        stage('Pytest') {
            steps {
                dir('app') {
                    sh '''
                        . venv/bin/activate
                        pytest -v
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir('app') {

                    withSonarQubeEnv('sonarqube') {

                        script {

                            def scannerHome = tool 'sonar-scanner'

                            withCredentials([
                                string(
                                    credentialsId: 'sonar-token',
                                    variable: 'SONAR_TOKEN'
                                )
                            ]) {

                                sh """
                                    ${scannerHome}/bin/sonar-scanner \
                                      -Dsonar.projectKey=cloud-devops-app \
                                      -Dsonar.sources=. \
                                      -Dsonar.host.url=http://sonarqube:9000 \
                                      -Dsonar.token=\\\$SONAR_TOKEN
                                """
                            }
                        }
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

        stage('Docker Build') {
            steps {
                script {

                    def TAG = env.BRANCH_NAME == 'main' ? 'latest' : 'dev'

                    sh """
                        docker build \
                          -t ${IMAGE_NAME}:${TAG} \
                          ./app
                    """
                }
            }
        }

        stage('Docker Push') {
            steps {
                script {

                    def TAG = env.BRANCH_NAME == 'main' ? 'latest' : 'dev'

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-creds',
                            usernameVariable: 'USER',
                            passwordVariable: 'PASS'
                        )
                    ]) {

                        sh '''
                            echo "$PASS" | docker login \
                                -u "$USER" \
                                --password-stdin
                        '''

                        sh """
                            docker push ${IMAGE_NAME}:${TAG}
                        """
                    }
                }
            }
        }
    }
}
