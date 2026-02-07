#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting Integration Test Environment${NC}"

# Check dependencies
if ! command -v docker >/dev/null; then
    echo -e "${RED}Docker is required but not installed.${NC}"
    exit 1
fi

# Spin up infrastructure
echo "Starting Docker containers..."
docker compose up -d postgres pubsub

# Wait for Postgres
echo "Waiting for PostgreSQL..."
until docker exec ideacapital-postgres pg_isready -U user >/dev/null 2>&1; do
    sleep 1
done

# Wait for Pub/Sub (simple sleep as it doesn't have a health check easily accessible)
sleep 5

# Ensure Pub/Sub topic/subscription exists
# We use the python script or just rely on the emulator auto-create if configured
# For now, let's assume the emulator is loose or we rely on the app creating them?
# Actually, the Vault doesn't create topics, it subscribes.
# We might need to create them.

echo "Creating Pub/Sub topics/subscriptions..."
# Curl the emulator to create topic
curl -X PUT http://localhost:8085/v1/projects/ideacapital-dev/topics/investment.pending >/dev/null 2>&1 || true
curl -X PUT http://localhost:8085/v1/projects/ideacapital-dev/topics/investment.confirmed >/dev/null 2>&1 || true
# Create subscription
curl -X PUT http://localhost:8085/v1/projects/ideacapital-dev/subscriptions/investment-pending-vault-sub \
    -H "Content-Type: application/json" \
    -d '{"topic":"projects/ideacapital-dev/topics/investment.pending"}' >/dev/null 2>&1 || true

# Run migration (Vault does this on startup, but we need DB ready for the script)
# We can just run the vault for a second or rely on the python script waiting?
# The python script polls DB, so table must exist.
# Let's run the vault migration manually or start the vault container?
# Starting the vault container is best test.

echo "Building and starting Vault..."
docker compose up -d --build vault

# Give Vault time to migrate and start
sleep 10

# Run Integration Test Script
echo -e "${GREEN}🧪 Running Integration Test Script...${NC}"

# We need to install python deps inside the environment or assume they exist
# Assuming the user runs this from a venv where they installed requests/asyncpg
if python3 scripts/test_integration_vault.py; then
    echo -e "${GREEN}✅ Integration Test Passed!${NC}"
else
    echo -e "${RED}❌ Integration Test Failed!${NC}"
    # Dump logs
    docker compose logs vault
    exit 1
fi

# Cleanup
# echo "Cleaning up..."
# docker compose down
