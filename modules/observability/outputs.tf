output "uptime_check_name" {
  value       = var.enable_uptime ? google_monitoring_uptime_check_config.web[0].name : null
  description = "Uptime check config name (if enabled)"
}

output "alert_policy_cpu_name" {
  value       = google_monitoring_alert_policy.cpu_high.name
  description = "Alert policy name for high CPU"
}

output "alert_policy_memory_name" {
  value       = google_monitoring_alert_policy.memory_high.name
  description = "Alert policy name for high memory"
}

output "alert_policy_disk_name" {
  value       = var.enable_disk_alert ? google_monitoring_alert_policy.disk_high[0].name : null
  description = "Alert policy name for high disk usage"
}

output "notification_channel_email" {
  value       = google_monitoring_notification_channel.email.id
  description = "Email notification channel ID"
}