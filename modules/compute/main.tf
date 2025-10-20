resource "google_compute_instance_template" "tpl" {
  name_prefix  = "web-tpl-"
  machine_type = var.machine_type
  tags         = var.target_tags          # đảm bảo trong tfvars có ["web"]

  service_account {
    email  = var.service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    type         = "pd-balanced"
    disk_size_gb = 10
  }

  network_interface {
    subnetwork = var.subnetwork_self_link # VM MIG dùng IP private
    # không thêm access_config {} để giữ private
  }
  lifecycle {
    prevent_destroy = true          # KHÔNG cho phép xóa
    ignore_changes  = all           # KHÔNG cập nhật hay ghi đè nếu có thay đổi
  }

  # !!! chú ý: var.ssh_public_key phải là "username:<nội_dung gcp_id.pub>"
  metadata = length(var.ssh_public_key) > 0 ? { 
    ssh-keys = var.ssh_public_key 
    startup-script = file("${path.module}/startup.sh")
    } : null

}

resource "google_compute_region_instance_group_manager" "mig" {
  name               = "web-mig"
  region             = var.region
  base_instance_name = "web"

  version { instance_template = google_compute_instance_template.tpl.id }
  target_size = var.size_min
}

resource "google_compute_region_autoscaler" "as" {
  name   = "web-as"
  region = var.region
  target = google_compute_region_instance_group_manager.mig.id

  autoscaling_policy {
    min_replicas = var.size_min
    max_replicas = var.size_max
    cpu_utilization { target = 0.6 }
  }
}

# Bastion có IP PUBLIC và tag "allow-ssh1"
resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
    access_config {}                      # 👈 cấp public IP cho bastion
  }

  # giống MIG: cần "ubuntu:<key>"
  metadata = { ssh-keys = var.ssh_public_key }

  tags = ["allow-ssh1"]                   # 👈 khớp firewall allow-ssh-bastion
}
