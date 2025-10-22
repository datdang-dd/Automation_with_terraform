modules/dns - simple Cloud DNS helper

This module either uses an existing Cloud DNS managed zone (by passing `zone_name`) or creates a new managed zone (by providing `dns_name` and optional `managed_zone_name`). It then creates an A record that points your `domain` to the provided `lb_ip`.

Example usage (in root or an example folder):

module "dns" {
  source = "../modules/dns"
  project_id = var.project_id
  # Use existing zone:
  # zone_name = "example-zone"
  # Or create a new zone:
  managed_zone_name = "demo-managed-zone"
  dns_name = "example.com."  # must end with a dot

  domain = "www.example.com."
  lb_ip  = module.lb.lb_http_ip
}

Notes:
- Ensure the `dns_name` ends with a trailing dot when creating a zone (e.g., "example.com.").
- When pointing the record for the zone apex (example.com), set `domain = "example.com."` and the module will create an A record for that name.
- After creating or updating DNS records, DNS propagation can take time depending on TTL.
