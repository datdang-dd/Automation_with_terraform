# output "alert_policy_name" {
#   value       = google_monitoring_alert_policy.cpu_high.name
#   description = "Alert policy name for high CPU"
# }

output "uptime_check_name" {
  value       = var.enable_uptime ? google_monitoring_uptime_check_config.web[0].name : null
  description = "Uptime check config name (if enabled)"
}