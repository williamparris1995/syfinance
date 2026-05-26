use crate::application::dtos::{
    CreateSecurityDto, HoldingDto, HoldingTradeDto, SecurityDto,
};
use crate::domain::{
    aggregates::{
        holding::{Holding, HoldingTransaction, HoldingTransactionType},
        security::{Security, SecurityType},
        Transaction,
    },
    repositories::{AccountRepository, HoldingRepository, SecurityRepository, TransactionRepository},
    value_objects::{Money, SyncMetadata, TransactionEntry},
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteHoldingRepository, SqliteSecurityRepository,
    SqliteTransactionRepository,
};
use rust_decimal::Decimal;
use std::sync::Arc;
use uuid::Uuid;

pub struct HoldingService {
    security_repo: Arc<SqliteSecurityRepository>,
    holding_repo: Arc<SqliteHoldingRepository>,
    account_repo: Arc<SqliteAccountRepository>,
    transaction_repo: Arc<SqliteTransactionRepository>,
}

#[derive(Debug)]
pub enum HoldingServiceError {
    AccountNotFound(Uuid),
    SecurityNotFound(Uuid),
    HoldingNotFound(Uuid),
    InsufficientQuantity { available: Decimal, requested: Decimal },
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for HoldingServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::SecurityNotFound(id) => write!(f, "security not found: {id}"),
            Self::HoldingNotFound(id) => write!(f, "holding not found: {id}"),
            Self::InsufficientQuantity { available, requested } =>
                write!(f, "insufficient quantity: have {available}, need {requested}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for HoldingServiceError {}
impl From<sqlx::Error> for HoldingServiceError {
    fn from(err: sqlx::Error) -> Self { Self::RepositoryError(err.to_string()) }
}

impl HoldingService {
    pub fn new(
        security_repo: Arc<SqliteSecurityRepository>,
        holding_repo: Arc<SqliteHoldingRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        transaction_repo: Arc<SqliteTransactionRepository>,
    ) -> Self {
        Self { security_repo, holding_repo, account_repo, transaction_repo }
    }

    // --- Securities ---

    pub async fn create_security(&self, dto: CreateSecurityDto) -> Result<SecurityDto, HoldingServiceError> {
        let id = Uuid::new_v4();
        let st = parse_security_type(&dto.security_type)?;
        let security = Security::new(id, dto.symbol, dto.name, st, dto.exchange, dto.currency_code, None);
        self.security_repo.create(&security).await?;
        Ok(self.security_to_dto(&security))
    }

    pub async fn list_securities(&self) -> Result<Vec<SecurityDto>, HoldingServiceError> {
        let securities = self.security_repo.find_all().await?;
        Ok(securities.iter().map(|s| self.security_to_dto(s)).collect())
    }

    pub async fn update_security_price(&self, id: Uuid, price: Decimal) -> Result<(), HoldingServiceError> {
        self.security_repo.find_by_id(id).await?.ok_or(HoldingServiceError::SecurityNotFound(id))?;
        self.security_repo.update_price(id, price).await?;
        Ok(())
    }

    // --- BUY ---

    pub async fn buy(&self, dto: HoldingTradeDto) -> Result<Uuid, HoldingServiceError> {
        let account = self.account_repo.find_by_id(dto.account_id).await?
            .ok_or(HoldingServiceError::AccountNotFound(dto.account_id))?;
        let security = self.security_repo.find_by_id(dto.security_id).await?
            .ok_or(HoldingServiceError::SecurityNotFound(dto.security_id))?;

        let amount = (dto.quantity * dto.price).round_dp(2);
        let device_id = Uuid::new_v4();
        let txn_id = Uuid::new_v4();

        // Double-entry: Debit 1101 (financial asset), Debit 5301 (fee), Credit 1002 (bank)
        let asset_money = Money::new(amount, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        let fee_money = Money::new(dto.fee, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        let total_money = Money::new(amount + dto.fee, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;

        let entries = vec![
            TransactionEntry::new(dto.account_id, "1101", Some(asset_money), None, &security.name)
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(dto.account_id, "5301", Some(fee_money), None, "Trade fee")
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(dto.account_id, "1002", None, Some(total_money), &format!("Buy {}", security.symbol))
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
        ];

        let transaction = Transaction::new(txn_id, dto.trade_date,
            format!("Buy {} {} @ {}", security.symbol, dto.quantity, dto.price),
            entries, SyncMetadata::new(device_id))
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        self.transaction_repo.create(&transaction).await?;

        // Create holding_transaction record
        let ht = HoldingTransaction {
            id: Uuid::new_v4(), account_id: dto.account_id, security_id: dto.security_id,
            trade_type: HoldingTransactionType::Buy, quantity: dto.quantity,
            price: dto.price, amount, fee: dto.fee, trade_date: dto.trade_date,
            transaction_id: Some(txn_id), notes: dto.notes,
        };
        self.holding_repo.create_transaction(&ht).await?;

        // Update or create holding
        let holdings = self.holding_repo.find_by_account(dto.account_id).await?;
        if let Some(mut h) = holdings.into_iter().find(|h| h.security_id == dto.security_id) {
            h.apply_buy(&ht);
            self.holding_repo.upsert(&h).await?;
        } else {
            let mut h = Holding::new(Uuid::new_v4(), dto.account_id, dto.security_id, Decimal::ZERO, Decimal::ZERO);
            h.apply_buy(&ht);
            self.holding_repo.upsert(&h).await?;
        }

        Ok(txn_id)
    }

    // --- SELL ---

    pub async fn sell(&self, dto: HoldingTradeDto) -> Result<Uuid, HoldingServiceError> {
        let account = self.account_repo.find_by_id(dto.account_id).await?
            .ok_or(HoldingServiceError::AccountNotFound(dto.account_id))?;
        let security = self.security_repo.find_by_id(dto.security_id).await?
            .ok_or(HoldingServiceError::SecurityNotFound(dto.security_id))?;

        let holdings = self.holding_repo.find_by_account(dto.account_id).await?;
        let mut holding = holdings.iter().find(|h| h.security_id == dto.security_id)
            .cloned()
            .ok_or(HoldingServiceError::HoldingNotFound(dto.security_id))?;

        if holding.quantity < dto.quantity {
            return Err(HoldingServiceError::InsufficientQuantity {
                available: holding.quantity, requested: dto.quantity,
            });
        }

        let amount = (dto.quantity * dto.price).round_dp(2);
        let device_id = Uuid::new_v4();
        let txn_id = Uuid::new_v4();

        let ht = HoldingTransaction {
            id: Uuid::new_v4(), account_id: dto.account_id, security_id: dto.security_id,
            trade_type: HoldingTransactionType::Sell, quantity: dto.quantity,
            price: dto.price, amount, fee: dto.fee, trade_date: dto.trade_date,
            transaction_id: Some(txn_id), notes: dto.notes,
        };

        // Capture old avg_cost before apply_sell mutates it (needed when sell empties holding)
        let old_avg_cost = holding.avg_cost;
        let realized_pnl = holding.apply_sell(&ht);

        // Double-entry using OLD avg_cost for cost_basis
        let net_proceeds = Money::new(amount - dto.fee, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        let cost_basis = Money::new(old_avg_cost * dto.quantity, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;

        let mut entries = vec![
            TransactionEntry::new(dto.account_id, "1002", Some(net_proceeds), None, &format!("Sell {}", security.symbol))
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(dto.account_id, "1101", None, Some(cost_basis), &format!("Sell {}", security.symbol))
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
        ];

        if realized_pnl > Decimal::ZERO {
            let gain = Money::new(realized_pnl, &account.currency_code)
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
            entries.push(TransactionEntry::new(dto.account_id, "4201", None, Some(gain), "Realized gain")
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?);
        } else if realized_pnl < Decimal::ZERO {
            let loss = Money::new(-realized_pnl, &account.currency_code)
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
            entries.push(TransactionEntry::new(dto.account_id, "5101", Some(loss), None, "Realized loss")
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?);
        }

        let transaction = Transaction::new(txn_id, dto.trade_date,
            format!("Sell {} {} @ {}", security.symbol, dto.quantity, dto.price),
            entries, SyncMetadata::new(device_id))
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        self.transaction_repo.create(&transaction).await?;
        self.holding_repo.create_transaction(&ht).await?;

        if holding.quantity <= Decimal::ZERO {
            self.holding_repo.soft_delete(holding.id).await?;
        } else {
            self.holding_repo.upsert(&holding).await?;
        }

        Ok(txn_id)
    }

    // --- List holdings ---

    pub async fn list_holdings(&self) -> Result<Vec<HoldingDto>, HoldingServiceError> {
        let holdings = self.holding_repo.find_all().await?;
        let mut dtos = Vec::new();
        for h in holdings {
            if let (Ok(Some(acc)), Ok(Some(sec))) = (
                self.account_repo.find_by_id(h.account_id).await,
                self.security_repo.find_by_id(h.security_id).await,
            ) {
                dtos.push(HoldingDto {
                    id: h.id, account_id: h.account_id, account_name: acc.name,
                    security_id: h.security_id, symbol: sec.symbol.clone(),
                    security_name: sec.name.clone(), security_type: sec.security_type.to_string(),
                    quantity: h.quantity, avg_cost: h.avg_cost,
                    current_price: sec.current_price,
                    market_value: sec.current_price.map(|p| h.market_value(p)),
                    unrealized_pnl: sec.current_price.map(|p| h.unrealized_pnl(p)),
                    currency_code: sec.currency_code,
                });
            }
        }
        Ok(dtos)
    }

    // --- Helpers ---

    fn security_to_dto(&self, s: &Security) -> SecurityDto {
        SecurityDto {
            id: s.id, symbol: s.symbol.clone(), name: s.name.clone(),
            security_type: s.security_type.to_string(), exchange: s.exchange.clone(),
            currency_code: s.currency_code.clone(), current_price: s.current_price,
        }
    }
}

fn parse_security_type(s: &str) -> Result<SecurityType, HoldingServiceError> {
    match s {
        "stock" => Ok(SecurityType::Stock), "fund" => Ok(SecurityType::Fund),
        "etf" => Ok(SecurityType::Etf), "bond" => Ok(SecurityType::Bond),
        "gold" => Ok(SecurityType::Gold), "option" => Ok(SecurityType::Option),
        "other" => Ok(SecurityType::Other),
        _ => Err(HoldingServiceError::ValidationError(format!("invalid security type: {s}"))),
    }
}
