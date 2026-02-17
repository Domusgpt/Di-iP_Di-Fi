provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. Artifact Registry (Docker Images)
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "ideacapital-repo"
  description   = "Docker repository for IdeaCapital services"
  format        = "DOCKER"
}

# 2. Cloud SQL (PostgreSQL 16)
resource "google_sql_database_instance" "vault_db" {
  name             = "ideacapital-vault-db"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "database" {
  name     = "ideacapital"
  instance = google_sql_database_instance.vault_db.name
}

resource "google_sql_user" "users" {
  name     = var.db_user
  instance = google_sql_database_instance.vault_db.name
  password = var.db_password
}

# 3. Pub/Sub Topics
resource "google_pubsub_topic" "investment_pending" {
  name = "investment.pending"
}

resource "google_pubsub_topic" "investment_confirmed" {
  name = "investment.confirmed"
}

resource "google_pubsub_topic" "ai_processing" {
  name = "ai.processing"
}

# 4. Cloud Run (Vault)
resource "google_cloud_run_service" "vault" {
  name     = "ideacapital-vault"
  location = var.region

  template {
    spec {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/ideacapital-repo/vault:latest"
        env {
          name  = "VAULT_DATABASE_URL"
          value = "postgres://${var.db_user}:${var.db_password}@${google_sql_database_instance.vault_db.public_ip_address}/ideacapital"
        }
        env {
          name = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# 5. Pub/Sub Subscription for Vault
resource "google_pubsub_subscription" "vault_sub" {
  name  = "investment-pending-vault-sub"
  topic = google_pubsub_topic.investment_pending.name

  # Push to Cloud Run (simplest for serverless) or Pull (if Vault is always on)
  # Vault is designed as a long-running service (Pull), so we use Pull.
}
