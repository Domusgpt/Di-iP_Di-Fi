-- IdeaCapital Vault: Initial Database Schema
-- PostgreSQL - The "Cold Storage" financial ledger

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Investment status enum
CREATE TYPE investment_status AS ENUM ('pending', 'confirmed', 'failed');

-- Investments table: records all investment transactions
CREATE TABLE investments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invention_id TEXT NOT NULL,
    wallet_address TEXT NOT NULL,
    amount_usdc NUMERIC(18, 6) NOT NULL,
    tx_hash TEXT NOT NULL UNIQUE,
    status investment_status NOT NULL DEFAULT 'pending',
    block_number BIGINT,
    token_amount NUMERIC(18, 6),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ
);

CREATE INDEX idx_investments_invention ON investments(invention_id);
CREATE INDEX idx_investments_wallet ON investments(wallet_address);
CREATE INDEX idx_investments_status ON investments(status);

-- Dividend distributions: records each distribution event
CREATE TABLE dividend_distributions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invention_id TEXT NOT NULL,
    total_revenue_usdc NUMERIC(18, 6) NOT NULL,
    merkle_root TEXT NOT NULL,
    claim_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_distributions_invention ON dividend_distributions(invention_id);

-- Individual dividend claims
CREATE TABLE dividend_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    distribution_id UUID NOT NULL REFERENCES dividend_distributions(id),
    wallet_address TEXT NOT NULL,
    amount_usdc NUMERIC(18, 6) NOT NULL,
    merkle_proof TEXT[] NOT NULL,
    claimed BOOLEAN NOT NULL DEFAULT FALSE,
    claim_tx_hash TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_claims_wallet ON dividend_claims(wallet_address);
CREATE INDEX idx_claims_distribution ON dividend_claims(distribution_id);
CREATE INDEX idx_claims_unclaimed ON dividend_claims(claimed) WHERE claimed = FALSE;

-- Inventions ledger: financial summary per invention (synced from Firestore)
CREATE TABLE invention_ledger (
    invention_id TEXT PRIMARY KEY,
    total_raised_usdc NUMERIC(18, 6) NOT NULL DEFAULT 0,
    total_distributed_usdc NUMERIC(18, 6) NOT NULL DEFAULT 0,
    backer_count INT NOT NULL DEFAULT 0,
    nft_token_id TEXT,
    royalty_token_address TEXT,
    crowdsale_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
