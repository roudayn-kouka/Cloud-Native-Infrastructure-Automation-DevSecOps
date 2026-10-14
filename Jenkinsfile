// Declarative CI/CD pipeline - Cloud-Native DevOps Project (Roudayna Kouka)
//
// Every branch : test -> SonarQube quality gate -> Trivy -> build images -> scan images
// main branch  : + push to Amazon ECR + GitOps promotion (commit new image tag; ArgoCD deploys)
//
// Required on the Jenkins side (see jenkins/README.md):
//   Tools/plugins : SonarQube Scanner, NodeJS-less agent (Node 22 installed by jenkins-agent-setup.sh),
//                   Pipeline Utility Steps, Timestamper, AnsiColor, (optional) Nexus Artifact Uploader
//   Credentials   : 'github-pat' (username + token, repo write access)
//   Sonar server  : configured under the name 'sonarqube'; scanner tool named 'sonar-scanner'
//   AWS access    : instance profile on the agent (ECR push) - no static keys in Jenkins

pipeline {
    agent { label 'AGENT-1' }

    options {
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timestamps()
        ansiColor('xterm')
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region of the ECR registry')
        booleanParam(name: 'FAIL_ON_VULNERABILITIES', defaultValue: true, description: 'Fail the build on HIGH/CRITICAL fixable vulnerabilities')
        booleanParam(name: 'PUBLISH_TO_NEXUS', defaultValue: false, description: 'Also archive the backend as a zip in Nexus (optional)')
    }

    environment {
        BACKEND_REPO  = 'expense-backend'
        FRONTEND_REPO = 'expense-frontend'
        GITOPS_VALUES = 'gitops/environments/dev/values.yaml'
        NEXUS_URL     = 'nexus.example.com:8081'   // only used when PUBLISH_TO_NEXUS=true
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    env.SKIP_CI = 'false'
                    def lastMessage = sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
                    if (lastMessage.contains('[skip ci]')) {
                        env.SKIP_CI = 'true'
                        currentBuild.result = 'NOT_BUILT'
                        echo 'Last commit is a GitOps promotion ([skip ci]); nothing to do.'
                        return
                    }
                    def version = readJSON(file: 'backend/package.json').version
                    def shortSha = sh(returnStdout: true, script: 'git rev-parse --short=7 HEAD').trim()
                    env.APP_VERSION = version
                    env.IMAGE_TAG   = "${version}-${env.BUILD_NUMBER}-${shortSha}"   // unique: ECR tags are immutable
                    env.AWS_ACCOUNT = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text').trim()
                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Pipeline') {
            when { expression { env.SKIP_CI != 'true' } }
            stages {

                stage('Test & Build') {
                    parallel {
                        stage('Backend: unit tests') {
                            steps {
                                dir('backend') {
                                    sh 'npm ci'
                                    sh 'npm test'
                                }
                            }
                        }
                        stage('Frontend: build') {
                            steps {
                                dir('frontend') {
                                    sh 'npm ci'
                                    sh 'npm run build'
                                }
                            }
                        }
                    }
                }

                stage('SonarQube analysis') {
                    steps {
                        script {
                            def scannerHome = tool 'sonar-scanner'
                            withSonarQubeEnv('sonarqube') {
                                sh "${scannerHome}/bin/sonar-scanner -Dsonar.projectVersion=${env.APP_VERSION}"
                            }
                        }
                    }
                }

                stage('Quality Gate') {
                    steps {
                        timeout(time: 10, unit: 'MINUTES') {
                            waitForQualityGate abortPipeline: true
                        }
                    }
                }

                stage('Trivy: source & IaC scan') {
                    steps {
                        // Blocking: known-vulnerable dependencies and leaked secrets
                        sh """
                            trivy fs --scanners vuln,secret \
                                --severity HIGH,CRITICAL --ignore-unfixed \
                                --exit-code ${params.FAIL_ON_VULNERABILITIES ? 1 : 0} \
                                --skip-dirs node_modules .
                        """
                        // Informational: Terraform / Helm / Dockerfile misconfigurations
                        sh '''
                            trivy config --severity HIGH,CRITICAL --exit-code 0 \
                                --format table --output trivy-config-report.txt .
                        '''
                    }
                }

                stage('Docker build') {
                    steps {
                        sh """
                            docker build -t ${BACKEND_REPO}:${IMAGE_TAG}  backend
                            docker build -t ${FRONTEND_REPO}:${IMAGE_TAG} frontend
                        """
                    }
                }

                stage('Trivy: image scan') {
                    steps {
                        sh """
                            for image in ${BACKEND_REPO} ${FRONTEND_REPO}; do
                              trivy image --severity HIGH,CRITICAL --ignore-unfixed \
                                  --exit-code ${params.FAIL_ON_VULNERABILITIES ? 1 : 0} \
                                  \$image:${IMAGE_TAG}
                            done
                        """
                    }
                }

                stage('Push to ECR') {
                    when { branch 'main' }
                    steps {
                        sh """
                            aws ecr get-login-password --region ${params.AWS_REGION} | \
                                docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            for repo in ${BACKEND_REPO} ${FRONTEND_REPO}; do
                              docker tag  \$repo:${IMAGE_TAG} ${ECR_REGISTRY}/\$repo:${IMAGE_TAG}
                              docker push ${ECR_REGISTRY}/\$repo:${IMAGE_TAG}
                            done
                        """
                    }
                }

                stage('Archive in Nexus (optional)') {
                    when { allOf { branch 'main'; expression { params.PUBLISH_TO_NEXUS } } }
                    steps {
                        sh "cd backend && zip -q -r ../backend-${APP_VERSION}.zip src package.json package-lock.json"
                        nexusArtifactUploader(
                            nexusVersion: 'nexus3',
                            protocol: 'http',
                            nexusUrl: env.NEXUS_URL,
                            groupId: 'com.expense',
                            version: env.APP_VERSION,
                            repository: 'backend',
                            credentialsId: 'nexus-auth',
                            artifacts: [[artifactId: 'backend', classifier: '', file: "backend-${env.APP_VERSION}.zip", type: 'zip']]
                        )
                    }
                }

                stage('GitOps promotion') {
                    when { branch 'main' }
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'github-pat', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
                            sh '''
                                set -e
                                git config user.name  "jenkins-ci"
                                git config user.email "jenkins-ci@users.noreply.github.com"
                                git fetch origin main
                                git checkout -B main origin/main
                                sed -i -E "s|^(  imageTag:).*|\\1 \\"${IMAGE_TAG}\\"|" "${GITOPS_VALUES}"
                                sed -i -E "s|^(  imageRegistry:).*|\\1 \\"${ECR_REGISTRY}\\"|" "${GITOPS_VALUES}"
                                git add "${GITOPS_VALUES}"
                                if git diff --cached --quiet; then
                                  echo "No change to promote."
                                else
                                  git commit -m "ci: deploy ${IMAGE_TAG} to dev [skip ci]"
                                  AUTH=$(printf 'x-access-token:%s' "${GIT_TOKEN}" | base64 -w0)
                                  git -c http.extraheader="AUTHORIZATION: basic ${AUTH}" push origin main
                                fi
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivy-config-report.txt', allowEmptyArchive: true
            sh 'docker image prune -f || true'
            cleanWs()
        }
        success { echo "Build ${env.IMAGE_TAG} finished. ArgoCD will roll it out within a few minutes." }
        failure { echo 'Build failed - check the stage logs above.' }
    }
}
