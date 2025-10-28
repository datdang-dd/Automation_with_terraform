resource "google_project_service" "enable_monitoring" {
  count   = var.manage_apis ? 1 : 0
  project = var.project_id
  service = "monitoring.googleapis.com"
  disable_on_destroy = false   # luôn giữ API khi destroy
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_service" "enable_logging" {
  count   = var.manage_apis ? 1 : 0
  project = var.project_id
  service = "logging.googleapis.com"
  disable_on_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}

# Bật Cloud Resource Manager API để thao tác IAM trên Project
resource "google_project_service" "enable_crm" {
  count   = var.manage_apis ? 1 : 0
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}

# (Nếu chưa có) đã bật IAM API
resource "google_project_service" "enable_iam" {
  project = var.project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
  lifecycle {
    prevent_destroy = true
  }
}


resource "google_service_account" "sa" {
  depends_on   = [
    google_project_service.enable_iam, 
    google_project_service.enable_crm,
    google_project_service.enable_monitoring,
    google_project_service.enable_logging
  ]
  account_id   = var.sa_id
  display_name = "Service Account for workloads"
}

resource "google_project_iam_member" "bind" {
  for_each = toset(var.sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.sa.email}"

  depends_on = [google_project_service.enable_crm]
}

# Grant admin email access to snapshots and compute resources
resource "google_project_iam_member" "admin_snapshot_access" {
  count   = length(var.admin_email) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/compute.storageAdmin"
  member  = "user:${var.admin_email}"

  depends_on = [google_project_service.enable_crm]
}

# Grant admin email access to view and manage snapshots
resource "google_project_iam_member" "admin_compute_viewer" {
  count   = length(var.admin_email) > 0 ? 1 : 0
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "user:${var.admin_email}"

  depends_on = [google_project_service.enable_crm]
}


