use crate::application::dtos::{
    CreateSecurityDto, HoldingDto, HoldingTradeDto, HoldingTransactionDto, SecurityDto,
    UpdateHoldingTradeRequest,
};
use crate::domain::{
    aggregates::{
        holding::{Holding, HoldingTransaction, HoldingTransactionType},
        security::{Security, SecurityType},
        Transaction,
    },
    repositories::{
        AccountRepository, HoldingRepository, SecurityRepository, TransactionRepository,
    },
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
    InsufficientQuantity {
        available: Decimal,
        requested: Decimal,
    },
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for HoldingServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::AccountNotFound(id) => write!(f, "account not found: {id}"),
            Self::SecurityNotFound(id) => write!(f, "security not found: {id}"),
            Self::HoldingNotFound(id) => write!(f, "holding not found: {id}"),
            Self::InsufficientQuantity {
                available,
                requested,
            } => write!(
                f,
                "insufficient quantity: have {available}, need {requested}"
            ),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for HoldingServiceError {}
impl From<sqlx::Error> for HoldingServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl HoldingService {
    pub fn new(
        security_repo: Arc<SqliteSecurityRepository>,
        holding_repo: Arc<SqliteHoldingRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        transaction_repo: Arc<SqliteTransactionRepository>,
    ) -> Self {
        Self {
            security_repo,
            holding_repo,
            account_repo,
            transaction_repo,
        }
    }

    // --- Securities ---

    pub async fn create_security(
        &self,
        dto: CreateSecurityDto,
    ) -> Result<SecurityDto, HoldingServiceError> {
        let id = Uuid::new_v4();
        let st = parse_security_type(&dto.security_type)?;
        let security = Security::new(
            id,
            dto.symbol,
            dto.name,
            st,
            dto.exchange,
            dto.currency_code,
            None,
        );
        self.security_repo.create(&security).await?;
        Ok(self.security_to_dto(&security))
    }

    pub async fn list_securities(&self) -> Result<Vec<SecurityDto>, HoldingServiceError> {
        let securities = self.security_repo.find_all().await?;
        Ok(securities.iter().map(|s| self.security_to_dto(s)).collect())
    }

    pub async fn update_security_price(
        &self,
        id: Uuid,
        price: Decimal,
    ) -> Result<(), HoldingServiceError> {
        self.security_repo
            .find_by_id(id)
            .await?
            .ok_or(HoldingServiceError::SecurityNotFound(id))?;
        self.security_repo.update_price(id, price).await?;
        Ok(())
    }

    // --- BUY ---

    pub async fn buy(&self, dto: HoldingTradeDto) -> Result<Uuid, HoldingServiceError> {
        let account = self
            .account_repo
            .find_by_id(dto.account_id)
            .await?
            .ok_or(HoldingServiceError::AccountNotFound(dto.account_id))?;
        let security = self
            .security_repo
            .find_by_id(dto.security_id)
            .await?
            .ok_or(HoldingServiceError::SecurityNotFound(dto.security_id))?;

        let amount = dto.quantity * dto.price;
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
            TransactionEntry::new(
                dto.account_id,
                "1101",
                Some(asset_money),
                None,
                &security.name,
            )
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(dto.account_id, "5301", Some(fee_money), None, "Trade fee")
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(
                dto.account_id,
                "1002",
                None,
                Some(total_money),
                &format!("Buy {}", security.symbol),
            )
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
        ];

        let transaction = Transaction::new(
            txn_id,
            dto.trade_date,
            format!("Buy {} {} @ {}", security.symbol, dto.quantity, dto.price),
            entries,
            SyncMetadata::new(device_id),
        )
        .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        self.transaction_repo.create(&transaction).await?;

        // Create holding_transaction record
        let ht = HoldingTransaction {
            id: Uuid::new_v4(),
            account_id: dto.account_id,
            security_id: dto.security_id,
            trade_type: HoldingTransactionType::Buy,
            quantity: dto.quantity,
            price: dto.price,
            amount,
            fee: dto.fee,
            trade_date: dto.trade_date,
            transaction_id: Some(txn_id),
            notes: dto.notes,
        };
        self.holding_repo.create_transaction(&ht).await?;

        // Update or create holding
        let holdings = self.holding_repo.find_by_account(dto.account_id).await?;
        if let Some(mut h) = holdings
            .into_iter()
            .find(|h| h.security_id == dto.security_id)
        {
            h.apply_buy(&ht);
            self.holding_repo.upsert(&h).await?;
        } else {
            let mut h = Holding::new(
                Uuid::new_v4(),
                dto.account_id,
                dto.security_id,
                Decimal::ZERO,
                Decimal::ZERO,
            );
            h.apply_buy(&ht);
            self.holding_repo.upsert(&h).await?;
        }

        Ok(txn_id)
    }

    // --- SELL ---

    pub async fn sell(&self, dto: HoldingTradeDto) -> Result<Uuid, HoldingServiceError> {
        let account = self
            .account_repo
            .find_by_id(dto.account_id)
            .await?
            .ok_or(HoldingServiceError::AccountNotFound(dto.account_id))?;
        let security = self
            .security_repo
            .find_by_id(dto.security_id)
            .await?
            .ok_or(HoldingServiceError::SecurityNotFound(dto.security_id))?;

        let holdings = self.holding_repo.find_by_account(dto.account_id).await?;
        let mut holding = holdings
            .iter()
            .find(|h| h.security_id == dto.security_id)
            .cloned()
            .ok_or(HoldingServiceError::HoldingNotFound(dto.security_id))?;

        if holding.quantity < dto.quantity {
            return Err(HoldingServiceError::InsufficientQuantity {
                available: holding.quantity,
                requested: dto.quantity,
            });
        }

        let amount = dto.quantity * dto.price;
        let device_id = Uuid::new_v4();
        let txn_id = Uuid::new_v4();

        let ht = HoldingTransaction {
            id: Uuid::new_v4(),
            account_id: dto.account_id,
            security_id: dto.security_id,
            trade_type: HoldingTransactionType::Sell,
            quantity: dto.quantity,
            price: dto.price,
            amount,
            fee: dto.fee,
            trade_date: dto.trade_date,
            transaction_id: Some(txn_id),
            notes: dto.notes,
        };

        // Capture old avg_cost before apply_sell mutates it (needed when sell empties holding)
        let old_avg_cost = holding.avg_cost;
        let _realized_pnl = holding.apply_sell(&ht);

        // Double-entry using OLD avg_cost for cost_basis
        let net_proceeds_amount = amount - dto.fee;
        let cost_basis_amount = old_avg_cost * dto.quantity;
        let realized_amount = net_proceeds_amount - cost_basis_amount;

        let net_proceeds = Money::new(net_proceeds_amount, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        let cost_basis = Money::new(cost_basis_amount, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;

        let mut entries = vec![
            TransactionEntry::new(
                dto.account_id,
                "1002",
                Some(net_proceeds),
                None,
                &format!("Sell {}", security.symbol),
            )
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(
                dto.account_id,
                "1101",
                None,
                Some(cost_basis),
                &format!("Sell {}", security.symbol),
            )
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
        ];

        if realized_amount > Decimal::ZERO {
            let gain = Money::new(realized_amount, &account.currency_code)
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
            entries.push(
                TransactionEntry::new(dto.account_id, "4201", None, Some(gain), "Realized gain")
                    .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            );
        } else if realized_amount < Decimal::ZERO {
            let loss = Money::new(-realized_amount, &account.currency_code)
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
            entries.push(
                TransactionEntry::new(dto.account_id, "5101", Some(loss), None, "Realized loss")
                    .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            );
        }

        let transaction = Transaction::new(
            txn_id,
            dto.trade_date,
            format!("Sell {} {} @ {}", security.symbol, dto.quantity, dto.price),
            entries,
            SyncMetadata::new(device_id),
        )
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
                    id: h.id,
                    account_id: h.account_id,
                    account_name: acc.name,
                    security_id: h.security_id,
                    symbol: sec.symbol.clone(),
                    security_name: sec.name.clone(),
                    security_type: sec.security_type.to_string(),
                    quantity: h.quantity,
                    avg_cost: h.avg_cost,
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
            id: s.id,
            symbol: s.symbol.clone(),
            name: s.name.clone(),
            security_type: s.security_type.to_string(),
            exchange: s.exchange.clone(),
            currency_code: s.currency_code.clone(),
            current_price: s.current_price,
        }
    }

    // --- List trade history for a holding ---

    pub async fn list_holding_transactions(
        &self,
        holding_id: Uuid,
    ) -> Result<Vec<HoldingTransactionDto>, HoldingServiceError> {
        let trades = self
            .holding_repo
            .find_transactions_by_holding_id(holding_id)
            .await?;
        Ok(trades
            .into_iter()
            .map(|t| HoldingTransactionDto {
                id: t.id,
                holding_id,
                transaction_id: t.transaction_id,
                trade_type: t.trade_type.to_string(),
                quantity: t.quantity,
                price: t.price,
                fee: t.fee,
                amount: t.amount,
                trade_date: t.trade_date,
                notes: t.notes,
            })
            .collect())
    }

    // --- Recalculate holding after trade changes ---

    async fn recalculate_holding(&self, holding_id: Uuid) -> Result<(), HoldingServiceError> {
        let trades = self
            .holding_repo
            .find_transactions_by_holding_id(holding_id)
            .await?;

        let mut quantity = Decimal::ZERO;
        let mut total_cost = Decimal::ZERO;

        for trade in &trades {
            match trade.trade_type {
                HoldingTransactionType::Buy => {
                    total_cost += trade.quantity * trade.price + trade.fee;
                    quantity += trade.quantity;
                }
                HoldingTransactionType::Sell => {
                    let avg = if quantity > Decimal::ZERO {
                        total_cost / quantity
                    } else {
                        Decimal::ZERO
                    };
                    let sold_cost = trade.quantity * avg;
                    total_cost -= sold_cost;
                    quantity -= trade.quantity;
                }
                _ => {}
            }
        }

        if quantity <= Decimal::ZERO {
            self.holding_repo
                .soft_delete_holding_by_id(holding_id)
                .await?;
        } else {
            let avg_cost = total_cost / quantity;
            self.holding_repo
                .update_holding_quantities(holding_id, quantity, avg_cost)
                .await?;
        }
        Ok(())
    }

    // --- Delete trade with cascade to transaction ---

    pub async fn delete_holding_trade(
        &self,
        holding_transaction_id: Uuid,
    ) -> Result<(), HoldingServiceError> {
        let ht = self
            .holding_repo
            .find_holding_transaction_by_id(holding_transaction_id)
            .await?
            .ok_or(HoldingServiceError::ValidationError(
                "holding transaction not found".into(),
            ))?;

        // Find the holding for this trade to get holding_id for recalculation
        let holdings = self.holding_repo.find_by_account(ht.account_id).await?;
        let holding = holdings
            .into_iter()
            .find(|h| h.security_id == ht.security_id);

        // Soft-delete the holding_transaction
        self.holding_repo
            .soft_delete_holding_transaction(holding_transaction_id)
            .await?;

        // Soft-delete the associated transaction (and its entries)
        if let Some(tx_id) = ht.transaction_id {
            self.holding_repo
                .soft_delete_transaction_cascade(tx_id)
                .await?;
        }

        // Recalculate the holding
        if let Some(h) = holding {
            self.recalculate_holding(h.id).await?;
        }

        Ok(())
    }

    // --- Update trade with transaction sync ---

    pub async fn update_holding_trade(
        &self,
        req: UpdateHoldingTradeRequest,
    ) -> Result<(), HoldingServiceError> {
        let ht = self
            .holding_repo
            .find_holding_transaction_by_id(req.holding_transaction_id)
            .await?
            .ok_or(HoldingServiceError::ValidationError(
                "holding transaction not found".into(),
            ))?;

        // Find the holding for recalculation
        let holdings = self.holding_repo.find_by_account(ht.account_id).await?;
        let holding = holdings
            .into_iter()
            .find(|h| h.security_id == ht.security_id);

        // Update the holding_transaction row
        self.holding_repo
            .update_holding_transaction(
                req.holding_transaction_id,
                req.quantity,
                req.price,
                req.fee,
                req.trade_date,
            )
            .await?;

        // Update the associated transaction entries
        if let Some(tx_id) = ht.transaction_id {
            let _account = self
                .account_repo
                .find_by_id(ht.account_id)
                .await?
                .ok_or(HoldingServiceError::AccountNotFound(ht.account_id))?;
            let security = self
                .security_repo
                .find_by_id(ht.security_id)
                .await?
                .ok_or(HoldingServiceError::SecurityNotFound(ht.security_id))?;

            let new_amount = req.quantity * req.price;
            let total = new_amount + req.fee;

            // Update transaction date and description
            let desc = match ht.trade_type {
                HoldingTransactionType::Buy => {
                    format!("Buy {} {} @ {}", security.symbol, req.quantity, req.price)
                }
                HoldingTransactionType::Sell => {
                    format!("Sell {} {} @ {}", security.symbol, req.quantity, req.price)
                }
                _ => format!("Trade {} {}", security.symbol, req.quantity),
            };
            sqlx::query("UPDATE transactions SET transaction_date=?, description=?, updated_at=? WHERE id=? AND deleted_at IS NULL")
                .bind(req.trade_date.to_string()).bind(&desc).bind(chrono::Utc::now().to_rfc3339())
                .bind(tx_id.to_string())
                .execute(self.holding_repo.pool()).await.map_err(|e| HoldingServiceError::RepositoryError(e.to_string()))?;

            // Soft-delete old entries and create new ones
            sqlx::query("UPDATE transaction_entries SET deleted_at=? WHERE transaction_id=? AND deleted_at IS NULL")
                .bind(chrono::Utc::now().to_rfc3339()).bind(tx_id.to_string())
                .execute(self.holding_repo.pool()).await.map_err(|e| HoldingServiceError::RepositoryError(e.to_string()))?;

            match ht.trade_type {
                HoldingTransactionType::Buy => {
                    // Debit 1101 (asset = qty*price), Debit 5301 (fee), Credit 1002 (bank = total)
                    let entries = vec![
                        (
                            ht.account_id.to_string(),
                            "1101",
                            new_amount.to_string(),
                            String::new(),
                            security.name.clone(),
                        ),
                        (
                            ht.account_id.to_string(),
                            "5301",
                            req.fee.to_string(),
                            String::new(),
                            "Trade fee".to_string(),
                        ),
                        (
                            ht.account_id.to_string(),
                            "1002",
                            String::new(),
                            total.to_string(),
                            format!("Buy {}", security.symbol),
                        ),
                    ];
                    for (acc_id, code, debit, credit, note) in entries {
                        let entry_id = uuid::Uuid::new_v4().to_string();
                        sqlx::query(
                            "INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount, note, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
                        )
                        .bind(&entry_id).bind(tx_id.to_string()).bind(&acc_id).bind(code)
                        .bind(if debit.is_empty() { "0" } else { &debit })
                        .bind(if credit.is_empty() { "0" } else { &credit })
                        .bind(&note).bind(chrono::Utc::now().to_rfc3339())
                        .execute(self.holding_repo.pool()).await.map_err(|e| HoldingServiceError::RepositoryError(e.to_string()))?;
                    }
                }
                HoldingTransactionType::Sell => {
                    let net_proceeds = new_amount - req.fee;
                    let cost_basis = if let Some(h) = &holding {
                        h.avg_cost * req.quantity
                    } else {
                        Decimal::ZERO
                    };

                    let mut entries = vec![
                        (
                            ht.account_id.to_string(),
                            "1002",
                            net_proceeds.to_string(),
                            String::new(),
                            format!("Sell {}", security.symbol),
                        ),
                        (
                            ht.account_id.to_string(),
                            "1101",
                            String::new(),
                            cost_basis.to_string(),
                            format!("Sell {}", security.symbol),
                        ),
                    ];

                    let pnl = net_proceeds - cost_basis;
                    if pnl > Decimal::ZERO {
                        entries.push((
                            ht.account_id.to_string(),
                            "4201",
                            String::new(),
                            pnl.to_string(),
                            "Realized gain".to_string(),
                        ));
                    } else if pnl < Decimal::ZERO {
                        entries.push((
                            ht.account_id.to_string(),
                            "5101",
                            (-pnl).to_string(),
                            String::new(),
                            "Realized loss".to_string(),
                        ));
                    }

                    for (acc_id, code, debit, credit, note) in entries {
                        let entry_id = uuid::Uuid::new_v4().to_string();
                        sqlx::query(
                            "INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount, note, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
                        )
                        .bind(&entry_id).bind(tx_id.to_string()).bind(&acc_id).bind(code)
                        .bind(if debit.is_empty() { "0" } else { &debit })
                        .bind(if credit.is_empty() { "0" } else { &credit })
                        .bind(&note).bind(chrono::Utc::now().to_rfc3339())
                        .execute(self.holding_repo.pool()).await.map_err(|e| HoldingServiceError::RepositoryError(e.to_string()))?;
                    }
                }
                _ => {}
            }
        }

        // Recalculate holding
        if let Some(h) = holding {
            self.recalculate_holding(h.id).await?;
        }

        Ok(())
    }
}

fn parse_security_type(s: &str) -> Result<SecurityType, HoldingServiceError> {
    match s {
        "stock" => Ok(SecurityType::Stock),
        "fund" => Ok(SecurityType::Fund),
        "etf" => Ok(SecurityType::Etf),
        "bond" => Ok(SecurityType::Bond),
        "gold" => Ok(SecurityType::Gold),
        "option" => Ok(SecurityType::Option),
        "other" => Ok(SecurityType::Other),
        _ => Err(HoldingServiceError::ValidationError(format!(
            "invalid security type: {s}"
        ))),
    }
}
