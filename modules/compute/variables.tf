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
    default = 4
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
  default     = "0.0.0.0/32" # change to your office IP/CIDR
}
