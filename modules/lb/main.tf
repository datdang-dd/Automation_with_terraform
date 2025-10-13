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
  health_checks         = [google_compute_health_check.hc.id]
  backend { group = var.mig_group }
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

# HTTPS optional (managed cert)
resource "google_compute_managed_ssl_certificate" "cert" {
  count   = length(var.domain) > 0 ? 1 : 0
  name    = "web-cert"
  managed { domains = [var.domain] }
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
