pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        APP_NAME = 'python-cicd-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        SLACK_CHANNEL = '#deployments'
    }
    
    parameters {
        choice(
            name: 'DEPLOY_TO_UAT',
            choices: ['No', 'Yes'],
            description: 'Deploy to UAT after Dev deployment?'
        )
        choice(
            name: 'DEPLOY_TO_PROD',
            choices: ['No', 'Yes'],
            description: 'Deploy to Production?'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install -r app/requirements.txt
                '''
            }
        }
        
        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    pytest tests/ -v --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }
        
        stage('Code Quality Check') {
            steps {
                sh '''
                    . venv/bin/activate
                    pip install pylint flake8
                    flake8 app/ --max-line-length=120 || true
                    pylint app/*.py || true
                '''
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${APP_NAME}:${IMAGE_TAG}")
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                    sh '''
                        snyk auth $SNYK_TOKEN
                        snyk container test ${APP_NAME}:${IMAGE_TAG} --severity-threshold=high --fail-on=all
                    '''
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: AWS_REGION) {
                        sh '''
                            # Login to ECR
                            aws ecr get-login-password --region ${AWS_REGION} | \\
                                docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            
                            # Tag images
                            docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}/${APP_NAME}:${IMAGE_TAG}
                            docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}/${APP_NAME}:${GIT_COMMIT_SHORT}
                            docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}/${APP_NAME}:latest
                            
                            # Push images
                            docker push ${ECR_REGISTRY}/${APP_NAME}:${IMAGE_TAG}
                            docker push ${ECR_REGISTRY}/${APP_NAME}:${GIT_COMMIT_SHORT}
                            docker push ${ECR_REGISTRY}/${APP_NAME}:latest
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to Dev') {
            when {
                branch 'master'
            }
            steps {
                script {
                    deployToEnvironment('dev', IMAGE_TAG)
                }
            }
        }
        
        stage('Approval for UAT') {
            when {
                branch 'master'
                expression { params.DEPLOY_TO_UAT == 'Yes' }
            }
            steps {
                script {
                    timeout(time: 24, unit: 'HOURS') {
                        input message: 'Deploy to UAT?', 
                              ok: 'Deploy',
                              submitter: 'admin,devops-team'
                    }
                }
            }
        }
        
        stage('Deploy to UAT') {
            when {
                branch 'master'
                expression { params.DEPLOY_TO_UAT == 'Yes' }
            }
            steps {
                script {
                    deployToEnvironment('uat', IMAGE_TAG)
                }
            }
        }
        
        stage('Smoke Tests - UAT') {
            when {
                branch 'master'
                expression { params.DEPLOY_TO_UAT == 'Yes' }
            }
            steps {
                script {
                    runSmokeTests('uat')
                }
            }
        }
        
        stage('Approval for Production') {
            when {
                branch 'master'
                expression { params.DEPLOY_TO_PROD == 'Yes' }
            }
            steps {
                script {
                    timeout(time: 48, unit: 'HOURS') {
                        input message: 'Deploy to PRODUCTION?', 
                              ok: 'Deploy to Production',
                              submitter: 'admin,release-manager'
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'master'
                expression { params.DEPLOY_TO_PROD == 'Yes' }
            }
            steps {
                script {
                    deployToEnvironment('prod', IMAGE_TAG)
                }
            }
        }
        
        stage('Smoke Tests - Production') {
            when {
                branch 'master'
                expression { params.DEPLOY_TO_PROD == 'Yes' }
            }
            steps {
                script {
                    runSmokeTests('prod')
                }
            }
        }
    }
    
    post {
        success {
            slackSend(
                channel: SLACK_CHANNEL,
                color: 'good',
                message: "✅ Pipeline SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}\\nImage: ${IMAGE_TAG}\\nCommit: ${GIT_COMMIT_SHORT}"
            )
        }
        failure {
            slackSend(
                channel: SLACK_CHANNEL,
                color: 'danger',
                message: "❌ Pipeline FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}\\nCommit: ${GIT_COMMIT_SHORT}"
            )
        }
        always {
            cleanWs()
        }
    }
}

def deployToEnvironment(String environment, String imageTag) {
    withAWS(credentials: 'aws-credentials', region: AWS_REGION) {
        dir("terraform/environments/${environment}") {
            sh """
                terraform init -upgrade
                terraform plan -var="image_tag=${imageTag}" -out=tfplan
                terraform apply -auto-approve tfplan
            """
            
            // Update ECS service with new image
            sh """
                aws ecs update-service \\
                    --cluster ${environment}-${APP_NAME}-cluster \\
                    --service ${environment}-${APP_NAME}-service \\
                    --force-new-deployment \\
                    --region ${AWS_REGION}
                
                # Wait for deployment to stabilize
                aws ecs wait services-stable \\
                    --cluster ${environment}-${APP_NAME}-cluster \\
                    --services ${environment}-${APP_NAME}-service \\
                    --region ${AWS_REGION}
            """
        }
    }
    
    slackSend(
        channel: SLACK_CHANNEL,
        color: 'good',
        message: "🚀 Deployed to ${environment.toUpperCase()}: ${APP_NAME}:${imageTag}"
    )
}

def runSmokeTests(String environment) {
    withAWS(credentials: 'aws-credentials', region: AWS_REGION) {
        sh """
            # Get ALB DNS name
            ALB_DNS=\\$(terraform output -raw alb_dns_name)
            
            # Health check
            echo "Running smoke tests against \\${ALB_DNS}"
            
            for i in {1..10}; do
                response=\\$(curl -s -o /dev/null -w "%{http_code}" http://\\${ALB_DNS}/health)
                if [ \\$response -eq 200 ]; then
                    echo "✅ Health check passed"
                    exit 0
                fi
                echo "Attempt \\$i failed, retrying..."
                sleep 10
            done
            
            echo "❌ Smoke tests failed"
            exit 1
        """
    }
}
