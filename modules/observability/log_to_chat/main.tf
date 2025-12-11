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
  combiner     = "OR"

  conditions {
    display_name = "Any VM or Service change (audit log)"

    condition_threshold {
      # metric.type = logging.googleapis.com/user/<metric_name>
      filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.audit_events_metric.name}\""

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.chat.id
  ]

  documentation {
    content  = "Alert when a GCE instance is created or a GCP API/service is enabled (based on Cloud Audit Logs)."
    mime_type = "text/markdown"
  }

  enabled = true
}


