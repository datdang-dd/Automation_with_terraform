locals {
  name = var.bucket_name
}

resource "google_storage_bucket" "bucket" {
  name                        = local.name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning { enabled = true }

  lifecycle_rule {
    action    { type = "Delete" }
    condition { age = 90 }
  }

  labels = { purpose = "practice", managed = "terraform" }

  lifecycle {
    prevent_destroy = false          # KHÔNG cho phép xóa
    ignore_changes  = all           # KHÔNG cập nhật hay ghi đè nếu có thay đổi
  }

}

resource "google_storage_bucket_iam_binding" "bucket_access" {
  count   = length(var.downloader_emails) > 0 ? 1 : 0
  bucket  = google_storage_bucket.bucket.name
  role    = "roles/storage.objectAdmin"
  members = [for email in var.downloader_emails : "user:${email}"]
}
