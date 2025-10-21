output "sa_email" { value = google_service_account.sa.email }

output "admin_email" { 
  description = "Admin email with snapshot access"
  value       = var.admin_email 
}