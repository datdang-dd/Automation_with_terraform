resource "google_logging_metric" "audit_events_metric" {
  project = var.project_id
  name    = "audit_vm_and_service_changes"

  # dùng đúng filter bạn đã định nghĩa
  filter = <<EOT
    logName = "projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
    AND operation.last = true
    AND (
      protoPayload.methodName = "v1.compute.instances.insert" OR
      protoPayload.methodName = "beta.compute.instances.insert" OR
      
      protoPayload.methodName = "cloud.sql.v1beta4.SqlInstancesService.Insert" OR
      
      protoPayload.methodName = "google.container.v1.ClusterManager.CreateCluster" OR
      
      protoPayload.methodName = "storage.buckets.create" OR
      
      protoPayload.methodName = "google.cloud.run.v2.Services.CreateService" OR
      
      protoPayload.methodName = "google.cloud.bigquery.v2.TableService.InsertTable" OR
      protoPayload.methodName = "google.cloud.bigquery.v2.DatasetService.InsertDataset" OR
      
      protoPayload.methodName = "google.cloud.aiplatform.v1.EndpointService.CreateEndpoint" OR
      protoPayload.methodName = "google.cloud.aiplatform.v1.JobService.CreateCustomJob" OR
      protoPayload.methodName = "google.cloud.aiplatform.v1.ModelService.UploadModel" OR
      protoPayload.methodName = "google.api.serviceusage.v1.ServiceUsage.EnableService" OR
      protoPayload.methodName = "google.api.servicemanagement.v1.ServiceManager.EnableService" OR
      protoPayload.methodName = "v1.compute.networks.insert" 
    )
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    display_name = "VM + Service changes (audit)"
  }
}

resource "google_monitoring_notification_channel" "chat" {
  project      = var.project_id
  display_name = "Google Chat – Audit Alerts"
  type         = "google_chat"

  labels = {
    space = "spaces/AAQAGKxqmro"
  }
}

resource "google_monitoring_alert_policy" "audit_events_to_chat" {
  project      = var.project_id
  display_name = "Audit: VM & Service changes → Google Chat"
  
  # Quan trọng: Kết hợp 2 điều kiện bằng OR (VM hoặc Service đều báo)
  combiner     = "OR" 

  # --- CONDITION 1: Compute/App Created (VM, GKE, Cloud Run) ---
  conditions {
    display_name = "Compute/App Created (VM, GKE, Cloud Run)"
    condition_threshold {
      # Gom nhóm các resource type vật lý
      filter = <<EOT
        metric.type="logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}" AND 
        (
          resource.type = "gce_instance" OR 
          resource.type = "gke_cluster" OR 
          resource.type = "cloud_run_service" OR
          resource.type = "cloud_run_revision" OR
          resource.type = "gce_network"
        )
      EOT
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
      comparison = "COMPARISON_GT"
      threshold_value = 0
      duration = "0s"
      trigger { count = 1 }
    }
  }

  # --- CONDITION 2: Data/Storage Created (SQL, BQ, GCS) ---
  conditions {
    display_name = "Data/Storage Created (SQL, BQ, GCS)"
    condition_threshold {
      # Gom nhóm Database, IAM và API
      filter = <<EOT
        metric.type="logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}" AND 
        (
          resource.type = "cloudsql_database" OR 
          resource.type = "bigquery_dataset" OR 
          resource.type = "bigquery_resource" OR 
          resource.type = "gcs_bucket"
        )
      EOT
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
      comparison = "COMPARISON_GT"
      threshold_value = 0
      duration = "0s"
      trigger { count = 1 }
    }
  }

# --- CONDITION 3: VERTEX AI & OTHERS ---
  conditions {
    display_name = "Vertex AI / Other API"
    condition_threshold {
      # Gom nhóm Database, IAM và API
      filter = <<EOT
        metric.type="logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}" AND 
        (
          resource.type = "aiplatform_endpoint" OR 
          resource.type = "aiplatform_job" OR
          resource.type = "audited_resource"
        )
      EOT
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
      comparison = "COMPARISON_GT"
      threshold_value = 0
      duration = "0s"
      trigger { count = 1 }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.chat.id
  ]
  
  enabled = true
}


