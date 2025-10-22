output "managed_zone_name" {
  value = local.managed_zone_name
}

output "record_fqdn" {
  value = google_dns_record_set.a_record.name
}

output "record_ttl" {
  value = google_dns_record_set.a_record.ttl
}
