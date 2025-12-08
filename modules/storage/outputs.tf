output "bucket_name" { 
  description = "GCS bucket name"
  value       = google_storage_bucket.bucket.name 
}

output "bucket_url" {
  description = "GCS bucket URL"
  value       = "gs://${google_storage_bucket.bucket.name}"
}

output "bucket_self_link" {
  description = "GCS bucket self link"
  value       = google_storage_bucket.bucket.self_link
}
