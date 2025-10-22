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
  default     = "0.0.0.0/0" # change to your office IP/CIDR
}

# Optional SMTP settings for Grafana (leave empty to disable)
variable "grafana_smtp_host" {
  description = "SMTP host for Grafana (e.g. smtp.example.com)"
  type        = string
  default     = "smtp.gmail.com"
}

variable "grafana_smtp_port" {
  description = "SMTP port (e.g. 587). If empty, default port is used by Grafana when host includes port or defaults apply."
  type        = string
  default     = "587"
}

variable "grafana_smtp_user" {
  description = "SMTP username"
  type        = string
  # Default must be a literal; do not reference other variables here.
  # If you want to populate this from the root list `grafana_receive_emails`,
  # pass it explicitly when calling the module (see root `main.tf`).
}

variable "grafana_smtp_pass" {
  description = "SMTP password"
  type        = string
  sensitive   = true
}

variable "grafana_smtp_from" {
  description = "From address for Grafana alert emails (e.g. grafana@example.com)"
  type        = string
  default     = "grafana@testing.com"
}

variable "grafana_smtp_skip_verify" {
  type    = string
  default = "false"

  validation {
    condition     = var.grafana_smtp_skip_verify == "true" || var.grafana_smtp_skip_verify == "false"
    error_message = "grafana_smtp_skip_verify must be \"true\" or \"false\""
  }
}

