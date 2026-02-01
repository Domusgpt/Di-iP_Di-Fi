//! Token Calculation Logic
//!
//! Calculates how many Royalty Tokens an investor receives for their USDC investment.
//! Also handles dividend distribution math.

use rust_decimal::Decimal;
use rust_decimal::prelude::*;

/// Calculate the number of royalty tokens for a given investment.
///
/// Formula: tokens = (investment / goal) * total_supply * (royalty_percentage / 100)
///
/// Example: $50 investment in a $10,000 goal with 1,000,000 token supply and 20% royalty
/// = (50 / 10000) * 1000000 * 0.20 = 1,000 tokens
pub fn calculate_token_amount(
    investment_usdc: Decimal,
    funding_goal_usdc: Decimal,
    total_token_supply: Decimal,
    royalty_percentage: Decimal,
) -> Decimal {
    if funding_goal_usdc.is_zero() {
        return Decimal::ZERO;
    }

    let share = investment_usdc / funding_goal_usdc;
    let royalty_factor = royalty_percentage / Decimal::from(100);

    (share * total_token_supply * royalty_factor).round_dp(0)
}

/// Calculate a token holder's share of a dividend distribution.
///
/// Formula: share = (holder_balance / total_supply) * revenue
pub fn calculate_dividend_share(
    holder_balance: Decimal,
    total_supply: Decimal,
    revenue_usdc: Decimal,
) -> Decimal {
    if total_supply.is_zero() {
        return Decimal::ZERO;
    }

    let ownership_fraction = holder_balance / total_supply;
    (ownership_fraction * revenue_usdc).round_dp(6)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_token_calculation() {
        let tokens = calculate_token_amount(
            Decimal::from(50),       // $50 investment
            Decimal::from(10_000),   // $10k goal
            Decimal::from(1_000_000), // 1M token supply
            Decimal::from(20),       // 20% royalty
        );
        assert_eq!(tokens, Decimal::from(1_000));
    }

    #[test]
    fn test_token_calculation_full_funding() {
        let tokens = calculate_token_amount(
            Decimal::from(10_000),   // Fund the whole thing
            Decimal::from(10_000),
            Decimal::from(1_000_000),
            Decimal::from(20),
        );
        assert_eq!(tokens, Decimal::from(200_000)); // 20% of supply
    }

    #[test]
    fn test_zero_goal() {
        let tokens = calculate_token_amount(
            Decimal::from(50),
            Decimal::ZERO,
            Decimal::from(1_000_000),
            Decimal::from(20),
        );
        assert_eq!(tokens, Decimal::ZERO);
    }

    #[test]
    fn test_dividend_share() {
        let share = calculate_dividend_share(
            Decimal::from(1_000),     // Holds 1,000 tokens
            Decimal::from(1_000_000), // Out of 1M
            Decimal::from(50_000),    // $50k revenue
        );
        assert_eq!(share, Decimal::from(50)); // $50
    }
}
