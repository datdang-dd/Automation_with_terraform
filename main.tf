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

# 1) Network (VPC + Subnet + Router/NAT + FW)
module "network" {
  source      = "./modules/network"
  project_id  = var.project_id
  region      = var.region
  vpc_name    = "demo1-vpc"
  subnet_name = "demo1-subnet"
  subnet_cidr = var.subnet_cidr
  ssh_cidr    = var.ssh_cidr
}

# 2) Security (Service Account + minimal IAM)
module "security" {
  source      = "./modules/security"
  project_id  = var.project_id
  sa_id       = "sa-web"
  sa_roles    = ["roles/storage.objectViewer"] # có thể thêm/giảm
}

# 3) Compute (Template + MIG + Autoscaler)
module "compute" {
  source         = "./modules/compute"
  region         = var.region
  zone           = var.zone
  machine_type   = var.machine_type
  ssh_public_key = var.ssh_public_key

  subnetwork_self_link = module.network.subnet_self_link
  target_tags          = ["web"]
  service_account      = module.security.sa_email
  size_min             = 2
  size_max             = 6
}

# 4) Load Balancer (HTTP/HTTPS)
module "lb" {
  source       = "./modules/lb"
  region       = var.region
  mig_group    = module.compute.mig_instance_group
  domain       = var.domain        # "" => chỉ tạo HTTP
}

# 5) Storage (Bucket + IAM)
module "storage" {
  source             = "./modules/storage"
  region             = var.region
  project_id         = var.project_id
  bucket_name_opt    = var.bucket_name
  downloader_emails  = var.downloader_emails
}

# 6) Observability (Uptime + Alert)
module "observability" {
  source       = "./modules/observability"
  project_id   = var.project_id
  uptime_host  = var.uptime_host != "" ? var.uptime_host : module.lb.lb_http_ip
}
