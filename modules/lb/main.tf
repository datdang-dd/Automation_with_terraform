resource "google_compute_health_check" "hc" {
  name               = "web-hc"
  check_interval_sec = 10
  timeout_sec        = 5
  http_health_check { port = 80 }
}

resource "google_compute_backend_service" "be" {
  name                  = "web-be"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  port_name             = "http"
  health_checks         = [google_compute_health_check.hc.id]
  backend { group = var.mig_group }
  
  # Enable connection draining
  connection_draining_timeout_sec = 30
  
  # Enable session affinity
  session_affinity = "CLIENT_IP"
  
  # Enable CDN for better performance
  enable_cdn = true
  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
    default_ttl = 3600
    client_ttl  = 3600
    max_ttl     = 86400
    # Minimal cache_key_policy to satisfy provider requirements
    cache_key_policy {
      include_host           = true
      include_protocol       = true
      include_query_string   = false
      # query_string_whitelist and blacklist not needed when include_query_string=false
    }
  }
}

resource "google_compute_url_map" "um" {
  name            = "web-um"
  default_service = google_compute_backend_service.be.id
}

resource "google_compute_target_http_proxy" "http" {
  name    = "web-http-proxy"
  url_map = google_compute_url_map.um.id
}

resource "google_compute_global_forwarding_rule" "fr_http" {
  name       = "web-http"
  target     = google_compute_target_http_proxy.http.id
  port_range = "80"
}

# HTTPS with enhanced security (managed cert)
resource "google_compute_managed_ssl_certificate" "cert" {
  count   = length(var.domain) > 0 ? 1 : 0
  name    = "web-cert"
  managed { 
    domains = [var.domain]
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "https" {
  count           = length(var.domain) > 0 ? 1 : 0
  name            = "web-https-proxy"
  url_map         = google_compute_url_map.um.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert[0].id]
}

resource "google_compute_global_forwarding_rule" "fr_https" {
  count      = length(var.domain) > 0 ? 1 : 0
  name       = "web-https"
  target     = google_compute_target_https_proxy.https[0].id
  port_range = "443"
}

# Simple web security monitoring (optional)
# You can enable this later if needed
