pipeline {
    agent any

    options {
        timestamps()
    }
    environment {
        // Đường dẫn tuyệt đối tới file JSON service account trên bastion
        GOOGLE_APPLICATION_CREDENTIALS = 'D:/terraform_repo/ardent-disk-474504-c0-6d324316d6fc.json'
        TF_WORKDIR = '.'       // vì main.tf ở ngay root repo
    }

    stages {
        stage('Checkout') {
            steps {
                // Lấy code từ repo (dùng cấu hình Git của job)
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${TF_WORKDIR}") {
                    bat '''
                      terraform init -input=false
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir("${TF_WORKDIR}") {
                    bat '''
                      terraform plan -input=false -no-color -out=tf.plan
                    '''
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: 'tf.plan', onlyIfSuccessful: true
        }
    }
}
