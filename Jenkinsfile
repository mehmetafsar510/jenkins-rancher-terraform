pipeline {
    agent any
    environment {
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        APP_NAME="phonebook"
        AWS_ACCOUNT_ID=sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        AWS_REGION="us-east-1"
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        RANCHER_URL="https://rancher.mehmetafsar.net"
        // Get the project-id from Rancher UI (petclinic-cluster-staging namespace, View in API, copy projectId )
        RANCHER_CONTEXT="phonebook-cluster:project-id" 
        RANCHER_CREDS=credentials('rancher-phonebook-credentials')
        CFN_KEYPAIR="the-doctor"
        MYSQL_DATABASE_PASSWORD = "Clarusway"
        MYSQL_DATABASE_USER = "admin"
        MYSQL_DATABASE_DB = "phonebook"
        MYSQL_DATABASE_PORT = 3306
        APP_REPO = "phonebook/app"
        APP_REPO_NAME = "mehmetafsar510"
        CLUSTER_NAME = "mehmet-cluster"
        FQDN = "phonebook.mehmetafsar.net"
        DOMAIN_NAME = "mehmetafsar.net"
        NM_SP = "phone"
        GIT_FOLDER = sh(script:'echo ${GIT_URL} | sed "s/.*\\///;s/.git$//"', returnStdout:true).trim()
    }
    stages{
        stage('Setup kubectl helm and eksctl binaries') {
            steps {
              script {

                println "Getting the kubectl helm and rke binaries..."
                sh """
                  curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.9/2020-08-04/bin/linux/amd64/kubectl
                  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
                  chmod 700 get_helm.sh
                  curl -SsL "https://github.com/rancher/rke/releases/download/v1.1.12/rke_linux-amd64" -o "rke_linux-amd64"
                  sudo mv rke_linux-amd64 /usr/local/bin/rke
                  chmod +x /usr/local/bin/rke
                  rke --version
                  chmod +x ./kubectl
                  sudo mv ./kubectl /usr/local/bin
                  ./get_helm.sh
                  curl -SsL "https://github.com/rancher/cli/releases/download/v2.4.9/rancher-linux-amd64-v2.4.9.tar.gz" -o "rancher-cli.tar.gz"
                  tar -zxvf rancher-cli.tar.gz
                  sudo mv ./rancher-v2.4.9/rancher /usr/local/bin/rancher
                  chmod +x /usr/local/bin/rancher
                  rancher --version
                """
              }
            }
        } 

        stage("compile"){
           agent{
               docker{
                   image 'python:alpine'
               }
           }
           steps{
               withEnv(["HOME=${env.WORKSPACE}"]) {
                    sh 'pip install -r requirements.txt'
                    sh 'python -m py_compile src/*.py'
                    stash(name: 'compilation_result', includes: 'src/*.py*')
                }
           }
        }

        stage('creating RDS for test stage'){
            agent any
            steps{
                echo 'creating RDS for test stage'
                sh '''
                    RDS=$(aws rds describe-db-instances --region ${AWS_REGION}  | grep mysql-instance |cut -d '"' -f 4| head -n 1)  || true
                    if [ "$RDS" == '' ]
                    then
                        aws rds create-db-instance \
                          --region ${AWS_REGION} \
                          --db-instance-identifier mysql-instance \
                          --db-instance-class db.t2.micro \
                          --engine mysql \
                          --db-name ${MYSQL_DATABASE_DB} \
                          --master-username ${MYSQL_DATABASE_USER} \
                          --master-user-password ${MYSQL_DATABASE_PASSWORD} \
                          --allocated-storage 20 \
                          --tags 'Key=Name,Value=masterdb'
                          
                    fi
                '''
            script {
                while(true) {
                        
                        echo "RDS is not UP and running yet. Will try to reach again after 10 seconds..."
                        sleep(10)

                        endpoint = sh(script:'aws rds describe-db-instances --region ${AWS_REGION} --db-instance-identifier mysql-instance --query DBInstances[*].Endpoint.Address --output text | sed "s/\\s*None\\s*//g"', returnStdout:true).trim()

                        if (endpoint.length() >= 7) {
                            echo "My Database Endpoint Address Found: $endpoint"
                            env.MYSQL_DATABASE_HOST = "$endpoint"
                            break
                        }
                    }
                }
            }
        }

        stage('create phonebook table in rds'){
            agent any
            steps{
                sh "mysql -u ${MYSQL_DATABASE_USER} -h ${MYSQL_DATABASE_HOST} -p${MYSQL_DATABASE_PASSWORD} < phonebook.sql"
            }
        } 
       
        stage('test'){
            agent {
                docker {
                    image 'python:alpine'
                }
            }
            steps {
                withEnv(["HOME=${env.WORKSPACE}"]) {
                    sh 'python -m pytest -v --junit-xml results.xml src/appTest.py'
                }
            }
            post {
                always {
                    junit 'results.xml'
                }
            }
        }  

        stage('creating .env for docker-compose'){
            agent any
            steps{
                script {
                    echo 'creating .env for docker-compose'
                    sh "cd ${WORKSPACE}"
                    writeFile file: '.env', text: "ECR_REGISTRY=${ECR_REGISTRY}\nAPP_REPO_NAME=${APP_REPO}:latest"
                }
            }
        }

        stage('creating ECR Repository'){
            agent any
            steps{
                echo 'creating ECR Repository'
                sh '''
                    RepoArn=$(aws ecr describe-repositories --region ${AWS_REGION} | grep ${APP_REPO} |cut -d '"' -f 4| head -n 1 )  || true
                    if [ "$RepoArn" == '' ]
                    then
                        aws ecr create-repository \
                          --repository-name ${APP_REPO} \
                          --image-scanning-configuration scanOnPush=false \
                          --image-tag-mutability MUTABLE \
                          --region ${AWS_REGION}
                        
                    fi
                '''
            }
        } 

        stage('build'){
            agent any
            steps{
                sh "docker build -t ${APP_REPO} ."
                sh 'docker tag ${APP_REPO} "$ECR_REGISTRY/$APP_REPO:latest"'
            }
        }

        stage('push'){
            agent any
            steps{
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO:latest"'
            }
        }

        stage('compose'){
            agent any
            steps{
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh "docker-compose up -d"
            }
        }

        stage('Build Docker Result Image') {
			steps {
				sh 'docker build -t phonebook:latest ${GIT_URL}#:result'
				sh 'docker tag phonebook:latest $APP_REPO_NAME/phonebook-result:latest'
				sh 'docker tag phonebook:latest $APP_REPO_NAME/phonebook-result:${BUILD_ID}'
				sh 'docker images'
			}
		}
        stage('Build Docker Update Image') {
			steps {
				sh 'docker build -t phonebook:latest ${GIT_URL}#:kubernetes'
				sh 'docker tag phonebook:latest $APP_REPO_NAME/phonebook-update:latest'
				sh 'docker tag phonebook:latest $APP_REPO_NAME/phonebook-update:${BUILD_ID}'
				sh 'docker images'
			}
		}
		stage('Push Result Image to Docker Hub') {
			steps {
				withDockerRegistry([ credentialsId: "dockerhub_id", url: "" ]) {
				sh 'docker push $APP_REPO_NAME/phonebook-update:latest'
				sh 'docker push $APP_REPO_NAME/phonebook-update:${BUILD_ID}'
				}
			}
		}
        stage('Push Update Image to Docker Hub') {
			steps {
				withDockerRegistry([ credentialsId: "dockerhub_id", url: "" ]) {
				sh 'docker push $APP_REPO_NAME/phonebook-result:latest'
				sh 'docker push $APP_REPO_NAME/phonebook-result:${BUILD_ID}'
				}
			}
		}

        stage('get-keypair'){
            agent any
            steps{
                sh '''
                    if [ -f "${CFN_KEYPAIR}.pem" ]
                    then 
                        echo "file exists..."
                    else
                        aws ec2 create-key-pair \
                          --region ${AWS_REGION} \
                          --key-name ${CFN_KEYPAIR} \
                          --query KeyMaterial \
                          --output text > ${CFN_KEYPAIR}.pem

                        chmod 400 ${CFN_KEYPAIR}.pem
                        
                        ssh-keygen -y -f ${CFN_KEYPAIR}.pem >> ${CFN_KEYPAIR}.pub
                        mkdir -p ${JENKINS_HOME}/.ssh
                        cp -f ${CFN_KEYPAIR}.pem ${JENKINS_HOME}/.ssh
                        cp -f ${CFN_KEYPAIR}.pub ${JENKINS_HOME}/.ssh
                        chown jenkins:jenkins ${JENKINS_HOME}/.ssh/${CFN_KEYPAIR}.pem
                        chown jenkins:jenkins ${JENKINS_HOME}/.ssh/${CFN_KEYPAIR}.pub
                    fi
                '''                
            }
        }


        stage('create infrastructure with terraform'){
            agent any
            steps{
                withAWS(credentials: 'mycredentials', region: 'us-east-1') {
                    sh "sed -i 's|{{keypair}}|${CFN_KEYPAIR}|g' main.tf"
                    sh "sed -i 's|{{keypairpub}}|${CFN_KEYPAIR}.pub|g' main.tf"
                    sh "JENKINS_IP=curl http://169.254.169.254/latest/meta-data/public-ipv4"
                    sh "sed -i 's|{{jenkinsip}}|${JENKINS_IP}|g' locals.tf"
                    sh "terraform init" 
                    sh "terraform apply -input=false -auto-approve"
                }    
            }
        }

        stage('Rancher instance publicip') {
            steps {
                echo 'Rancher instance public'
            script {
                while(true) {
                        
                        echo "Rancher Master is not UP and running yet. Will try to reach again after 10 seconds..."
                        sleep(10)

                        ip = sh(script:'aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=rancher-instance  --query Reservations[*].Instances[*].[PublicIpAddress] --output text | sed "s/\\s*None\\s*//g"', returnStdout:true).trim()

                        if (ip.length() >= 7) {
                            echo "Rancher Master Public Ip Address Found: $ip"
                            env.MASTER_INSTANCE_PUBLIC_IP = "$ip"
                            sleep(30)
                            break
                        }
                    }
                }
            }
        }

        stage('Rancher instance privateip') {
            steps {
                echo 'Rancher instance private'
            script {
                while(true) {
                        
                        echo "Rancher Master is not UP and running yet. Will try to reach again after 10 seconds..."
                        sleep(10)

                        ip = sh(script:'aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=rancher-instance  --query Reservations[*].Instances[*].[PrivateIpAddress] --output text | sed "s/\\s*None\\s*//g"', returnStdout:true).trim()

                        if (ip.length() >= 7) {
                            echo "Rancher Master Private Ip Address Found: $ip"
                            env.MASTER_INSTANCE_PRIVATE_IP = "$ip"
                            sleep(30)
                            break
                        }
                    }
                }
            }
        }

        stage('Configure Rancher yaml') {
            steps { 
                echo "Configure Rancher cluster yaml"
                
                        sh "sed -i 's|{{public}}|${MASTER_INSTANCE_PUBLIC_IP}|g' rancher-cluster.yml"
                        sh "sed -i 's|{{private}}|${MASTER_INSTANCE_PRIVATE_IP}|g' rancher-cluster.yml"
                        sh '''
                        Rancher=$(kubectl get nodes | grep -i worker )  || true
                        if [ "$Rancher" == '' ]
                        then
                            rke up --config ./rancher-cluster.yml
                            mkdir -p ${JENKINS_HOME}/.kube
                            mv -f ./kube_config_rancher-cluster.yml ${JENKINS_HOME}/.kube/config
                            chmod 400 ${JENKINS_HOME}/.kube/config
                            kubectl get nodes
                        fi
                        '''
                        sh "helm repo add rancher-latest https://releases.rancher.com/server-charts/latest"
                        sh "helm repo list"
                        sh '''
                        NameSpaces=$(kubectl get namespaces | grep -i cattle-system) || true
                        if [ "$NameSpaces" == '' ]
                        then
                            kubectl create namespace cattle-system

                        fi
                        '''
                        sh '''
                        helm install rancher rancher-latest/rancher \
                            --namespace cattle-system \
                            --set hostname=$RANCHER_URL \
                            --set tls=external \
                            --set replicas=2
                        '''
                        sh "kubectl -n cattle-system get deploy rancher"
                    }
                }

        stage('Test login rancher cluster') {
            steps {
                withAWS(credentials: 'mycredentials', region: 'us-east-1') {
                    echo "Testing if the K8s cluster is ready or not"
                script {
                    while(true) {
                        try {
                          sh "rancher login $RANCHER_URL --context $RANCHER_CONTEXT --token $RANCHER_CREDS_USR:$RANCHER_CREDS_PSW"
                          echo "Successfully login Rancher cluster."
                          break
                        }
                        catch(Exception) {
                          echo 'Could not login cluster please wait'
                          sleep(5)  
                        } 
                    }
                }
            }
        }
    }


        stage('Deploy App on  Kubernetes Cluster'){
            steps {
                echo 'Deploying App on K8s Cluster'
                sh "rancher login $RANCHER_URL --context $RANCHER_CONTEXT --token $RANCHER_CREDS_USR:$RANCHER_CREDS_PSW"
                sh "rancher kubectl apply -f  storage-class.yaml"
                sh "rancher kubectl apply -f result"
                sh "rancher kubectl apply -f kubernetes"
            }
        }
        
    }
    post {
        always {
            echo 'Deleting all local images'
            sh 'docker image prune -af'
        }
    }
}