resource "google_logging_metric" "audit_events_metric" {
  project = var.project_id
  name    = "audit_vm_and_service_changes"

  # dùng đúng filter bạn đã định nghĩa
  filter = <<EOT
    logName = "projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
    AND operation.last = true
    AND (
      # 1. Compute Engine (VM)
      protoPayload.methodName = "v1.compute.instances.insert" OR
      protoPayload.methodName = "beta.compute.instances.insert" OR

      # 2. Network (VPC, Subnet, Firewall)
      protoPayload.methodName = "v1.compute.networks.insert" OR
      protoPayload.methodName = "v1.compute.subnetworks.insert" OR
      protoPayload.methodName = "v1.compute.firewalls.insert" OR

      # 3. Database (Cloud SQL)
      protoPayload.methodName = "cloud.sql.v1beta4.SqlInstancesService.Insert" OR

      # 4. Kubernetes (GKE Cluster)
      protoPayload.methodName = "google.container.v1.ClusterManager.CreateCluster" OR

      # 5. Storage (GCS Bucket)
      protoPayload.methodName = "storage.buckets.create" OR

      # 6. IAM & Security (Service Account, Keys, Roles)
      protoPayload.methodName = "SetIamPolicy" OR
      protoPayload.methodName = "google.iam.admin.v1.CreateServiceAccountKey" OR

      # 7. Service Management (Enable/Disable API)
      protoPayload.methodName = "google.api.serviceusage.v1.ServiceUsage.EnableService"
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

  # --- CONDITION 1: INFRASTRUCTURE (VM, Network, GKE, Storage) ---
  conditions {
    display_name = "Infrastructure Change (VM/Net/GKE/Storage)"
    condition_threshold {
      # Gom nhóm các resource type vật lý
      filter = <<EOT
        metric.type="logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}" AND 
        (
          resource.type = "gce_instance" OR 
          resource.type = "gce_subnetwork" OR 
          resource.type = "gce_network" OR 
          resource.type = "gce_firewall_rule" OR 
          resource.type = "gke_cluster" OR 
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

  # --- CONDITION 2: SECURITY & SERVICES (IAM, SQL, API) ---
  conditions {
    display_name = "Security/Data/Service Change"
    condition_threshold {
      # Gom nhóm Database, IAM và API
      filter = <<EOT
        metric.type="logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}" AND 
        (
          resource.type = "cloudsql_database" OR 
          resource.type = "service_account" OR 
          resource.type = "project" OR 
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


