variable "region"               { type = string }
variable "project_id" {
  type = string
}
variable "zone" {
  type = string
}
variable "machine_type"         { type = string }
variable "ssh_public_key"       { type = string }
variable "subnetwork_self_link" { type = string }
variable "target_tags"          { type = list(string) }
variable "service_account"      { type = string }
variable "size_min" { 
    type = number
    default = 2
  }
variable "size_max"  { 
    type = number
    default = 3
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_pass" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_allowed_cidr" {
  description = "CIDR allowed to access Grafana (port 3000)"
  type        = string
  default     = "0.0.0.0/0" # change to your office IP/CIDR
}

variable "extra_disk_enabled" {
  description = "Whether to create and attach an extra persistent disk to each MIG instance."
  type        = bool
  default     = true
}

variable "extra_disk_size_gb" {
  description = "Size (GB) for the extra persistent disk attached to each instance when enabled."
  type        = number
  default     = 10
}

variable "extra_disk_type" {
  description = "Disk type for the extra persistent disk (e.g. pd-standard, pd-balanced, pd-ssd)."
  type        = string
  default     = "pd-balanced"
}

variable "extra_disk_auto_delete" {
  description = "Whether the extra persistent disk should be auto-deleted when the instance is deleted. Set false to preserve the disk."
  type        = bool
  default     = false
}

variable "bucket_name" {
  description = "GCS bucket name which stores web artifact zip"
  type        = string
}

variable "data_disk_snapshot_name" {
  type = string
  default = "snap-shot-disk"
}
