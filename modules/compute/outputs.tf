output "mig_name"            { value = google_compute_region_instance_group_manager.mig.name }
output "mig_instance_group"  { value = google_compute_region_instance_group_manager.mig.instance_group }

output "bastion_ip" {
  description = "Public IP of the bastion host"
  value       = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
}

output "snapshot_policy_name" {
  description = "Name of the snapshot policy for MIG instances"
  value       = google_compute_resource_policy.snapshot_policy.name
}