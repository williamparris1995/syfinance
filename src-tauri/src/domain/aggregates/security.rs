use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SecurityType {
    Stock,
    Fund,
    Etf,
    Bond,
    Gold,
    Option,
    Other,
}

impl std::fmt::Display for SecurityType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Stock => write!(f, "stock"),
            Self::Fund => write!(f, "fund"),
            Self::Etf => write!(f, "etf"),
            Self::Bond => write!(f, "bond"),
            Self::Gold => write!(f, "gold"),
            Self::Option => write!(f, "option"),
            Self::Other => write!(f, "other"),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Security {
    pub id: Uuid,
    pub symbol: String,
    pub name: String,
    pub security_type: SecurityType,
    pub exchange: Option<String>,
    pub currency_code: String,
    pub current_price: Option<rust_decimal::Decimal>,
}

impl Security {
    pub fn new(
        id: Uuid,
        symbol: String,
        name: String,
        security_type: SecurityType,
        exchange: Option<String>,
        currency_code: String,
        current_price: Option<rust_decimal::Decimal>,
    ) -> Self {
        Self {
            id,
            symbol,
            name,
            security_type,
            exchange,
            currency_code,
            current_price,
        }
    }
}
