resource "google_logging_metric" "audit_events_metric" {
  project = var.project_id
  name    = "audit_vm_and_service_changes"

  # dùng đúng filter bạn đã định nghĩa
  filter = <<EOT
  logName = "projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
  AND (
    protoPayload.methodName = "v1.compute.instances.insert" OR
    protoPayload.methodName = "beta.compute.instances.insert" OR
    protoPayload.methodName = "google.api.serviceusage.v1.ServiceUsage.EnableService" OR
    protoPayload.methodName = "google.api.servicemanagement.v1.ServiceManager.EnableService"
  )
  AND operation.last = true
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

  # ĐIỀU KIỆN 1: Dành cho VM (GCE Instance)
  conditions {
    display_name = "VM Change Detected"
    condition_threshold {
      filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}\" AND resource.type=\"gce_instance\""
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      trigger { count = 1 }
    }
  }

  # ĐIỀU KIỆN 2: Dành cho Service/API (Audited Resource)
  conditions {
    display_name = "Service Change Detected"
    condition_threshold {
      # audited_resource là loại resource chung cho các hành động quản trị API
      filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}\" AND resource.type=\"audited_resource\""
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      trigger { count = 1 }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.chat.id
  ]
  
  enabled = true
}


