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
    
    # Enable auto snapshot policy
    resource_policies = [google_compute_resource_policy.snapshot_policy.id]
  }

  # NOTE: extra disks will be managed as separate `google_compute_disk` resources
  # and attached via per-instance config / stateful disks in the MIG. That
  # allows each instance to keep its disk across recreation.

  network_interface {
    subnetwork = var.subnetwork_self_link # VM MIG dùng IP private
    # không thêm access_config {} để giữ private
  }
  lifecycle {
    # Create the new instance template before destroying the old one so Terraform
    # can perform a smooth swap: new template is created, MIG can be updated to
    # use it (rolling), and only then the old template is removed.
    create_before_destroy = true
  }

  # !!! chú ý: var.ssh_public_key phải là "username:<nội_dung gcp_id.pub>"
  metadata = length(var.ssh_public_key) > 0 ? {
    "ssh-keys" = var.ssh_public_key
  } : null

  # Mount and prepare the per-instance persistent disk named by device_name "data".
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

  # Keep the extra disk (device_name = "data") when instances are replaced
  stateful_disk {
    device_name = "data"
    delete_rule = "NEVER"
  }
}

# Create per-instance persistent disks in the same zone as the MIG
resource "google_compute_disk" "data" {
  count = var.size_min
  name  = "web-${count.index}-data"
  type  = var.extra_disk_type
  zone  = var.zone
  size  = var.extra_disk_size_gb
}

# Attach each created disk to the corresponding instance in the MIG using
# per-instance config (preserved_state). The instance name must match the
# name pattern used by the MIG (base_instance_name + index). Adjust if needed.
resource "google_compute_per_instance_config" "cfg" {
  count                 = var.size_min
  zone                  = var.zone
  instance_group_manager = google_compute_instance_group_manager.mig.name
  name                  = "web-${count.index}"

  preserved_state {
    disk {
      device_name = "data"
      source      = google_compute_disk.data[count.index].self_link
      mode        = "READ_WRITE"
    }
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
