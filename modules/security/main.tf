resource "google_service_account" "sa" {
  account_id   = var.sa_id
  display_name = "Service Account for workloads"
}

# Gán role mức project (least privilege tuỳ biến qua biến sa_roles)
resource "google_project_iam_member" "bind" {
  for_each = toset(var.sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.sa.email}"
}
