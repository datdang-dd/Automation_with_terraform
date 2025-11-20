pipeline {
    // Jenkins đang chạy trên bastion luôn => dùng agent any là được
    // (LƯU Ý: Vì đang chạy trên Windows, agent any sẽ dùng môi trường Windows)
    agent any

    options {
        timestamps()
    }
    

    environment {
        // Đường dẫn này nên là đường dẫn Linux nếu Jenkins chạy trên Linux Bastion
        // NHƯNG vì bạn đang chạy trên WINDOWS, đường dẫn này nên được điều chỉnh
        // Nếu file JSON nằm trên Windows, hãy dùng: 'D:\terraform_repo\...'
        GOOGLE_APPLICATION_CREDENTIALS = 'D:/terraform_repo/ardent-disk-474504-c0-6d324316d6fc.json'
        
        TF_WORKDIR = '.'        // vì main.tf ở ngay root repo

        // CẤU HÌNH FILE STATE LOCAL
        // Đây là đường dẫn nơi bạn lưu file tfstate gốc trên máy tính
        // Ví dụ: D:\terraform_state_store\terraform.tfstate
        // Lưu ý: Dùng dấu gạch chéo / hoặc 2 dấu gạch ngược \\ để tránh lỗi
        PATH_TO_LOCAL_STATE = 'D:\terraform.tfstate' 
    }

    stages {
        stage('Checkout') {
            steps {
                // Lấy code từ repo (dùng cấu hình Git của job)
                checkout scm
            }
        }
        
        stage('Verify Path') {
            steps {
                dir("${TF_WORKDIR}") {
                    // Dùng lệnh Windows để kiểm tra xem hệ thống có nhận ra terraform không
                    bat 'where terraform'
                }
            }
        }

        stage('Restore State') {
            steps {
                dir("${TF_WORKDIR}") {
                    script {
                        // Kiểm tra xem file state gốc có tồn tại không trước khi copy
                        if (fileExists(env.PATH_TO_LOCAL_STATE)) {
                            echo "Tim thay file state tai ${env.PATH_TO_LOCAL_STATE}. Dang copy vao workspace..."
                            // Copy file state từ ổ cứng vào thư mục làm việc hiện tại của Jenkins
                            // /Y để ghi đè không cần hỏi
                            bat "copy /Y \"${env.PATH_TO_LOCAL_STATE}\" terraform.tfstate"
                        } else {
                            echo "CANH BAO: Khong tim thay file state tai ${env.PATH_TO_LOCAL_STATE}. Terraform se tao moi (nguy hiem neu resource da ton tai)!"
                        }
                    }
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${TF_WORKDIR}") {
                    // Chuyển từ 'sh' sang 'bat' cho môi trường Windows
                    bat '''
                    terraform init -input=false
                    '''
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir("${TF_WORKDIR}") {
                    // QUAN TRỌNG: Đã đổi từ 'sh' sang 'bat' để chạy được trên Windows
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
            
            // TÙY CHỌN: Sau khi chạy xong (Apply), bạn có thể muốn copy ngược lại state mới
            // vào nơi lưu trữ để cập nhật cho lần sau.
            script {
               bat "copy /Y terraform.tfstate \"${env.PATH_TO_LOCAL_STATE}\""
            }
        }
    }
}