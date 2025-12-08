resource "google_monitoring_uptime_check_config" "web" {
  count        = var.enable_uptime ? 1 : 0
  display_name = "web-uptime"
  timeout      = "10s"

  http_check {
    path = "/"
    port = 80
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.uptime_host     # LB IP hoặc domain
    }
  }
}

############################
# Notification Channel – Email
############################
resource "google_monitoring_notification_channel" "email" {
  display_name = "Ops Alert Email"
  type         = "email"
  labels = {
    email_address = "dangdat10044001@gmail.com"
  }
  # depends_on = [google_project_service.enable_monitoring]
}

############################
# Alert Policies
############################

# CPU High Alert
resource "google_monitoring_alert_policy" "cpu_high" {
  display_name = "High CPU Usage - MIG Instances"
  combiner     = "OR"

  conditions {
    display_name = "CPU Utilization > 90%"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.9
      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  enabled               = true
}

# Memory High Alert
resource "google_monitoring_alert_policy" "memory_high" {
  display_name = "High Memory Usage - MIG Instances"
  combiner     = "OR"

  conditions {
    display_name = "Memory Utilization > 90%"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"agent.googleapis.com/memory/percent_used\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 0.90
      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  enabled               = true
}

# Disk Usage Alert
resource "google_monitoring_alert_policy" "disk_high" {
  display_name = "High Disk Usage - MIG Instances"
  combiner     = "OR"

  conditions {
    display_name = "Disk Usage > 90%"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"agent.googleapis.com/disk/percent_used\" AND metric.labels.device_name=\"sda\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.90
      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  enabled               = true
}

# Uptime Check Failure Alert
resource "google_monitoring_alert_policy" "uptime_failure" {
  count        = var.enable_uptime ? 1 : 0
  display_name = "Uptime Check Failure"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failed"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.5
      trigger {
        count = 1
      }
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  enabled               = true
}




