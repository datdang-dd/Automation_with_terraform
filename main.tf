# ======================== main.tf ========================

terraform {
  required_version = ">= 1.6.0"

  cloud {
    organization = "test_terraform_spi"           # <-- edit
    workspaces { name = "test_workspace" }  # <-- edit
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Network (VPC, Subnet, Firewall)
resource "google_compute_network" "vpc" {
  name                    = "demo1-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "demo1-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh1"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http1"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_https" {
  name    = "allow-https1"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
}

# GCS bucket
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  resolved_bucket_name = coalesce(var.bucket_name, "demo1-tf-bucket-${var.project_id}-${random_id.suffix.hex}")
}

resource "google_storage_bucket" "bucket" {
  name                        = local.resolved_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  labels = {
    purpose = "practice"
    managed = "terraform"
  }
}

# Compute instance (Ubuntu)
resource "google_compute_instance" "vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {}
  }

  metadata = length(var.ssh_public_key) > 0 ? {
    ssh-keys = var.ssh_public_key
  } : null

  tags = ["allow-ssh1", "allow-http1", "allow-https1"]
}

# IAM binding: cho phép 2 người truy cập và quản lý object trong bucket
resource "google_storage_bucket_iam_binding" "bucket_access" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectAdmin"   # cho phép upload, download, delete object
  members = [
    for email in var.downloader_emails : "user:${email}"
  ]
}
