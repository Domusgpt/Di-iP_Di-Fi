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
  depends_on    = [google_project_service.apis]
}

# 2. Cloud SQL (PostgreSQL 16)
resource "google_sql_database_instance" "vault_db" {
  name             = "ideacapital-vault-db-prod"
  database_version = "POSTGRES_16"
  region           = var.region
  deletion_protection = false # For dev ease

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = true
    }
  }
  depends_on = [google_project_service.apis]
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
  depends_on = [google_project_service.apis]
}

resource "google_pubsub_topic" "investment_confirmed" {
  name = "investment.confirmed"
  depends_on = [google_project_service.apis]
}

resource "google_pubsub_topic" "ai_processing" {
  name = "ai.processing"
  depends_on = [google_project_service.apis]
}

# 4. Cloud Run (Vault)
resource "google_cloud_run_service" "vault" {
  name     = "ideacapital-vault"
  location = var.region
  depends_on = [google_project_service.apis, google_sql_database_instance.vault_db]

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/ideacapital-repo/vault:latest"

        # --- Environment Variables ---
        env {
          name  = "VAULT_DATABASE_URL"
          # CORRECTED: Using Cloud SQL Auth Proxy Socket Connection
          # Format: postgres://user:pass@/dbname?host=/cloudsql/connection_name
          value = "postgres://${var.db_user}:${var.db_password}@/ideacapital?host=/cloudsql/${google_sql_database_instance.vault_db.connection_name}"
        }
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
        env {
          name = "VAULT_SHARED_SECRET"
          value = var.vault_shared_secret
        }
        env {
          name = "RPC_URL"
          value = var.rpc_url
        }
      }
    }

    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.vault_db.connection_name
        "run.googleapis.com/client-name"        = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# 5. Cloud Run (Brain)
resource "google_cloud_run_service" "brain" {
  name     = "ideacapital-brain"
  location = var.region
  depends_on = [google_project_service.apis]

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/ideacapital-repo/brain:latest"

        env {
          name = "VERTEX_AI_PROJECT"
          value = var.vertex_ai_project
        }
        env {
          name = "GOOGLE_PATENTS_API_KEY"
          value = var.google_patents_api_key
        }
        env {
          name = "SERPAPI_KEY"
          value = var.serpapi_key
        }
        env {
          name = "PINECONE_API_KEY"
          value = var.pinecone_api_key
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# 6. Pub/Sub Subscription for Vault
resource "google_pubsub_subscription" "vault_sub" {
  name  = "investment-pending-vault-sub"
  topic = google_pubsub_topic.investment_pending.name

  push_config {
    push_endpoint = "${google_cloud_run_service.vault.status[0].url}/pubsub/investment-pending"
    oidc_token {
      service_account_email = google_service_account.cloud_run_sa.email
    }
  }
}
