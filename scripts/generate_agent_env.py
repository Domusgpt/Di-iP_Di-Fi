#!/usr/bin/env python3
"""
Generates the Environment Variables list for the Jules Agent.
Usage: python3 scripts/generate_agent_env.py --key-file ./service-account.json

This script reads your local secrets and formats them for the Agent's settings.
It compacts the JSON key into a single line string.
"""

import argparse
import json
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="Generate Jules Agent Environment Variables")
    parser.add_argument("--key-file", help="Path to Google Service Account JSON key", required=True)
    parser.add_argument("--env-file", help="Path to .env file", default=".env")
    args = parser.parse_args()

    output = []

    # 1. Process Service Account Key
    try:
        with open(args.key_file, 'r') as f:
            key_data = json.load(f)
            # Compact JSON to a single line string
            compact_json = json.dumps(key_data, separators=(',', ':'))
            output.append(f"GCP_SA_KEY_JSON='{compact_json}'")
    except FileNotFoundError:
        print(f"❌ Error: Key file '{args.key_file}' not found.")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"❌ Error: '{args.key_file}' is not valid JSON.")
        sys.exit(1)

    # 2. Process .env file
    if os.path.exists(args.env_file):
        with open(args.env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                # Skip the local key path variable, we replaced it with the content
                if line.startswith("GCLOUD_SERVICE_ACCOUNT_KEY="):
                    continue
                output.append(line)
    else:
        print(f"⚠️  Warning: {args.env_file} not found. Only generating SA Key.")

    # 3. Print Result
    print("\n" + "="*60)
    print("📋 COPY THE BLOCK BELOW INTO JULES ENVIRONMENT VARIABLES")
    print("="*60 + "\n")

    for item in output:
        print(item)

    print("\n" + "="*60)
    print("✅ Done! With these variables, I can authenticate and deploy.")

if __name__ == "__main__":
    main()
