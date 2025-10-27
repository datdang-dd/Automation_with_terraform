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
    resource_policies = [google_compute_resource_policy.snapshot_policy.id]
  }

  # >>> Disk phụ stateful (device_name = "data")
  disk {
    device_name = "data"
    auto_delete = false
    boot        = false
    type         = "PERSISTENT"
    disk_type = var.extra_disk_type
    disk_size_gb = var.extra_disk_size_gb
  }

  network_interface {
    subnetwork = var.subnetwork_self_link
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata = length(var.ssh_public_key) > 0 ? {
    "ssh-keys"       = var.ssh_public_key
  } : null

  metadata_startup_script = <<-BASH
    #!/usr/bin/env bash
    set -euxo pipefail
    DEV="/dev/disk/by-id/google-data"   # device_name = "data"
    MNT="/mnt/data"
    mkdir -p "$MNT"
    if ! blkid "$DEV" >/dev/null 2>&1; then
      mkfs.ext4 -F "$DEV"
    fi
    mount "$DEV" "$MNT" || true
    grep -q "$DEV" /etc/fstab || echo "$DEV $MNT ext4 defaults,nofail 0 2" >> /etc/fstab
  BASH
}


# Snapshot policy for MIG instances - creates snapshot after 7 days, deletes after another 7 days
# This uses a weekly schedule that creates snapshots every 7 days and keeps them for 7 days
resource "google_compute_resource_policy" "snapshot_policy" {
  name   = "mig-snapshot-policy"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      weekly_schedule {
        day_of_weeks {
          day        = "TUESDAY"
          start_time = "13:00"
        }
      }
    }
    
    retention_policy {
      max_retention_days    = 7
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
    
    snapshot_properties {
      labels = {
        environment = "production"
        managed_by  = "terraform"
        mig_name    = "web-mig"
        schedule_type = "weekly"
      }
      storage_locations = [var.region]
    }
  }
}

resource "google_compute_instance_group_manager" "mig" {
  name               = "web-mig-zonal"
  zone               = var.zone
  base_instance_name = "web"
  target_size        = var.size_min

  version { instance_template = google_compute_instance_template.tpl.id }

  update_policy {
    type                    = "PROACTIVE"
    minimal_action          = "REPLACE"
    max_surge_percent       = 50
    max_unavailable_percent = 0
  }

  # Mark disk "data" là stateful → KHÔNG xoá khi thay thế VM
  stateful_disk {
    device_name = "data"
    delete_rule = "NEVER"
  }
}


# Bastion có IP PUBLIC và tag "allow-ssh1"
resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params { image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts" }
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
      "ssh-keys" = var.ssh_public_key 
    }
}
