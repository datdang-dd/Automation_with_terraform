# Cloud Armor Security Policy - Optimized for High Traffic
resource "google_compute_security_policy" "web_security_policy" {
  name = "web-security-policy"
  
  # Default rule - allow all traffic
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default allow rule"
  }
  
  # High traffic rate limiting - 10,000 requests per minute per IP
  rule {
    action   = "throttle"
    priority = "100"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count = 10000
        interval_sec = 60
      }
    }
    description = "High traffic rate limiting - 10,000 req/min per IP"
  }
  
  # Aggressive DDoS protection - 1000 requests per 10 seconds per IP
  rule {
    action   = "throttle"
    priority = "50"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count = 1000
        interval_sec = 10
      }
    }
    description = "DDoS protection - 1000 req/10sec per IP"
  }
  
  # Burst protection - 100 requests per second per IP
  rule {
    action   = "throttle"
    priority = "25"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        # interval_sec must be one of the allowed values (10,30,60,...).
        # To preserve ~100 requests/second, use 1000 requests per 10 seconds.
        count = 1000
        interval_sec = 10
      }
    }
    description = "Burst protection - 100 req/sec per IP"
  }
}

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
  
  # Security: Apply Cloud Armor policy
  security_policy = google_compute_security_policy.web_security_policy.id
  
  # DDoS Protection: Enable connection draining
  connection_draining_timeout_sec = 30
  
  # DDoS Protection: Enable session affinity
  session_affinity = "CLIENT_IP"
  
  # DDoS Protection: Enable CDN for better performance
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
