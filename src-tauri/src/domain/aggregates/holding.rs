use chrono::NaiveDate;
use rust_decimal::Decimal;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum HoldingTransactionType {
    Buy,
    Sell,
    Dividend,
    Split,
}

impl std::fmt::Display for HoldingTransactionType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Buy => write!(f, "BUY"),
            Self::Sell => write!(f, "SELL"),
            Self::Dividend => write!(f, "DIVIDEND"),
            Self::Split => write!(f, "SPLIT"),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Holding {
    pub id: Uuid,
    pub account_id: Uuid,
    pub security_id: Uuid,
    pub quantity: Decimal,
    pub avg_cost: Decimal,
}

#[derive(Debug, Clone)]
pub struct HoldingTransaction {
    pub id: Uuid,
    pub account_id: Uuid,
    pub security_id: Uuid,
    pub trade_type: HoldingTransactionType,
    pub quantity: Decimal,
    pub price: Decimal,
    pub amount: Decimal,
    pub fee: Decimal,
    pub trade_date: NaiveDate,
    pub transaction_id: Option<Uuid>,
    pub notes: Option<String>,
}

impl Holding {
    pub fn new(
        id: Uuid,
        account_id: Uuid,
        security_id: Uuid,
        quantity: Decimal,
        avg_cost: Decimal,
    ) -> Self {
        Self {
            id,
            account_id,
            security_id,
            quantity,
            avg_cost,
        }
    }

    /// Apply a BUY transaction to this holding
    pub fn apply_buy(&mut self, trade: &HoldingTransaction) {
        let total_cost = self.avg_cost * self.quantity + trade.amount + trade.fee;
        self.quantity += trade.quantity;
        self.avg_cost = if self.quantity > Decimal::ZERO {
            total_cost / self.quantity
        } else {
            Decimal::ZERO
        };
    }

    /// Apply a SELL transaction, returns realized P&L
    pub fn apply_sell(&mut self, trade: &HoldingTransaction) -> Decimal {
        let realized_pnl = (trade.price - self.avg_cost) * trade.quantity - trade.fee;
        self.quantity -= trade.quantity;
        if self.quantity <= Decimal::ZERO {
            self.quantity = Decimal::ZERO;
            self.avg_cost = Decimal::ZERO;
        }
        realized_pnl
    }

    /// Market value at given price
    pub fn market_value(&self, current_price: Decimal) -> Decimal {
        self.quantity * current_price
    }

    /// Unrealized P&L at given price
    pub fn unrealized_pnl(&self, current_price: Decimal) -> Decimal {
        (current_price - self.avg_cost) * self.quantity
    }

    /// Apply a DIVIDEND — cash distribution, does not change quantity or avg_cost
    pub fn apply_dividend(&mut self, _cash_per_share: Decimal, total_amount: Decimal) {
        assert!(
            total_amount > Decimal::ZERO,
            "dividend total_amount must be positive"
        );
        // Dividends are cash distributions; quantity and avg_cost remain unchanged
    }

    /// Apply a SPLIT — multiply quantity by ratio, divide avg_cost by ratio
    pub fn apply_split(&mut self, ratio: Decimal) {
        assert!(ratio > Decimal::ZERO, "split ratio must be positive");
        self.quantity *= ratio;
        self.avg_cost /= ratio;
    }
}
