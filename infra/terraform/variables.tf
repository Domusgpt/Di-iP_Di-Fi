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
