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
# Alert Policy – CPU High
############################
resource "google_monitoring_alert_policy" "cpu_high" {
  display_name = "High CPU Usage"
  combiner     = "OR"

  conditions {
    display_name = "CPU Utilization > 60%"
    condition_threshold {
      filter           = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\""
      comparison       = "COMPARISON_GT"
      threshold_value  = 0.6
      duration         = "60s"
      trigger { count  = 1 }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
  enabled               = true
  # depends_on            = [google_project_service.enable_monitoring]
}

############################
# Dashboard – MIG Overview
############################
resource "google_monitoring_dashboard" "mig_dashboard" {
  dashboard_json = jsonencode({
    displayName = "MIG Overview - ${var.mig_name}"
    gridLayout  = {
      columns = 2
      widgets = [
        # 1) MIG Size (actual)
        {
          title   = "MIG Size (actual) - ${var.mig_name}"
          xyChart = {
            chartOptions = { mode = "COLOR" }
            dataSets = [
              {
                plotType        = "LINE"
                legendTemplate  = "actual size"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance_group/size\" AND resource.type=\"gce_instance_group\" AND resource.label.\"instance_group_name\"=\"${var.mig_name}\""
                    aggregation = {
                      alignmentPeriod   = "60s"
                      perSeriesAligner  = "ALIGN_MEAN"
                    }
                  }
                }
              }
            ]
            yAxis = { label = "instances", scale = "LINEAR" }
          }
        },

        # 2) MIG Target Size
        {
          title   = "MIG Target Size - ${var.mig_name}"
          xyChart = {
            chartOptions = { mode = "COLOR" }
            dataSets = [
              {
                plotType        = "LINE"
                legendTemplate  = "target size"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance_group/target_size\" AND resource.type=\"gce_instance_group\" AND resource.label.\"instance_group_name\"=\"${var.mig_name}\""
                    aggregation = {
                      alignmentPeriod   = "60s"
                      perSeriesAligner  = "ALIGN_MEAN"
                    }
                  }
                }
              }
            ]
            yAxis = { label = "instances", scale = "LINEAR" }
          }
        },

        # 3) CPU Utilization (avg across instances)
        {
          title   = "CPU Utilization (avg) - project"
          xyChart = {
            chartOptions = { mode = "COLOR" }
            dataSets = [
              {
                plotType        = "LINE"
                legendTemplate  = "avg cpu"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.project_id"]
                    }
                  }
                }
              }
            ]
            yAxis = { label = "ratio", scale = "LINEAR" }
          }
        },

        # 4) Uptime Check Pass Ratio (LB host)
        {
          title   = "Uptime Check Pass Ratio - ${var.uptime_host}"
          xyChart = {
            chartOptions = { mode = "COLOR" }
            dataSets = [
              {
                plotType        = "LINE"
                legendTemplate  = "pass ratio"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND resource.label.\"host\"=\"${var.uptime_host}\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_MEAN"
                      crossSeriesReducer = "REDUCE_MEAN"
                      groupByFields      = ["resource.label.\"host\""]
                    }
                  }
                }
              }
            ]
            yAxis = { label = "ratio", scale = "LINEAR" }
          }
        }
      ]
    }
  })
}


