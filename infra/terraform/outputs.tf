output "vault_url" {
  value = google_cloud_run_service.vault.status[0].url
}

output "db_connection_name" {
  value = google_sql_database_instance.vault_db.connection_name
}
