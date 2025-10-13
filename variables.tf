# ======================== variables.tf ========================
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Default GCP zone"
  type        = string
  default     = "us-central1-b"
}

variable "network_cidr" {
  description = "CIDR for the VPC primary range"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "bucket_name" {
  description = "Name for the GCS bucket (must be globally unique)"
  type        = string
  default     = null
}

variable "vm_name" {
  description = "VM instance name"
  type        = string
  default     = "demo-vm"
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-micro"
}

variable "ssh_public_key" {
  description = "SSH public key to inject for login"
  type        = string
  default     = ""
}

variable "downloader_emails" {
  description = "List of emails that have access to download/upload/delete objects in the bucket"
  type        = list(string)
  default     = []
}
