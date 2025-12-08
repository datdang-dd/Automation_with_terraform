output "vpc_name"          { value = module.network.vpc_name }
output "subnet_name"       { value = module.network.subnet_name }
output "subnet_self_link"  { value = module.network.subnet_self_link }

output "mig_name"          { value = module.compute.mig_name }
output "lb_http_ip"        { value = module.lb.lb_http_ip }
output "lb_https_ip"       { value = module.lb.lb_https_ip }

output "bucket_name"       { value = module.storage.bucket_name }
output "service_account"   { value = module.security.sa_email }

# root outputs.tf
output "bastion_ip" {
  description = "Public IP of the bastion host"
  value       = module.compute.bastion_ip
}

output "admin_email" {
  description = "Admin email with snapshot access permissions"
  value       = module.security.admin_email
}

# Grafana Access
output "grafana_url" {
  description = "Grafana access URL"
  value       = "http://${module.compute.bastion_ip}:3000"
}

# Storage Outputs
output "bucket_url" {
  description = "GCS bucket URL"
  value       = "gs://${module.storage.bucket_name}"
}