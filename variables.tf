variable "project_id" { 
  type = string
  description = "GCP Project ID"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be a valid GCP project ID (lowercase letters, numbers, hyphens, 6-30 characters)."
  }
}

variable "region"     { 
  type = string
  default = "us-central1" 
}
variable "zone"       { 
  type = string
  default = "us-central1-b" 
}

variable "subnet_cidr" { 
  type = string
  default = "10.10.1.0/24"
  description = "CIDR block for the subnet"
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "Subnet CIDR must be a valid CIDR block (e.g., 10.10.1.0/24)."
  }
}
variable "ssh_cidr"    { 
  type = list(string)
  default = ["0.0.0.0/0"] 
}

variable "machine_type"   { 
  type = string
  default = "e2-micro" 
}
variable "ssh_public_key" { 
  type = string
  default = "" 
}    # nội dung .pub

variable "bucket_name"       { 
  type = string
  default = "my-static-web-bucket" 
}
variable "downloader_emails" { 
  type = list(string)
  default = [] 
}

variable "domain" { 
  type = string
  default = "" 
}  # app.example.com (nếu cần HTTPS)

variable "uptime_host" { 
  type = string
  default = "" 
}  # để override nếu muốn

variable "mig_name" {
  type = string
  default = "web-mig"
}
variable "grafana_admin_pass" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default = "admin"
}
variable "grafana_allowed_cidr" {
  description = "CIDR allowed to access Grafana (port 3000)"
  type        = string
  default     = "0.0.0.0/0" # change to your office IP/CIDR
}
variable "app_version" {
  type = string
  default = "1.0.0"
}

variable "gcp_credentials_path" {
  description = "Path to GCP service account credentials JSON file. Leave empty to use Application Default Credentials."
  type        = string
  default     = "D:/terraform_repo/ardent-disk-474504-c0-6d324316d6fc.json"
  sensitive   = true
}

variable "mig_size_min" {
  description = "Minimum number of instances in the Managed Instance Group"
  type        = number
  default     = 1
}

variable "mig_size_max" {
  description = "Maximum number of instances in the Managed Instance Group"
  type        = number
  default     = 1
}

variable "snapshot_name" {
  description = "Name of the snapshot to use for stateful disk. Leave empty to create new disk."
  type        = string
  default     = "snap-shot-disk"
}

variable "uploader_service_account"{
  description = "Service account email that can write the bucket"
  type        = string
  default     = ""
}