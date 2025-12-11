variable "project_id" {
  type = string
}

variable "log_filter" {
  type        = string
  description = "Logging filter for audit events to send to Chat"
}

variable "chat_webhook_url" {
  type        = string
  description = "Google Chat incoming webhook URL"
}
