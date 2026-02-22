# Monitoring & Alerting

# 1. Notification Channel (Email)
resource "google_monitoring_notification_channel" "email" {
  display_name = "DevOps Team Email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

# 2. Vault Uptime Check
resource "google_monitoring_uptime_check_config" "vault_uptime" {
  display_name = "Vault Service Uptime"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path = "/health"
    port = 443
    use_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = replace(google_cloud_run_service.vault.status[0].url, "https://", "")
    }
  }

  content_matchers {
    content = "OK" # Assuming /health returns "OK" or similar
    matcher = "CONTAINS_STRING"
  }

  depends_on = [google_cloud_run_service.vault]
}

# 3. Brain Uptime Check
resource "google_monitoring_uptime_check_config" "brain_uptime" {
  display_name = "Brain Service Uptime"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path = "/health"
    port = 443
    use_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = replace(google_cloud_run_service.brain.status[0].url, "https://", "")
    }
  }

  depends_on = [google_cloud_run_service.brain]
}

# 4. Alert Policy: Uptime Check Failure
resource "google_monitoring_alert_policy" "uptime_failure" {
  display_name = "Uptime Check Failure"
  combiner     = "OR"
  conditions {
    display_name = "Uptime Check Failed"
    condition_threshold {
      filter     = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\""
      duration   = "60s"
      comparison = "COMPARISON_GT"
      threshold_value = 1
      aggregations {
        alignment_period   = "1200s"
        per_series_aligner = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields = ["resource.label.host"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}
