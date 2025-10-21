# Bật Cloud Resource Manager API để thao tác IAM trên Project
resource "google_project_service" "enable_crm" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
}

# (Nếu chưa có) đã bật IAM API
resource "google_project_service" "enable_iam" {
  project = var.project_id
  service = "iam.googleapis.com"
}

# Enable Monitoring API for Grafana
resource "google_project_service" "enable_monitoring" {
  project = var.project_id
  service = "monitoring.googleapis.com"
}

# Enable Logging API for Grafana
resource "google_project_service" "enable_logging" {
  project = var.project_id
  service = "logging.googleapis.com"
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


