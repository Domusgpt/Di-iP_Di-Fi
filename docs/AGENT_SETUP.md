# Jules Agent Setup Guide

This guide explains how to configure the Jules AI Agent to work with your specific Google Cloud environment.

## 1. Prerequisites

You must have:
*   A Google Cloud Service Account JSON key file (`service-account.json`).
*   A populated `.env` file with your project secrets (see `.env.example`).
*   Python 3 installed.

## 2. Generate Agent Secrets

Jules (the agent) cannot read your local file system directly unless you provide the secrets as environment variables. Specifically, the Service Account JSON key needs to be passed as a single-line string.

We have created a helper script to generate the exact configuration block you need.

**Run the following command:**

```bash
python3 scripts/generate_agent_env.py --key-file ./service-account.json
```

## 3. Configure the Agent

The script will output a block of text that looks like this:

```bash
GCP_SA_KEY_JSON='{"type":"service_account","project_id":"..."}'
GOOGLE_CLOUD_PROJECT=ideacapital-dev
...
```

**Copy this entire block** and paste it into the "Environment Variables" or "Secrets" section of your Agent platform (e.g., GitHub Actions Secrets, Vercel Env Vars, or the specific AI Agent interface you are using).

## 4. How Jules Uses These Secrets

When Jules runs, it will look for `GCP_SA_KEY_JSON`. If found, it will:
1.  Parse the JSON string.
2.  Authenticate the `gcloud` CLI using this key.
3.  Proceed with deployment tasks (Terraform, Cloud Run, etc.) as if it were running on your local machine.

This allows Jules to manage your infrastructure securely without needing physical access to your key file.
