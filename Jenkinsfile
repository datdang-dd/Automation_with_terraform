pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        GOOGLE_APPLICATION_CREDENTIALS = 'D:/terraform_repo/ardent-disk-474504-c0-6d324316d6fc.json'
        TF_WORKDIR          = '.'
        PATH_TO_LOCAL_STATE = 'D:\\terraform.tfstate'
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
        success {
            script {
                // Lưu tf.plan khi build thành công (nếu có)
                if (fileExists('tf.plan')) {
                    archiveArtifacts artifacts: 'tf.plan', onlyIfSuccessful: true
                }

                // Chỉ update state trên ổ D khi APPLY (tức là nhánh main và là merge PR)
                if (env.GIT_BRANCH == 'origin/main') {
                    echo "Cap nhat file state moi ve ${env.PATH_TO_LOCAL_STATE}"
                    bat "copy /Y terraform.tfstate \"${env.PATH_TO_LOCAL_STATE}\""
                }
            }
        }
    }
}
