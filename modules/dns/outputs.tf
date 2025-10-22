output "managed_zone_name" {
  value = local.managed_zone_name
}

output "record_fqdn" {
  value = length(google_dns_record_set.a_record) > 0 ? google_dns_record_set.a_record[0].name : ""
}

output "record_ttl" {
  value = length(google_dns_record_set.a_record) > 0 ? google_dns_record_set.a_record[0].ttl : 0
}
