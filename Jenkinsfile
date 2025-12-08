pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        GOOGLE_APPLICATION_CREDENTIALS = 'D:/terraform_repo/ardent-disk-474504-c0-6d324316d6fc.json'
        TF_WORKDIR          = '.'
        PATH_TO_LOCAL_STATE = 'D:\\terraform_repo\\Automation_with_terraform\\terraform.tfstate'
        GCS_BUCKET_NAME     = 'my-static-web-bucket'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Path') {
            steps {
                dir("${TF_WORKDIR}") {
                    bat 'where terraform'
                }
            }
        }

        stage('Restore State') {
            steps {
                dir("${TF_WORKDIR}") {
                    script {
                        if (fileExists(env.PATH_TO_LOCAL_STATE)) {
                            echo "Tim thay state o ${env.PATH_TO_LOCAL_STATE} -> copy vao workspace"
                            bat "copy /Y \"${env.PATH_TO_LOCAL_STATE}\" terraform.tfstate"
                        } else {
                            echo "CANH BAO: Khong tim thay state o ${env.PATH_TO_LOCAL_STATE}, Terraform se tao moi!"
                        }
                    }
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${TF_WORKDIR}") {
                    echo "Dang khoi tao Terraform..."
                    bat 'terraform state rm module.security.google_project_service.enable_logging[0]'
                    bat 'terraform state rm module.security.google_project_service.enable_monitoring[0]'
                    bat 'terraform init -input=false'
                }
            }
        }

        // PLAN cho nhánh test (không apply)
        stage('Plan (Branch test)') {
            when {
                expression { env.GIT_BRANCH == 'origin/test' }
            }
            steps {
                dir("${TF_WORKDIR}") {
                    echo "Nhanh TEST -> chi PLAN"
                    bat 'terraform plan -input=false -no-color -out=tf.plan'
                }
            }
        }

        // APPLY chỉ khi MERGE vào main
        stage('Apply (Merged into main)') {
            when {
                expression { env.GIT_BRANCH == 'origin/main' }
            }
            steps {
                dir("${TF_WORKDIR}") {
                    echo "Nhanh MAIN + commit MERGE PR -> APPLY"
                    bat 'terraform apply -input=false -auto-approve'
                }
            }
        }
    }

    post {
        always {
            script {
                dir("${TF_WORKDIR}") {
                    // Luon copy state ra D:\ du co loi hay khong (neu ton tai file)
                    if (fileExists('terraform.tfstate')) {
                        echo "Sao chep terraform.tfstate ve ${env.PATH_TO_LOCAL_STATE} (luon thuc hien)"
                        bat "copy /Y terraform.tfstate \"${env.PATH_TO_LOCAL_STATE}\""
                    } else {
                        echo "Khong tim thay terraform.tfstate de sao chep"
                    }
                }
            }
        }
        success {
            script {
                // Lưu tf.plan khi build thành công (nếu có)
                if (fileExists('tf.plan')) {
                    archiveArtifacts artifacts: 'tf.plan', onlyIfSuccessful: true
                }

                dir("${TF_WORKDIR}") {
                    if (fileExists('terraform.tfstate')) {
                        // Upload state file to GCS bucket khi thanh cong
                        echo "Auth service account va upload terraform.tfstate len GCS bucket: ${env.GCS_BUCKET_NAME}"
                        bat "gcloud auth activate-service-account --key-file=\"%GOOGLE_APPLICATION_CREDENTIALS%\""
                        bat "gsutil cp terraform.tfstate gs://${env.GCS_BUCKET_NAME}/terraform.tfstate"
                        echo "Da upload state file len GCS thanh cong!"
                    } else {
                        echo "Khong tim thay terraform.tfstate de upload len GCS"
                    }
                }
            }
        }
    }
}

