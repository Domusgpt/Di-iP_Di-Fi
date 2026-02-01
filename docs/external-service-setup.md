# External Service Setup Instructions

Quick-start links and step-by-step instructions for the API keys and services IdeaCapital requires.

---

## 1. Google Cloud Platform (GCP) — Service Account

You need a GCP service account JSON key for: Vertex AI (Gemini), Cloud Pub/Sub, Cloud Speech, Firestore (admin SDK).

### Steps

1. **Open the GCP Console Service Accounts page:**
   https://console.cloud.google.com/iam-admin/serviceaccounts

2. **Create a new project** (if you haven't already):
   - Click the project dropdown at the top → "New Project"
   - Name it `ideacapital-dev`
   - Click "Create"

3. **Create a service account:**
   - Click "+ CREATE SERVICE ACCOUNT"
   - Name: `ideacapital-backend`
   - Description: "Backend service account for IdeaCapital"
   - Click "Create and Continue"

4. **Grant roles** (add all of these):
   - `Vertex AI User`
   - `Pub/Sub Editor`
   - `Cloud Datastore User` (for Firestore)
   - `Storage Object Viewer` (for Cloud Storage)
   - Click "Continue" → "Done"

5. **Create a key:**
   - Click on the service account you just created
   - Go to the "Keys" tab
   - Click "Add Key" → "Create new key"
   - Select **JSON** → "Create"
   - A `.json` file will download automatically

6. **Place the key in the project:**
   ```bash
   mv ~/Downloads/ideacapital-dev-*.json ./service-account.json
   ```

7. **Update `.env`:**
   ```
   GCLOUD_SERVICE_ACCOUNT_KEY=./service-account.json
   GOOGLE_CLOUD_PROJECT=ideacapital-dev
   VERTEX_AI_PROJECT=ideacapital-dev
   ```

8. **Enable required APIs** (run in your terminal with gcloud, OR enable via Console):
   ```bash
   gcloud services enable aiplatform.googleapis.com
   gcloud services enable pubsub.googleapis.com
   gcloud services enable firestore.googleapis.com
   gcloud services enable speech.googleapis.com
   ```
   Or visit: https://console.cloud.google.com/apis/library

---

## 2. WalletConnect — Project ID

You need a WalletConnect Project ID for the Flutter frontend wallet connection (MetaMask, Rainbow, etc.).

### Steps

1. **Open the WalletConnect Cloud dashboard:**
   https://cloud.walletconnect.com/

2. **Sign up / Log in** (GitHub or email)

3. **Create a new project:**
   - Click "New Project"
   - Name: `IdeaCapital`
   - Type: "App"
   - Click "Create"

4. **Copy your Project ID:**
   - You'll see your **Project ID** on the project dashboard
   - It looks like: `a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6`

5. **Update `.env`:**
   ```
   WALLETCONNECT_PROJECT_ID=your-project-id-here
   ```

6. **Configure allowed origins** (for web):
   - In your WalletConnect project settings
   - Add `http://localhost:3000` and `http://localhost:5000` to allowed origins
   - Add your production domain when ready

---

## 3. SerpAPI — API Key

SerpAPI powers patent search (Google Patents engine). Free tier: 100 searches/month.

### Steps

1. **Open SerpAPI:**
   https://serpapi.com/

2. **Sign up** (free tier available — 100 searches/month)

3. **Get your API key:**
   - After signing up, go to: https://serpapi.com/manage-api-key
   - Copy the API key shown on that page

4. **Update `.env`:**
   ```
   SERPAPI_KEY=your-serpapi-api-key-here
   ```

5. **Test it works:**
   ```bash
   curl "https://serpapi.com/search?engine=google_patents&q=solar+panel&api_key=YOUR_KEY"
   ```

---

## 4. Contract Deployment (when ready)

Deploy smart contracts to a local Hardhat node or testnet.

### Local Deployment (Hardhat Node)

```bash
# Terminal 1: Start local blockchain
cd contracts && npx hardhat node

# Terminal 2: Deploy contracts
cd contracts && npx hardhat run scripts/deploy.ts --network hardhat
```

The deploy script will output contract addresses. Update `.env`:
```
USDC_CONTRACT_ADDRESS=0x...
CROWDSALE_ADDRESS=0x...
ROYALTY_TOKEN_ADDRESS=0x...
DIVIDEND_VAULT_ADDRESS=0x...
IPNFT_ADDRESS=0x...
```

### Testnet Deployment (Polygon Amoy)

1. Get test MATIC from https://faucet.polygon.technology/
2. Get an Alchemy/Infura RPC URL
3. Update `.env`:
   ```
   RPC_URL=https://polygon-amoy.g.alchemy.com/v2/YOUR_KEY
   CHAIN_ID=80002
   DEPLOYER_PRIVATE_KEY=0xYOUR_TESTNET_PRIVATE_KEY
   ```
4. Deploy:
   ```bash
   cd contracts && npx hardhat run scripts/deploy.ts --network polygonAmoy
   ```

---

## Quick Reference: What Goes Where

| Variable | Where to Get It | Required? |
|----------|----------------|-----------|
| `GCLOUD_SERVICE_ACCOUNT_KEY` | [GCP Console](https://console.cloud.google.com/iam-admin/serviceaccounts) | Yes — for AI + Pub/Sub |
| `GOOGLE_CLOUD_PROJECT` | Your GCP project ID | Yes |
| `WALLETCONNECT_PROJECT_ID` | [WalletConnect Cloud](https://cloud.walletconnect.com/) | Yes — for wallet |
| `SERPAPI_KEY` | [SerpAPI Dashboard](https://serpapi.com/manage-api-key) | Optional — patent search |
| `DEPLOYER_PRIVATE_KEY` | Your wallet / Hardhat default | Yes — for contracts |
| `RPC_URL` | Alchemy / Infura / localhost | Yes — for blockchain |
| `PINECONE_API_KEY` | [Pinecone Console](https://app.pinecone.io/) | Optional — vector DB |
| `PINATA_API_KEY` | [Pinata Cloud](https://app.pinata.cloud/) | Optional — IPFS |
