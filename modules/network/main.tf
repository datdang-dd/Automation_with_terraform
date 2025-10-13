resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Firewall theo tag "web"
resource "google_compute_firewall" "allow_ssh" {
  name         = "allow-ssh1"
  network      = google_compute_network.vpc.name
  allow        { 
    protocol = "tcp" 
    ports = ["22"] 
}
  source_ranges = var.ssh_cidr
  direction    = "INGRESS"
  target_tags  = ["web"]
}
resource "google_compute_firewall" "allow_http" {
  name         = "allow-http1"
  network      = google_compute_network.vpc.name
  allow        { 
    protocol = "tcp"
    ports = ["80"] 
  }
  source_ranges = ["0.0.0.0/0"]
  direction    = "INGRESS"
  target_tags  = ["web"]
}
resource "google_compute_firewall" "allow_https" {
  name         = "allow-https1"
  network      = google_compute_network.vpc.name
  allow        { 
    protocol = "tcp" 
    ports = ["443"] 
  }
  source_ranges = ["0.0.0.0/0"]
  direction    = "INGRESS"
  target_tags  = ["web"]
}

# Router + NAT để egress không cần public IP
resource "google_compute_router" "cr" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.cr.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
