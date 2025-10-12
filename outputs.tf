# ======================== outputs.tf ========================
output "bucket_name" {
  value       = google_storage_bucket.bucket.name
  description = "Created GCS bucket name"
}

output "vm_external_ip" {
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
  description = "VM external IP"
}

output "vpc_self_link" {
  value       = google_compute_network.vpc.self_link
  description = "VPC self link"
}

output "subnet_self_link" {
  value       = google_compute_subnetwork.subnet.self_link
  description = "Subnet self link"
}
