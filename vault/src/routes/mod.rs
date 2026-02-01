//! API Routes for the Vault service.

pub mod investments;
pub mod dividends;

use axum::Router;
use sqlx::PgPool;

pub fn vault_router(pool: PgPool) -> Router {
    Router::new()
        .nest("/investments", investments::router(pool.clone()))
        .nest("/dividends", dividends::router(pool))
}
