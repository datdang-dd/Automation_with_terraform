output "vpc_name"         { value = google_compute_network.vpc.name }
output "subnet_name"      { value = google_compute_subnetwork.subnet.name }
output "subnet_self_link" { value = google_compute_subnetwork.subnet.self_link }
