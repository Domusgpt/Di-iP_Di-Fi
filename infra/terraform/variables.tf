variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "vault_user"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
}

variable "rpc_url" {
  description = "Blockchain RPC URL"
  type        = string
  sensitive   = true
}

variable "vault_shared_secret" {
  description = "Shared secret for service auth"
  type        = string
  sensitive   = true
}

variable "vertex_ai_project" {
  description = "GCP Project for Vertex AI"
  type        = string
}

variable "google_patents_api_key" {
  description = "API Key for Patents"
  type        = string
  sensitive   = true
}

variable "serpapi_key" {
  description = "API Key for SerpApi"
  type        = string
  sensitive   = true
}

variable "pinecone_api_key" {
  description = "API Key for Pinecone"
  type        = string
  sensitive   = true
}
