resource "google_compute_instance_template" "tpl" {
  name_prefix  = "web-tpl-"
  machine_type = var.machine_type
  tags         = var.target_tags

  service_account {
    email  = var.service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Boot disk
  disk {
    auto_delete  = true
    boot         = true
    type         = "pd-balanced"
    disk_size_gb = 10
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
  }

  # >>> Disk phụ stateful (device_name = "data")
  disk {
    device_name = "data"
    auto_delete = false
    boot        = false
    type         = "PERSISTENT"
    source_snapshot = var.data_disk_snapshot_name
    disk_type = var.extra_disk_type
    disk_size_gb = var.extra_disk_size_gb
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    "ssh-keys" = var.ssh_public_key
  }

  metadata_startup_script = file("${path.module}/startup_stateful.sh")
}

resource "google_compute_instance_group_manager" "mig" {
  name               = "web-mig-zonal"
  zone               = var.zone
  base_instance_name = "web"
  target_size        = var.size_min
  named_port { 
    name = "http"
    port = 80 
  }

  version { instance_template = google_compute_instance_template.tpl.id }

  update_policy {
    type                    = "PROACTIVE"
    minimal_action          = "REPLACE"
    replacement_method      = "RECREATE"
    max_surge_percent       = 0
    max_unavailable_percent = 50
  }

  # Mark disk "data" là stateful → KHÔNG xoá khi thay thế VM
  stateful_disk {
    device_name = "data"
    delete_rule = "NEVER"
  }
}

resource "google_compute_disk" "bastion_data" {
  name  = "bastion-data-disk"
  type  = "pd-balanced"
  zone  = var.zone
  size  = 20   

  lifecycle {
    prevent_destroy = true   # chống destroy nhầm
  }

  labels = {
    purpose = "bastion-data"
    managed = "terraform"
  }  
}

# Bastion có IP PUBLIC và tag "allow-ssh1"
resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-medium"
  zone         = var.zone
  allow_stopping_for_update = true

  boot_disk {
    initialize_params { image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts" }
  }

  attached_disk {
    source      = google_compute_disk.bastion_data.id
    device_name = "bastion-data"
    mode        = "READ_WRITE"
  }

  network_interface {
    subnetwork   = var.subnetwork_self_link
    access_config {}
  }

service_account {
    email  = var.service_account         # truyền từ root (module.security.sa_email)
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  

  # STARTUP: write SA json from GOOGLE_CREDENTIALS, set ADC, install Docker, run Grafana, provision GCM datasource
  # Tag also for Grafana access rule
  tags = ["allow-ssh1", "allow-grafana"]

  metadata_startup_script = templatefile(
    "${path.module}/grafana_startup.sh.tmpl",
    {
      project_id         = var.project_id         # pass down from root
      grafana_admin_user = var.grafana_admin_user
      grafana_admin_pass = var.grafana_admin_pass
    }
  )

  # Pass values to the startup environment (project id, grafana creds)
  metadata = {
      project_id           = var.project_id
      GRAFANA_ADMIN_USER   = var.grafana_admin_user
      GRAFANA_ADMIN_PASS   = var.grafana_admin_pass
      PROJECT_ID_OVERRIDE  = var.project_id
      PROJECT_ID          = var.project_id 
      "ssh-keys" = var.ssh_public_key 
    }
}
resource "google_compute_autoscaler" "as" {
  name   = "web-as"
  zone   = var.zone
  target = google_compute_instance_group_manager.mig.id

  autoscaling_policy {
    mode = "ONLY_UP"
    min_replicas = var.size_min
    max_replicas = var.size_max
    cooldown_period = 120
    cpu_utilization { target = 0.8 }
  }
}
