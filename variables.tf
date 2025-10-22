variable "project_id" { type = string }

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
  default = null 
}
variable "downloader_emails" { 
  type = list(string)
  default = [] 
}

variable "grafana_receive_emails" {
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
variable "dns_zone_name" {
  description = "Optional: use an existing Cloud DNS managed zone name"
  type        = string
  default     = ""
}

variable "dns_name" {
  description = "Optional: dns_name to create a managed zone (must end with a dot), e.g. example.com."
  type        = string
  default     = ""
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

# Grafana SMTP settings (optional)
variable "grafana_smtp_host" {
  type    = string
  default = ""
}

variable "grafana_smtp_port" {
  type    = string
  default = ""
}

variable "grafana_smtp_user" {
  type    = string
  default = ""
}

variable "grafana_smtp_pass" {
  type    = string
  default = ""
}

variable "grafana_smtp_from" {
  type    = string
  default = ""
}

variable "grafana_smtp_skip_verify" {
  type    = string
  default = "false"
}
