resource "google_project_service" "enable_iam" {
  project = var.project_id
  service = "iam.googleapis.com"
}

resource "google_service_account" "sa" {
  depends_on   = [google_project_service.enable_iam]
  account_id   = var.sa_id
  display_name = "Service Account for workloads"
}

resource "google_project_iam_member" "bind" {
  for_each = toset(var.sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.sa.email}"
}