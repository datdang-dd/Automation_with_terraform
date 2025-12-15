resource "google_monitoring_notification_channel" "chat" {
  project      = var.project_id
  display_name = "Google Chat – Audit Alerts"
  type         = "google_chat"

  labels = {
    # Thay đổi mã Space bên dưới nếu bạn muốn gửi vào phòng chat khác
    space = "spaces/AAQAGKxqmro"
  }
}

resource "google_monitoring_alert_policy" "master_audit_alert" {
  project      = var.project_id
  display_name = "🚨 Security Alert: Critical Resources Created"
  
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Match Critical Audit Logs"
    condition_matched_log {
      filter = <<EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        AND (
          (
            operation.last = true
            AND (
              (resource.type="gce_instance" AND (protoPayload.methodName="v1.compute.instances.insert" OR protoPayload.methodName="beta.compute.instances.insert"))
              OR
              (resource.type="gce_network" AND (protoPayload.methodName="v1.compute.networks.insert" OR protoPayload.methodName="beta.compute.networks.insert"))
              OR
              (resource.type="gke_cluster" AND protoPayload.methodName="google.container.v1.ClusterManager.CreateCluster")
              
              OR
              
              (resource.type="cloudsql_database" AND (protoPayload.methodName="cloudsql.instances.create" OR protoPayload.methodName="cloud.sql.v1beta4.SqlInstancesService.Insert"))
              OR
              (resource.type="gcs_bucket" AND protoPayload.methodName="storage.buckets.create")
              
              OR

              (resource.type="audited_resource" AND (
                protoPayload.methodName="google.api.serviceusage.v1.ServiceUsage.EnableService" OR
                protoPayload.methodName="google.cloud.run.v2.Services.CreateService"
              ))
            )
          )

          OR
          (
            (resource.type="bigquery_dataset" AND (
               protoPayload.methodName="google.cloud.bigquery.v2.DatasetService.InsertDataset" OR
               protoPayload.methodName="google.cloud.bigquery.v2.TableService.InsertTable"
            ))
            
            OR
            (resource.type="audited_resource" AND (
               protoPayload.methodName="google.cloud.aiplatform.v1.EndpointService.CreateEndpoint" OR
               protoPayload.methodName="google.cloud.aiplatform.v1.JobService.CreateCustomJob"
            ))
          )
        )
      EOT
    }
  }

  # Cấu hình auto_close để dọn dẹp dashboard sau 30p
  alert_strategy {
    auto_close = "1800s"
  }

  notification_channels = [google_monitoring_notification_channel.chat.id]
}