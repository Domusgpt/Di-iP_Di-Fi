-- Immutable Audit Logs for Compliance
-- Records every major financial or state-change event for legal auditing.

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type TEXT NOT NULL, -- e.g. "DIVIDEND_DISTRIBUTION", "FEE_SPLIT_CHANGE"
    actor TEXT NOT NULL, -- e.g. "system", "admin_wallet_0x..."
    target_resource TEXT NOT NULL, -- e.g. "invention_123"
    payload JSONB NOT NULL, -- Snapshot of the data at that time (fee percentages, amounts)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_target ON audit_logs(target_resource);
