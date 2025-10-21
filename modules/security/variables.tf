variable "project_id" { type = string }
variable "sa_id"      { 
    type = string 
    default = "vm-service-account"
}
variable "sa_roles"   { 
    type = list(string) 
    default = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/monitoring.objectViewer",
        "roles/storage.objectViewer"
    ] 
}

variable "admin_email" {
  description = "Email address that will have admin access to snapshots"
  type        = string
  default     = ""
}