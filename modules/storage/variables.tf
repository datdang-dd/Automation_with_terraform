variable "project_id"        { type = string }
variable "region"            { type = string }
variable "bucket_name" {
  type = string
}
variable "downloader_emails" { 
    type = list(string)
    default = [] 
}

# Optional service account that needs write access (e.g., CI/CD)
variable "uploader_service_account" {
  description = "Service account email that can write the bucket (optional)"
  type        = string
  default     = ""
}