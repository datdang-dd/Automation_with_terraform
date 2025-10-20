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
          title   = "MIG Target Size - ${var.mig_name}"
          xyChart = {
            chartOptions = { mode = "COLOR" }
            dataSets = [
              {
                plotType       = "LINE"
                legendTemplate = "target size"
                timeSeriesQuery = {
                  timeSeriesQueryLanguage = <<-MQL
                    fetch gce_instance_group_manager
                    | metric 'compute.googleapis.com/instance_group_manager/target_size'
                    | filter resource.instance_group_manager_name == '${var.mig_name}'
                      && resource.location == '${var.region}'
                    | align mean(1m)
                    | every 1m
                  MQL
                }
              }
            ]
            yAxis = { label = "instances", scale = "LINEAR" }
          }
        },

        # 2) MIG Target Size
        {
        title   = "MIG Managed Instance Count - ${var.mig_name}"
        xyChart = {
          chartOptions = { mode = "COLOR" }
          dataSets = [
            {
              plotType       = "LINE"
              legendTemplate = "managed instances"
              timeSeriesQuery = {
                timeSeriesQueryLanguage = <<-MQL
                  fetch gce_instance_group_manager
                  | metric 'compute.googleapis.com/instance_group_manager/instance_count'
                  | filter resource.instance_group_manager_name == '${var.mig_name}'
                    && resource.location == '${var.region}'
                  | align mean(1m)
                  | every 1m
                MQL
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
                plotType       = "LINE"
                legendTemplate = "pass ratio"
                timeSeriesQuery = {
                  timeSeriesQueryLanguage = <<-MQL
                    fetch uptime_url
                    | metric 'monitoring.googleapis.com/uptime_check/check_passed'
                    | filter resource.host == '${var.uptime_host}'
                    | group_by [], mean(val())
                    | align mean(1m)
                    | every 1m
                  MQL
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


