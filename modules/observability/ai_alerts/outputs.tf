output "ai_log_analyzer_url" {
  value       = google_cloud_run_service.ai_service.status[0].url
  description = "Cloud Run URL for the AI log analyzer"
}

output "logs_topic" {
  value       = google_pubsub_topic.logs_topic.name
  description = "Pub/Sub topic receiving filtered logs"
}

output "logs_sink_filter" {
  value       = google_logging_project_sink.logs_sink.filter
  description = "Logging filter used for AI monitoring"
}
