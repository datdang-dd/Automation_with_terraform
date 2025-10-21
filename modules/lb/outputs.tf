output "lb_http_ip"  { value = google_compute_global_forwarding_rule.fr_http.ip_address }
output "lb_https_ip" { value = try(google_compute_global_forwarding_rule.fr_https[0].ip_address, null) }

# Simple Web Security Outputs
output "security_policy_name" {
  description = "Cloud Armor security policy name"
  value       = google_compute_security_policy.web_security_policy.name
}