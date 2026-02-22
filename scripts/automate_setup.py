#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess
import shutil

# --- Configuration ---
ENV_EXAMPLE_PATH = ".env.example"
ENV_PATH = ".env"
REQUIRED_ENV_VARS = [
    "GOOGLE_CLOUD_PROJECT",
    "FIREBASE_PROJECT_ID",
    "GCLOUD_SERVICE_ACCOUNT_KEY",
    "RPC_URL",
    "CHAIN_ID",
    "DEPLOYER_PRIVATE_KEY",
    "USDC_CONTRACT_ADDRESS",
    "VAULT_PORT",
    "VAULT_DATABASE_URL",
    "VAULT_REDIS_URL",
    "VAULT_SHARED_SECRET",
    "BRAIN_PORT",
    "VERTEX_AI_PROJECT",
    "VERTEX_AI_LOCATION",
    "GOOGLE_PATENTS_API_KEY",
    "SERPAPI_KEY",
    "PINECONE_API_KEY",
    "PINECONE_INDEX",
    "PUBSUB_TOPIC_INVENTION_CREATED",
    "PUBSUB_TOPIC_INVESTMENT_PENDING",
    "PUBSUB_TOPIC_INVESTMENT_CONFIRMED",
    "PUBSUB_TOPIC_AI_PROCESSING",
    "PUBSUB_TOPIC_PATENT_STATUS",
    "WALLETCONNECT_PROJECT_ID",
    "PINATA_API_KEY",
    "PINATA_SECRET_KEY"
]

def main():
    parser = argparse.ArgumentParser(description="Automate Setup & Integration Test for IdeaCapital")
    parser.add_argument("--key-file", help="Path to Google Service Account JSON key file", required=False)
    # Add other arguments as needed for automation
    args = parser.parse_args()

    print("🚀 Starting Automated Setup...")

    # 1. Check for Service Account Key
    key_path = args.key_file
    if not key_path:
        key_path = input("Enter path to Google Service Account JSON key (or press Enter if configured in ENV): ").strip()

    if key_path and not os.path.exists(key_path):
        print(f"❌ Key file not found at: {key_path}")
        sys.exit(1)

    if key_path:
        print(f"✅ Key file verified at: {key_path}")
        # Ideally, we would set this in the environment or .env file

    # 2. Generate .env file
    if not os.path.exists(ENV_PATH):
        print(f"ℹ️  Generating {ENV_PATH} from {ENV_EXAMPLE_PATH}...")
        try:
            shutil.copyfile(ENV_EXAMPLE_PATH, ENV_PATH)
        except FileNotFoundError:
             print(f"❌ {ENV_EXAMPLE_PATH} not found!")
             sys.exit(1)

        print(f"⚠️  Please manually edit {ENV_PATH} with your actual secrets if not providing them via env vars.")
        # In a real automation scenario, we would parse and replace values here.
        # For this script, we'll prompt or assume existing env vars override.
    else:
        print(f"✅ {ENV_PATH} already exists. Skipping generation.")

    # 3. Update .env with Key Path if provided
    if key_path:
        update_env_file(ENV_PATH, "GCLOUD_SERVICE_ACCOUNT_KEY", key_path)

    # 4. Check for critical tools
    check_command("docker")
    check_command("npm")
    check_command("cargo")
    check_command("python3")
    check_command("flutter")

    # 5. Run Integration Tests
    print("\n🧪 Launching Integration Tests...")
    try:
        subprocess.check_call(["bash", "scripts/run_integration_test.sh"])
    except subprocess.CalledProcessError as e:
        print(f"❌ Integration tests failed with exit code {e.returncode}")
        sys.exit(e.returncode)

    print("\n✅ Automation Complete! System is ready.")

def check_command(cmd):
    if shutil.which(cmd) is None:
        print(f"❌ Command '{cmd}' not found in PATH. Please install it.")
        sys.exit(1)
    print(f"✅ Found {cmd}")

def update_env_file(filepath, key, value):
    """Updates a specific key in the .env file."""
    with open(filepath, "r") as f:
        lines = f.readlines()

    with open(filepath, "w") as f:
        updated = False
        for line in lines:
            if line.startswith(f"{key}="):
                f.write(f"{key}={value}\n")
                updated = True
            else:
                f.write(line)
        if not updated:
            f.write(f"{key}={value}\n")
    print(f"✅ Updated {key} in {filepath}")

if __name__ == "__main__":
    main()
