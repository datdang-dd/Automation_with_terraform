variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "ai_service_image" {
  type        = string
  description = "Container image for AI log analyzer (Cloud Run)"
}

variable "chat_webhook_url" {
  type        = string
  default     = "https://chat.googleapis.com/v1/spaces/AAQAGKxqmro/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=3GAX29aYu5cZ_CAhSq3EOxRke1jgBHGEGg2iSgtSbmc"
  description = "Google Chat incoming webhook URL"
}

variable "log_filter" {
  type = string
  default = <<EOT
  logName = "projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
  AND (
    protoPayload.methodName = "v1.compute.instances.insert" OR
    protoPayload.methodName = "beta.compute.instances.insert" OR
    protoPayload.methodName = "google.api.serviceusage.v1.ServiceUsage.EnableService" OR
    protoPayload.methodName = "google.api.servicemanagement.v1.ServiceManager.EnableService"
  )
  AND operation.last = true
  EOT
  description = "Cloud Logging filter for logs sent to AI"
}
