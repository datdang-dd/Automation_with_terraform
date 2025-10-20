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
}
