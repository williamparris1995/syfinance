use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSecurityDto {
    pub symbol: String,
    pub name: String,
    pub security_type: String,
    pub exchange: Option<String>,
    pub currency_code: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityDto {
    pub id: Uuid,
    pub symbol: String,
    pub name: String,
    pub security_type: String,
    pub exchange: Option<String>,
    pub currency_code: String,
    pub current_price: Option<Decimal>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoldingTradeDto {
    pub account_id: Uuid,
    pub security_id: Uuid,
    pub direction: String, // "BUY" or "SELL"
    pub quantity: Decimal,
    pub price: Decimal,
    pub fee: Decimal,
    pub trade_date: NaiveDate,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoldingDto {
    pub id: Uuid,
    pub account_id: Uuid,
    pub account_name: String,
    pub security_id: Uuid,
    pub symbol: String,
    pub security_name: String,
    pub security_type: String,
    pub quantity: Decimal,
    pub avg_cost: Decimal,
    pub current_price: Option<Decimal>,
    pub market_value: Option<Decimal>,
    pub unrealized_pnl: Option<Decimal>,
    pub currency_code: String,
}
