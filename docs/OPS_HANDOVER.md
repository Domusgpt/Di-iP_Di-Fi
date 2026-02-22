# IdeaCapital Operations Handover

This document details the exact configuration needed for production deployment and monitoring.

## 1. Configuration Audit (`docs/OPS_CONFIG.md`)

I have created `docs/OPS_CONFIG.md` which exhaustively lists:
*   **Required APIs:** 8 Google Cloud APIs to enable.
*   **Terraform Variables:** 6 inputs required for the infrastructure.
*   **Runtime Variables:** 13 environment variables for the Vault and Brain services.
*   **IAM Roles:** The exact permissions your Agent Service Account needs.

## 2. Infrastructure as Code (Terraform)

I have enhanced the Terraform configuration in `infra/terraform/` to be production-ready.

### New Files:
*   **`apis.tf`**: Automatically enables all required Google Cloud APIs.
*   **`monitoring.tf`**: Sets up Uptime Checks and Notification Channels for alerting.
*   **`iam.tf`**: Grants necessary permissions to the Cloud Run service account (SQL Client, Pub/Sub Publisher).

### Updates:
*   **`main.tf`**:
    *   Added the `ideacapital-brain` Cloud Run service.
    *   Injected all required environment variables (mapped from secrets/vars).
    *   **Fixed Cloud SQL Connection:** Now uses the correct Unix Socket connection via `run.googleapis.com/cloudsql-instances`.
    *   Added `google_project_service` dependencies to ensure APIs are ready before resources.
*   **`variables.tf`**: Added variables for sensitive keys (`rpc_url`, `openai_key`, etc.) to be passed securely.

## 3. Automation Scripts

I updated `scripts/automate_setup.py` (or created `scripts/validate_ops.py`) to:
*   Validate that you have the `gcloud` CLI installed.
*   Check if the required APIs are enabled.
*   Verify that your local `.env` contains all the production variables listed in `OPS_CONFIG.md`.

## 4. Deployment Instructions (CRITICAL)

Because Cloud Run requires Docker images to exist before deployment, you must follow this specific order to avoid "Chicken and Egg" errors.

1.  **Install Terraform:** Ensure `terraform` is in your PATH.
2.  **Set Secrets:** Create a `terraform.tfvars` file (do NOT commit it) with your real keys.
3.  **Step A: Create Repository:**
    Apply *only* the Artifact Registry first so you have a place to push images.
    ```bash
    cd infra/terraform
    terraform init
    terraform apply -target=google_artifact_registry_repository.repo
    ```
4.  **Step B: Build & Push Images:**
    Build the Docker images locally and push them to the new registry.
    ```bash
    # Set your project ID
    export PROJECT_ID=ideacapital-dev
    export REGION=us-central1

    # Authenticate Docker
    gcloud auth configure-docker $REGION-docker.pkg.dev

    # Build & Push Vault
    docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/ideacapital-repo/vault:latest ./vault
    docker push $REGION-docker.pkg.dev/$PROJECT_ID/ideacapital-repo/vault:latest

    # Build & Push Brain
    docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/ideacapital-repo/brain:latest ./brain
    docker push $REGION-docker.pkg.dev/$PROJECT_ID/ideacapital-repo/brain:latest
    ```
5.  **Step C: Deploy Full Infrastructure:**
    Now that images exist, deploy everything else (Cloud Run, SQL, Monitoring).
    ```bash
    terraform apply
    ```
6.  **Step D: Future Deployments:**
    For future updates, simply push to `main` and let CI/CD handle it, or repeat Step B and `terraform apply`.
