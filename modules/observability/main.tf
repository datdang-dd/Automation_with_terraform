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

resource "google_monitoring_alert_policy" "cpu_high" {
  display_name = "CPU > 80%"
  combiner     = "OR"
  conditions {
    display_name = "High CPU"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
}
