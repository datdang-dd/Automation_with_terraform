resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr         # ví dụ: 10.10.1.0/24
  region        = var.region
  network       = google_compute_network.vpc.id
}

# 1) SSH từ máy bạn vào BASTION (target tag: allow-ssh1)
resource "google_compute_firewall" "allow_ssh_bastion" {
  name         = "allow-ssh-bastion"
  network      = google_compute_network.vpc.name
  direction    = "INGRESS"
  target_tags  = ["allow-ssh1"]           # 👈 bastion sẽ gắn tag này
  source_ranges = var.ssh_cidr            # ví dụ: ["<YOUR_PUBLIC_IP>/32"] hoặc ["0.0.0.0/0"] khi test

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# 2) SSH NỘI BỘ từ BASTION -> các VM WEB trong MIG (target tag: web)
resource "google_compute_firewall" "allow_ssh_internal" {
  name         = "allow-ssh-internal"
  network      = google_compute_network.vpc.name
  direction    = "INGRESS"
  target_tags  = ["web"]                  # 👈 áp lên VM trong MIG
  source_ranges = [var.subnet_cidr]       # 👈 cho phép mọi IP trong subnet (bastion nằm trong đây)

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# HTTP/HTTPS cho web (không đổi)
resource "google_compute_firewall" "allow_http" {
  name         = "allow-http1"
  network      = google_compute_network.vpc.name
  direction    = "INGRESS"
  target_tags  = ["web"]
  source_ranges = ["0.0.0.0/0"]
  allow { 
    protocol = "tcp" 
    ports = ["80"] 
  }
}

resource "google_compute_firewall" "allow_https" {
  name         = "allow-https1"
  network      = google_compute_network.vpc.name
  direction    = "INGRESS"
  target_tags  = ["web"]
  source_ranges = ["0.0.0.0/0"]
  allow { 
    protocol = "tcp"
  ports = ["443"] 
  }
}

# Router + NAT
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

# Get the network of the provided subnetwork
data "google_compute_subnetwork" "bastion_subnet" {
  self_link = var.subnetwork_self_link
}

resource "google_compute_firewall" "allow_grafana" {
  name    = "allow-grafana"
  network = data.google_compute_subnetwork.bastion_subnet.network

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = [var.grafana_allowed_cidr]
  target_tags   = ["allow-grafana"]
}
