# ---- Build Stage ----
FROM python:3.11-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Runtime Stage ----
FROM python:3.11-slim

# Install Node.js (for snarkjs) and Curl (for installing other tools)
RUN apt-get update && apt-get install -y nodejs npm curl && \
    npm install -g snarkjs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Circom (Linux binary)
# Using a fixed version for reproducibility
RUN curl -L https://github.com/iden3/circom/releases/download/v2.1.8/circom-linux-amd64 -o /usr/local/bin/circom && \
    chmod +x /usr/local/bin/circom

WORKDIR /app
COPY --from=builder /install /usr/local
COPY src/ src/
COPY scripts/ scripts/

ENV BRAIN_PORT=8081
EXPOSE 8081

# Ensure ZKP setup is done (compile circuits if needed)
# In production, circuits should be pre-compiled in the build stage,
# but for this dev setup we might do it on start or manually.
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8081"]
