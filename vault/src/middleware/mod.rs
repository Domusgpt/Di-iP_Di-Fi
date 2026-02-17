//! Vault middleware — service-to-service authentication
//!
//! Validates that incoming requests originate from authorized Cloud Functions
//! by verifying a shared HMAC-SHA256 token or a Firebase/Google ID token.

use axum::{
    extract::Request,
    http::{HeaderMap, StatusCode},
    middleware::Next,
    response::Response,
};
use sha2::Sha256;
use hmac::{Hmac, Mac};

#[allow(dead_code)]
type HmacSha256 = Hmac<Sha256>;

/// Service-to-service auth middleware.
/// Checks the `X-Vault-Auth` header against a shared secret HMAC.
/// In production, this would verify a Google OIDC token instead.
#[allow(dead_code)]
pub async fn require_service_auth(
    headers: HeaderMap,
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let shared_secret = std::env::var("VAULT_SHARED_SECRET")
        .unwrap_or_default();

    // Skip auth in development if no secret configured
    if shared_secret.is_empty() {
        tracing::warn!("VAULT_SHARED_SECRET not set — auth disabled (dev mode)");
        return Ok(next.run(request).await);
    }

    let auth_header = headers
        .get("x-vault-auth")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| {
            tracing::warn!("Missing X-Vault-Auth header");
            StatusCode::UNAUTHORIZED
        })?;

    // Extract timestamp and signature from "timestamp:signature" format
    let parts: Vec<&str> = auth_header.splitn(2, ':').collect();
    if parts.len() != 2 {
        return Err(StatusCode::UNAUTHORIZED);
    }

    let timestamp = parts[0];
    let provided_sig = parts[1];

    // Verify timestamp is within 5 minutes
    let ts: i64 = timestamp.parse().map_err(|_| StatusCode::UNAUTHORIZED)?;
    let now = chrono::Utc::now().timestamp();
    if (now - ts).abs() > 300 {
        tracing::warn!("Auth token expired (timestamp drift > 5min)");
        return Err(StatusCode::UNAUTHORIZED);
    }

    // Verify HMAC
    let mut mac = HmacSha256::new_from_slice(shared_secret.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    mac.update(timestamp.as_bytes());

    let expected = hex::encode(mac.finalize().into_bytes());
    if expected != provided_sig {
        tracing::warn!("Invalid auth signature");
        return Err(StatusCode::UNAUTHORIZED);
    }

    Ok(next.run(request).await)
}

/// Health check bypass — no auth required.
#[allow(dead_code)]
pub async fn health_passthrough(
    request: Request,
    next: Next,
) -> Response {
    next.run(request).await
}
