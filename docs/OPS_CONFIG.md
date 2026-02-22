# Operational Configuration & Deployment Guide

This document lists every environment variable, IAM role, and Google Cloud service required to deploy and monitor IdeaCapital in production. Use this as the "Source of Truth" for your Infrastructure-as-Code (Terraform) and CI/CD pipelines.

## 1. Required Google Cloud APIs

Enable these APIs in your project (`ideacapital-dev`):
*   `run.googleapis.com` (Cloud Run)
*   `sqladmin.googleapis.com` (Cloud SQL)
*   `pubsub.googleapis.com` (Pub/Sub)
*   `artifactregistry.googleapis.com` (Docker Images)
*   `secretmanager.googleapis.com` (Secrets Management)
*   `monitoring.googleapis.com` (Cloud Monitoring)
*   `logging.googleapis.com` (Cloud Logging)
*   `cloudbuild.googleapis.com` (CI/CD Build)

## 2. Infrastructure Variables (Terraform)

These variables must be defined in `infra/terraform/terraform.tfvars` or passed via `-var`:

| Variable | Description | Example |
| :--- | :--- | :--- |
| `project_id` | GCP Project ID | `ideacapital-dev` |
| `region` | GCP Region for resources | `us-central1` |
| `db_user` | PostgreSQL Username | `vault_user` |
| `db_password` | **Secret** PostgreSQL Password | `secure-random-string` |
| `app_image_tag` | Docker Image Tag to deploy | `v1.0.0` or `sha-abc1234` |
| `alert_email` | Email address for monitoring alerts | `ops@ideacapital.xyz` |

## 3. Application Runtime Variables

These environment variables must be injected into the Cloud Run services (`vault` and `brain`).

### A. The Vault (Rust Service)
| Variable | Source | Description |
| :--- | :--- | :--- |
| `VAULT_DATABASE_URL` | Cloud SQL | `postgres://user:pass@/ideacapital?host=/cloudsql/PROJECT:REGION:INSTANCE` |
| `VAULT_REDIS_URL` | Redis | `redis://redis-host:6379` (Optional if using in-memory cache) |
| `VAULT_SHARED_SECRET` | **Secret** | HMAC key for internal service-to-service auth |
| `RPC_URL` | **Secret** | Blockchain RPC Endpoint (Alchemy/Infura) |
| `CHAIN_ID` | Config | `80001` (Mumbai) or `8453` (Base) |
| `USDC_CONTRACT_ADDRESS` | Config | `0x...` |
| `CROWDSALE_ADDRESS` | Config | `0x...` (Address of the active Crowdsale contract) |

### B. The Brain (Python Service)
| Variable | Source | Description |
| :--- | :--- | :--- |
| `VERTEX_AI_PROJECT` | Config | GCP Project ID |
| `VERTEX_AI_LOCATION` | Config | `us-central1` |
| `GOOGLE_PATENTS_API_KEY` | **Secret** | API Key for patent search |
| `SERPAPI_KEY` | **Secret** | API Key for Google Search |
| `PINECONE_API_KEY` | **Secret** | Vector DB Key |
| `PINECONE_INDEX` | Config | `inventions` |

### C. Backend (TypeScript Functions)
*Deployed via `firebase deploy`, configured via `firebase functions:config:set`.*
| Variable | Description |
| :--- | :--- |
| `web3.rpc_url` | Blockchain RPC |
| `web3.chain_id` | Chain ID |
| `service.shared_secret` | Matches `VAULT_SHARED_SECRET` |

## 4. IAM Roles & Permissions

The **Agent Service Account** (used by CI/CD or the automation script) needs these roles:

*   `roles/editor` (Broad access for initial setup)
*   OR granularly:
    *   `roles/run.admin` (Deploy Cloud Run)
    *   `roles/cloudsql.admin` (Manage DB)
    *   `roles/pubsub.admin` (Manage Topics)
    *   `roles/iam.serviceAccountUser` (Pass SA to Cloud Run)
    *   `roles/storage.admin` (Upload Terraform state)
    *   `roles/monitoring.editor` (Create Dashboards/Alerts)

The **Cloud Run Service Account** (runtime identity) needs:
*   `roles/cloudsql.client` (Connect to DB)
*   `roles/pubsub.publisher` (Publish events)
*   `roles/pubsub.subscriber` (Consume events)
*   `roles/secretmanager.secretAccessor` (Read secrets)

## 5. Monitoring Strategy

We use Google Cloud Monitoring.

### Alerts
1.  **Uptime Check:** Pings `/health` endpoint every 1 minute. Fails if !200 OK.
2.  **High Latency:** Alert if p99 latency > 2s for 5 minutes.
3.  **Error Rate:** Alert if 5xx responses > 1% of traffic.
4.  **Log-Based:** Alert on specific error logs (e.g., "Panic", "Exception").

### Dashboards
*   **Vault Overview:** RPS, Latency, Active DB Connections.
*   **Brain Overview:** AI Processing Time, Token Usage, Error Rate.
