pipeline {
    agent any
    tools {
        terraform 'terraform'
    }

    stages {
        stage('Create Infrastructure for the App') {
            steps {
                sh 'az login --identity'
                dir('/var/lib/jenkins/workspace/Jenkins_project/aks-terraform'){
                    echo 'Creating Infrastructure for the App on AZURE Cloud'
                    sh 'terraform init'
                    sh 'terraform apply --auto-approve'
                }
            }
        }

        stage('Connect to AKS') {
            steps {
                dir('/var/lib/jenkins/workspace/Jenkins_project/aks-terraform'){
                    echo 'Injecting Terraform Output into connection command'
                    script {
                        env.AKS_NAME = sh(script: 'terraform output -raw aks_name', returnStdout:true).trim()
                        env.RG_NAME = sh(script: 'terraform output -raw rg_name', returnStdout:true).trim()
                    }
                    sh 'az aks get-credentials --resource-group ${RG_NAME} --name ${AKS_NAME}'
                }
            }
        }
        stage('Deploy K8s files') {
            steps {
                dir('/var/lib/jenkins/workspace/Jenkins_project/k8s') {
                    sh 'kubectl apply -f .'
                }
            }
        }
        stage('Destroy the Infrastructure') {
            steps{
                timeout(time:5, unit:'DAYS'){
                    input message:'Do you want to terminate?'
                }
                dir('/var/lib/jenkins/workspace/Jenkins_project/aks-terraform'){
                    sh """
                    terraform destroy --auto-approve
                    """
                }
            }
        }
    }
}