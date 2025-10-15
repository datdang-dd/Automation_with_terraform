resource "google_monitoring_uptime_check_config" "web" {
  count        = var.enable_uptime ? 1 : 0          # <— dùng boolean, không phụ thuộc unknown
  display_name = "web-uptime"
  timeout      = "10s"

  http_check { 
    path = "/" 
    port = 80 
  }

  monitored_resource {
    type   = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.uptime_host          # có thể là IP từ LB hoặc domain
    }
  }
}
# Notification channel – Email
resource "google_monitoring_notification_channel" "email" {
  display_name = "Ops Alert Email"
  type         = "email"
  labels = {
    email_address = "dangdat10044001@gmail.com"
  }
}


resource "google_monitoring_alert_policy" "cpu_high" {
  display_name = "High CPU Usage"
  combiner     = "OR"
  conditions {
    display_name = "CPU Utilization > 60%"
    condition_threshold {
      filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\""
      comparison = "COMPARISON_GT"
      threshold_value = 0.6
      duration = "60s"
      trigger { count = 1 }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
  enabled = true
}

