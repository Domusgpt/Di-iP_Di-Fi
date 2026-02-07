-- Arizona ABS Compliance Module
-- Adds support for Fee Sharing and Compliance Lawyer tracking

ALTER TABLE invention_ledger
ADD COLUMN fee_sharing_enabled BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN compliance_lawyer_id TEXT, -- References a user_id or lawyer_id
ADD COLUMN legal_entity_type TEXT DEFAULT 'DAO_LLC';

-- Add a table to track fee splits for legal compliance
CREATE TABLE compliance_fee_splits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invention_id TEXT NOT NULL REFERENCES invention_ledger(invention_id),
    recipient_type TEXT NOT NULL CHECK (recipient_type IN ('LAWYER', 'PLATFORM', 'INVENTOR', 'DAO_TREASURY')),
    recipient_address TEXT NOT NULL,
    percentage NUMERIC(5, 2) NOT NULL, -- Percentage of revenue (0-100)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_compliance_invention ON compliance_fee_splits(invention_id);
