terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

locals {
  service_name = "ai-log-analyzer"
}

# ---------- Service account for Cloud Run ----------
resource "google_service_account" "ai_sa" {
  project      = var.project_id
  account_id   = "ai-log-analyzer-sa"
  display_name = "AI Log Analyzer SA"
}

# Allow Cloud Run to use Vertex AI, read logs, etc.
resource "google_project_iam_member" "ai_sa_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.ai_sa.email}"
}

resource "google_project_iam_member" "ai_sa_logs" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.ai_sa.email}"
}

resource "google_project_iam_member" "ai_sa_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.ai_sa.email}"
}

# (Optional, if Chat webhook is in Secret Manager later)
# resource "google_project_iam_member" "ai_sa_secrets" { ... }

# ---------- Pub/Sub topic for logs ----------
resource "google_pubsub_topic" "logs_topic" {
  project = var.project_id
  name    = "ai-log-errors-topic"
}

# ---------- Logging sink -> Pub/Sub ----------
resource "google_logging_project_sink" "logs_sink" {
  project                 = var.project_id
  name                    = "ai-log-errors-sink"
  destination             = "pubsub.googleapis.com/${google_pubsub_topic.logs_topic.id}"
  filter                  = var.log_filter
  unique_writer_identity  = true
}

# Grant sink writer SA permission to publish to topic
resource "google_pubsub_topic_iam_member" "logs_sink_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.logs_topic.name
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.logs_sink.writer_identity
}
# Enable Cloud Run Admin API for the project
resource "google_project_service" "run_api" {
  project = var.project_id
  service = "run.googleapis.com"

  # Thường để true để tf destroy không vô tình tắt API
  disable_on_destroy = false
}

# ---------- Cloud Run service ----------
resource "google_cloud_run_service" "ai_service" {
  name     = local.service_name
  project  = var.project_id
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.ai_sa.email

      containers {
        image = var.ai_service_image

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "LOCATION"
          value = var.region
        }

        env {
          name  = "CHAT_WEBHOOK_URL"
          value = var.chat_webhook_url
        }

        env {
          name  = "MODEL_NAME"
          value = "gemini-2.5-flash"
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Only allow authenticated invocations
resource "google_cloud_run_service_iam_member" "invoker" {
  service  = google_cloud_run_service.ai_service.name
  location = google_cloud_run_service.ai_service.location
  project  = google_cloud_run_service.ai_service.project

  role   = "roles/run.invoker"
  member = "serviceAccount:${google_service_account.ai_sa.email}"
}

# ---------- Pub/Sub push subscription -> Cloud Run ----------
resource "google_pubsub_subscription" "logs_push_sub" {
  project = var.project_id
  name    = "ai-log-errors-push-sub"
  topic   = google_pubsub_topic.logs_topic.name

  push_config {
    push_endpoint = google_cloud_run_service.ai_service.status[0].url

    oidc_token {
      service_account_email = google_service_account.ai_sa.email
      audience              = google_cloud_run_service.ai_service.status[0].url
    }
  }

  depends_on = [google_cloud_run_service.ai_service]
}
