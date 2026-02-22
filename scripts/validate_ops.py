#!/usr/bin/env python3
"""
Validates that the current environment is ready for Production Operations.
Checks:
1. Google Cloud CLI authentication.
2. Required APIs enabled.
3. Presence of all required OPS configuration variables in .env (or env vars).
"""

import os
import sys
import subprocess
import shutil

# --- Configuration (Must match OPS_CONFIG.md) ---
REQUIRED_APIS = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "pubsub.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudbuild.googleapis.com"
]

REQUIRED_ENV_VARS = [
    # Infrastructure
    "GOOGLE_CLOUD_PROJECT",
    "GCLOUD_SERVICE_ACCOUNT_KEY", # Or active gcloud auth

    # Vault Secrets
    "VAULT_DATABASE_URL",
    "VAULT_SHARED_SECRET",
    "RPC_URL",

    # Brain Secrets
    "VERTEX_AI_PROJECT",
    "GOOGLE_PATENTS_API_KEY",
    "SERPAPI_KEY",
    "PINECONE_API_KEY",

    # Alerts
    "ALERT_EMAIL"
]

def check_command(cmd):
    if shutil.which(cmd) is None:
        print(f"❌ Command '{cmd}' not found. Please install it.")
        return False
    return True

def check_gcloud_auth():
    print("Checking gcloud authentication...")
    try:
        # Check if active account is set
        result = subprocess.run(
            ["gcloud", "auth", "list", "--filter=status:ACTIVE", "--format=value(account)"],
            capture_output=True, text=True
        )
        account = result.stdout.strip()
        if account:
            print(f"✅ Authenticated as: {account}")
            return True
        else:
            print("❌ No active gcloud account. Run 'gcloud auth login' or activate a service account.")
            return False
    except FileNotFoundError:
        print("❌ gcloud CLI not found.")
        return False

def check_apis_enabled(project_id):
    print(f"Checking enabled APIs for project {project_id}...")
    try:
        result = subprocess.run(
            ["gcloud", "services", "list", "--enabled", f"--project={project_id}", "--format=value(config.name)"],
            capture_output=True, text=True
        )
        enabled_apis = result.stdout.splitlines()

        missing = [api for api in REQUIRED_APIS if api not in enabled_apis]

        if missing:
            print(f"❌ Missing APIs: {', '.join(missing)}")
            print("   Enable them with: gcloud services enable " + " ".join(missing))
            return False

        print("✅ All required APIs are enabled.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to list services: {e}")
        return False

def check_env_vars():
    print("Checking environment variables...")
    missing = []

    # Load .env if present
    if os.path.exists(".env"):
        with open(".env", "r") as f:
            for line in f:
                if "=" in line and not line.startswith("#"):
                    key, val = line.strip().split("=", 1)
                    os.environ[key] = val

    for var in REQUIRED_ENV_VARS:
        if var not in os.environ or not os.environ[var]:
            missing.append(var)

    if missing:
        print(f"❌ Missing Environment Variables: {', '.join(missing)}")
        print("   Please add them to your .env file or export them.")
        return False

    print("✅ All required environment variables are set.")
    return True

def main():
    print("🚀 Starting Operations Readiness Check...")

    if not check_command("gcloud"):
        sys.exit(1)

    if not check_command("terraform"):
        print("⚠️  Terraform not found. You will need it for deployment.")

    if not check_env_vars():
        sys.exit(1)

    # If env vars ok, get project id
    project_id = os.environ.get("GOOGLE_CLOUD_PROJECT")

    if not check_gcloud_auth():
        # Try to auth with key if provided
        key_path = os.environ.get("GCLOUD_SERVICE_ACCOUNT_KEY")
        if key_path and os.path.exists(key_path):
            print(f"ℹ️  Attempting to auth with key: {key_path}")
            subprocess.run(["gcloud", "auth", "activate-service-account", "--key-file", key_path], check=True)
        else:
            sys.exit(1)

    if not check_apis_enabled(project_id):
        print("⚠️  APIs checks failed. Terraform might handle enabling them, but verify permissions.")

    print("\n✅ System is READY for Deployment Handoff.")
    print("   Run: cd infra/terraform && terraform init && terraform apply")

if __name__ == "__main__":
    main()
