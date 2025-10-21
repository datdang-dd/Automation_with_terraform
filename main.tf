terraform {
  required_version = ">= 1.6.0"

  cloud {
    organization = "test_terraform_spi"
    workspaces { name = "test_workspace" }
  }

  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.40" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 1) Network (VPC/Subnet/Router-NAT/Firewall)
module "network" {
  source      = "./modules/network"
  project_id  = var.project_id
  region      = var.region
  vpc_name    = "demo1-vpc"
  subnet_name = "demo1-subnet"
  subnet_cidr = var.subnet_cidr
  ssh_cidr    = var.ssh_cidr
  subnetwork_self_link = module.network.subnet_self_link
  grafana_allowed_cidr= var.grafana_allowed_cidr

}

# 2) Security (Service Account + minimal IAM)
module "security" {
  source    = "./modules/security"

  project_id = var.project_id
  sa_id      = "sa-web"
  sa_roles   = [
    "roles/storage.objectViewer",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/logging.logWriter"
  ]
  admin_email = length(var.downloader_emails) > 0 ? var.downloader_emails[0] : ""
}

# 3) Compute (Template + MIG + Autoscaler + Bastion)
#    All resources are defined INSIDE the module (no duplicates in root)
module "compute" {
  source = "./modules/compute"
  region               = var.region
  zone                 = var.zone
  machine_type         = var.machine_type
  ssh_public_key       = var.ssh_public_key
  subnetwork_self_link = module.network.subnet_self_link
  target_tags          = ["web"]
  service_account      = module.security.sa_email
  project_id = var.project_id
  grafana_admin_user = "admin"
  grafana_admin_pass = var.grafana_admin_pass
}

# 4) Load Balancer (HTTP/HTTPS)
module "lb" {
  source = "./modules/lb"

  region    = var.region
  mig_group = module.compute.mig_instance_group
  domain    = var.domain         # "" -> HTTP only
}

# 5) Storage (Bucket + optional access bindings)
module "storage" {
  source            = "./modules/storage"

  region            = var.region
  project_id        = var.project_id
  bucket_name_opt   = var.bucket_name
  downloader_emails = var.downloader_emails
}

# 6) Observability (Uptime + Alerts)
module "observability" {
  source       = "./modules/observability"
  project_id   = var.project_id
  mig_name     = "web-mig"   # hoặc output từ module compute nếu bạn export
  uptime_host  = var.uptime_host != "" ? var.uptime_host : module.lb.lb_http_ip
  enable_uptime = true
  region = var.region
}



