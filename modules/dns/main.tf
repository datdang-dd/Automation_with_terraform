# Use existing managed zone if provided
locals {
  use_existing_zone = length(var.zone_name) > 0
  # Ensure domain/dns_name have trailing dot for DNS recordset (google provider requires FQDN)
  fqdn = var.domain == "" ? "" : (endswith(var.domain, ".") ? var.domain : "${var.domain}.")
  dns_name_normalized = var.dns_name == "" ? "" : (endswith(var.dns_name, ".") ? var.dns_name : "${var.dns_name}.")
}

data "google_dns_managed_zone" "existing" {
  count = local.use_existing_zone ? 1 : 0
  name  = var.zone_name
  project = var.project_id
}

resource "google_dns_managed_zone" "created" {
  count = local.use_existing_zone ? 0 : 1
  name  = var.managed_zone_name
  dns_name = local.dns_name_normalized
  project  = var.project_id
  description = "Managed zone created by Terraform example module"
}

# Resolve the managed zone name and DNS name
locals {
  managed_zone_name = local.use_existing_zone ? data.google_dns_managed_zone.existing[0].name : google_dns_managed_zone.created[0].name
  dns_name          = local.use_existing_zone ? data.google_dns_managed_zone.existing[0].dns_name : google_dns_managed_zone.created[0].dns_name
}

# Create the A record only when a domain is provided
resource "google_dns_record_set" "a_record" {
  count = local.fqdn == "" ? 0 : 1
  name = local.fqdn
  type = "A"
  ttl  = var.ttl
  managed_zone = local.managed_zone_name
  project = var.project_id

  rrdatas = [var.lb_ip]
}
