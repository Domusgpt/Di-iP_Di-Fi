# Service Accounts & IAM

# 1. Cloud Run Service Account (Runtime Identity)
resource "google_service_account" "cloud_run_sa" {
  account_id   = "ideacapital-cloud-run-sa"
  display_name = "IdeaCapital Cloud Run Service Account"
}

# 2. Permissions for Cloud Run SA
# Allow connecting to Cloud SQL
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Allow publishing to Pub/Sub
resource "google_project_iam_member" "pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Allow subscribing to Pub/Sub
resource "google_project_iam_member" "pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Allow accessing Secrets (if we use Secret Manager)
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
