# Asset Holdings System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add transaction-driven holdings layer to Investment accounts, enabling atomic-level tracking of individual securities with double-entry accounting on every buy/sell.

**Architecture:** Three new tables (securities, holdings, holding_transactions). Holdings are computed from transactions (append-only), not directly edited. Each BUY/SELL creates a double-entry Transaction via the existing `transactions` system. Dashboard groups holdings by asset_type.

**Tech Stack:** Rust/Tauri (sqlx, SQLite), React 19/TypeScript, @base-ui/react, recharts, react-i18next

---

### File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `src-tauri/migrations/20260527000001_create_holdings.sql` | Create | DDL for securities, holdings, holding_transactions |
| `src-tauri/src/domain/aggregates/security.rs` | Create | Security domain model |
| `src-tauri/src/domain/aggregates/holding.rs` | Create | Holding + HoldingTransaction domain models |
| `src-tauri/src/domain/aggregates/mod.rs` | Modify | Register new modules |
| `src-tauri/src/domain/repositories/mod.rs` | Modify | Add SecurityRepo + HoldingRepo traits |
| `src-tauri/src/infrastructure/repositories/security_repository.rs` | Create | Security CRUD (SQLite) |
| `src-tauri/src/infrastructure/repositories/holding_repository.rs` | Create | Holding query + transaction append (SQLite) |
| `src-tauri/src/application/dtos/holding_dto.rs` | Create | DTOs for securities, holdings, trades |
| `src-tauri/src/application/dtos/mod.rs` | Modify | Re-export new DTOs |
| `src-tauri/src/application/services/holding_service.rs` | Create | BUY/SELL logic + holding recomputation |
| `src-tauri/src/presentation/tauri_commands/holding_commands.rs` | Create | Tauri commands |
| `src-tauri/src/presentation/tauri_commands/mod.rs` | Modify | Register holding commands |
| `src-tauri/src/main.rs` | Modify | Register commands + state |
| `src/lib/tauri/holding.ts` | Create | Frontend API types + functions |
| `src/components/HoldingTradeForm.tsx` | Create | BUY/SELL form |
| `src/components/SecurityForm.tsx` | Create | Add/edit security form |
| `src/pages/HoldingsPage.tsx` | Create | Portfolio overview page |
| `src/pages/HomePage.tsx` | Modify | Holdings summary cards in dashboard |
| `src/i18n/locales/en.json` | Modify | New keys |
| `src/i18n/locales/zh.json` | Modify | New keys |

---

### Task 1: DB Migration — securities, holdings, holding_transactions

**Files:**
- Create: `src-tauri/migrations/20260527000001_create_holdings.sql`

- [ ] **Step 1: Write migration**

```sql
-- Securities reference table
CREATE TABLE IF NOT EXISTS securities (
    id TEXT PRIMARY KEY NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL,
    exchange VARCHAR(30),
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    current_price DECIMAL(20,4),
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (type IN ('stock', 'fund', 'etf', 'bond', 'gold', 'option', 'other')),
    FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT
);

CREATE INDEX idx_securities_symbol ON securities(symbol);
CREATE INDEX idx_securities_type ON securities(type);

-- Holdings table (computed from transactions)
CREATE TABLE IF NOT EXISTS holdings (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL,
    security_id TEXT NOT NULL,
    quantity DECIMAL(20,8) NOT NULL DEFAULT 0,
    avg_cost DECIMAL(20,4) NOT NULL DEFAULT 0,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    UNIQUE(account_id, security_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (security_id) REFERENCES securities(id) ON DELETE RESTRICT
);

CREATE INDEX idx_holdings_account ON holdings(account_id);

-- Holding transactions (append-only ledger)
CREATE TABLE IF NOT EXISTS holding_transactions (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL,
    security_id TEXT NOT NULL,
    type VARCHAR(10) NOT NULL,
    quantity DECIMAL(20,8) NOT NULL,
    price DECIMAL(20,4) NOT NULL,
    amount DECIMAL(20,2) NOT NULL,
    fee DECIMAL(20,2) NOT NULL DEFAULT 0,
    trade_date DATE NOT NULL,
    transaction_id TEXT,
    notes TEXT,
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (type IN ('BUY', 'SELL', 'DIVIDEND', 'SPLIT')),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (security_id) REFERENCES securities(id) ON DELETE RESTRICT,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
);

CREATE INDEX idx_ht_account ON holding_transactions(account_id);
CREATE INDEX idx_ht_security ON holding_transactions(security_id);
CREATE INDEX idx_ht_date ON holding_transactions(trade_date);
```

- [ ] **Step 2: Commit**

```bash
git add src-tauri/migrations/20260527000001_create_holdings.sql
git commit -m "feat: add securities, holdings, holding_transactions tables"
```

---

### Task 2: Security Domain Model

**Files:**
- Create: `src-tauri/src/domain/aggregates/security.rs`
- Modify: `src-tauri/src/domain/aggregates/mod.rs`

- [ ] **Step 1: Create security.rs**

```rust
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
        Self { id, symbol, name, security_type, exchange, currency_code, current_price }
    }
}
```

- [ ] **Step 2: Register in mod.rs**

Add after `pub mod debt_details;`:
```rust
pub mod holding;
pub mod security;
```

- [ ] **Step 3: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: zero errors (holding.rs doesn't exist yet, will error — that's Task 3)

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/domain/aggregates/security.rs src-tauri/src/domain/aggregates/mod.rs
git commit -m "feat: add Security domain model"
```

---

### Task 3: Holding Domain Model

**Files:**
- Create: `src-tauri/src/domain/aggregates/holding.rs`

- [ ] **Step 1: Create holding.rs**

```rust
use chrono::NaiveDate;
use rust_decimal::Decimal;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
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
    pub fn new(id: Uuid, account_id: Uuid, security_id: Uuid, quantity: Decimal, avg_cost: Decimal) -> Self {
        Self { id, account_id, security_id, quantity, avg_cost }
    }

    /// Apply a BUY transaction to this holding
    pub fn apply_buy(&mut self, trade: &HoldingTransaction) {
        let total_cost = self.avg_cost * self.quantity + trade.amount + trade.fee;
        self.quantity += trade.quantity;
        self.avg_cost = if self.quantity > Decimal::ZERO {
            (total_cost / self.quantity).round_dp(4)
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
        realized_pnl.round_dp(2)
    }

    /// Market value at given price
    pub fn market_value(&self, current_price: Decimal) -> Decimal {
        (self.quantity * current_price).round_dp(2)
    }

    /// Unrealized P&L at given price
    pub fn unrealized_pnl(&self, current_price: Decimal) -> Decimal {
        ((current_price - self.avg_cost) * self.quantity).round_dp(2)
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: zero errors

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/domain/aggregates/holding.rs
git commit -m "feat: add Holding domain model with apply_buy/apply_sell"
```

---

### Task 4: Repository Traits

**Files:**
- Modify: `src-tauri/src/domain/repositories/mod.rs`

- [ ] **Step 1: Add SecurityRepository and HoldingRepository traits**

Add after the ChartOfAccountsRepository trait block:

```rust
use crate::domain::aggregates::holding::{Holding, HoldingTransaction};
use crate::domain::aggregates::security::{Security, SecurityType};

#[allow(async_fn_in_trait, dead_code)]
pub trait SecurityRepository: Send + Sync {
    async fn create(&self, security: &Security) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Security>>;
    async fn find_by_symbol(&self, symbol: &str) -> sqlx::Result<Option<Security>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Security>>;
    async fn find_by_type(&self, security_type: &SecurityType) -> sqlx::Result<Vec<Security>>;
    async fn update(&self, security: &Security) -> sqlx::Result<bool>;
    async fn update_price(&self, id: Uuid, price: Decimal) -> sqlx::Result<bool>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;
}

#[allow(async_fn_in_trait, dead_code)]
pub trait HoldingRepository: Send + Sync {
    async fn find_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<Holding>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Holding>>;
    async fn upsert(&self, holding: &Holding) -> sqlx::Result<()>;
    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool>;

    async fn create_transaction(&self, txn: &HoldingTransaction) -> sqlx::Result<()>;
    async fn find_transactions_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<HoldingTransaction>>;
    async fn find_transactions_by_holding(&self, account_id: Uuid, security_id: Uuid) -> sqlx::Result<Vec<HoldingTransaction>>;
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: errors about missing trait implementations — expected, will be resolved in Tasks 5-6

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/domain/repositories/mod.rs
git commit -m "feat: add SecurityRepository and HoldingRepository traits"
```

---

### Task 5: Security Repository Implementation

**Files:**
- Create: `src-tauri/src/infrastructure/repositories/security_repository.rs`

- [ ] **Step 1: Implement SqliteSecurityRepository**

Follow the existing `account_repository.rs` pattern. Use text-based UUID/Decimal serialization.

```rust
use crate::domain::aggregates::security::{Security, SecurityType};
use crate::domain::repositories::SecurityRepository;
use chrono::Utc;
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteSecurityRepository { pool: SqlitePool }

impl SqliteSecurityRepository {
    pub fn new(pool: SqlitePool) -> Self { Self { pool } }

    fn parse_type(s: &str) -> Result<SecurityType, sqlx::Error> {
        match s {
            "stock" => Ok(SecurityType::Stock),
            "fund" => Ok(SecurityType::Fund),
            "etf" => Ok(SecurityType::Etf),
            "bond" => Ok(SecurityType::Bond),
            "gold" => Ok(SecurityType::Gold),
            "option" => Ok(SecurityType::Option),
            "other" => Ok(SecurityType::Other),
            _ => Err(sqlx::Error::Decode(format!("invalid security type: {}", s).into())),
        }
    }

    fn row_to_security(row: &sqlx::sqlite::SqliteRow) -> Result<Security, sqlx::Error> {
        let id_str: String = row.try_get("id")?;
        let id = Uuid::parse_str(&id_str)
            .map_err(|e| sqlx::Error::Decode(format!("invalid UUID: {}", e).into()))?;
        let symbol: String = row.try_get("symbol")?;
        let name: String = row.try_get("name")?;
        let type_str: String = row.try_get("type")?;
        let security_type = Self::parse_type(&type_str)?;
        let exchange: Option<String> = row.try_get("exchange")?;
        let currency_code: String = row.try_get("currency_code")?;
        let price_str: Option<String> = row.try_get("current_price")?;
        let current_price = price_str
            .map(|s| Decimal::from_str(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(format!("invalid decimal: {}", e).into()))?;
        Ok(Security::new(id, symbol, name, security_type, exchange, currency_code, current_price))
    }
}

impl SecurityRepository for SqliteSecurityRepository {
    async fn create(&self, s: &Security) -> sqlx::Result<()> {
        sqlx::query(
            "INSERT INTO securities (id, symbol, name, type, exchange, currency_code, current_price, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(s.id.to_string()).bind(&s.symbol).bind(&s.name)
        .bind(s.security_type.to_string()).bind(&s.exchange).bind(&s.currency_code)
        .bind(s.current_price.map(|p| p.to_string())).bind(Utc::now().to_rfc3339())
        .execute(&self.pool).await?;
        Ok(())
    }

    async fn find_by_id(&self, id: Uuid) -> sqlx::Result<Option<Security>> {
        let row = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE id = ? AND deleted_at IS NULL"
        ).bind(id.to_string()).fetch_optional(&self.pool).await?;
        row.map(|r| Self::row_to_security(&r)).transpose()
    }

    async fn find_by_symbol(&self, symbol: &str) -> sqlx::Result<Option<Security>> {
        let row = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE symbol = ? AND deleted_at IS NULL"
        ).bind(symbol).fetch_optional(&self.pool).await?;
        row.map(|r| Self::row_to_security(&r)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Security>> {
        let rows = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE deleted_at IS NULL ORDER BY symbol"
        ).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_security(r)).collect()
    }

    async fn find_by_type(&self, st: &SecurityType) -> sqlx::Result<Vec<Security>> {
        let rows = sqlx::query(
            "SELECT id, symbol, name, type, exchange, currency_code, CAST(current_price AS TEXT) as current_price
             FROM securities WHERE type = ? AND deleted_at IS NULL ORDER BY symbol"
        ).bind(st.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_security(r)).collect()
    }

    async fn update(&self, s: &Security) -> sqlx::Result<bool> {
        let result = sqlx::query(
            "UPDATE securities SET symbol=?, name=?, type=?, exchange=?, currency_code=?, current_price=?, updated_at=?
             WHERE id=? AND deleted_at IS NULL"
        )
        .bind(&s.symbol).bind(&s.name).bind(s.security_type.to_string())
        .bind(&s.exchange).bind(&s.currency_code)
        .bind(s.current_price.map(|p| p.to_string())).bind(Utc::now().to_rfc3339())
        .bind(s.id.to_string()).execute(&self.pool).await?;
        Ok(result.rows_affected() > 0)
    }

    async fn update_price(&self, id: Uuid, price: Decimal) -> sqlx::Result<bool> {
        let result = sqlx::query(
            "UPDATE securities SET current_price=?, updated_at=? WHERE id=? AND deleted_at IS NULL"
        ).bind(price.to_string()).bind(Utc::now().to_rfc3339()).bind(id.to_string())
        .execute(&self.pool).await?;
        Ok(result.rows_affected() > 0)
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let result = sqlx::query(
            "UPDATE securities SET deleted_at=? WHERE id=? AND deleted_at IS NULL"
        ).bind(Utc::now().to_rfc3339()).bind(id.to_string()).execute(&self.pool).await?;
        Ok(result.rows_affected() > 0)
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: errors about HoldingRepository missing — expected

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/security_repository.rs
git commit -m "feat: add SqliteSecurityRepository"
```

---

### Task 6: Holding Repository Implementation

**Files:**
- Create: `src-tauri/src/infrastructure/repositories/holding_repository.rs`

- [ ] **Step 1: Implement SqliteHoldingRepository**

```rust
use crate::domain::aggregates::holding::{Holding, HoldingTransaction, HoldingTransactionType};
use crate::domain::repositories::HoldingRepository;
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{Row, SqlitePool};
use std::str::FromStr;
use uuid::Uuid;

pub struct SqliteHoldingRepository { pool: SqlitePool }

impl SqliteHoldingRepository {
    pub fn new(pool: SqlitePool) -> Self { Self { pool } }

    fn parse_trade_type(s: &str) -> Result<HoldingTransactionType, sqlx::Error> {
        match s {
            "BUY" => Ok(HoldingTransactionType::Buy),
            "SELL" => Ok(HoldingTransactionType::Sell),
            "DIVIDEND" => Ok(HoldingTransactionType::Dividend),
            "SPLIT" => Ok(HoldingTransactionType::Split),
            _ => Err(sqlx::Error::Decode(format!("invalid trade type: {}", s).into())),
        }
    }

    fn row_to_holding(row: &sqlx::sqlite::SqliteRow) -> Result<Holding, sqlx::Error> {
        let id_str: String = row.try_get("id")?;
        let acc_str: String = row.try_get("account_id")?;
        let sec_str: String = row.try_get("security_id")?;
        let qty_str: String = row.try_get("quantity")?;
        let cost_str: String = row.try_get("avg_cost")?;
        Ok(Holding::new(
            Uuid::parse_str(&id_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Uuid::parse_str(&acc_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Uuid::parse_str(&sec_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Decimal::from_str(&qty_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            Decimal::from_str(&cost_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
        ))
    }

    fn row_to_ht(row: &sqlx::sqlite::SqliteRow) -> Result<HoldingTransaction, sqlx::Error> {
        let id_str: String = row.try_get("id")?;
        let acc_str: String = row.try_get("account_id")?;
        let sec_str: String = row.try_get("security_id")?;
        let type_str: String = row.try_get("type")?;
        let qty_str: String = row.try_get("quantity")?;
        let price_str: String = row.try_get("price")?;
        let amt_str: String = row.try_get("amount")?;
        let fee_str: String = row.try_get("fee")?;
        let date_str: String = row.try_get("trade_date")?;
        let txn_id: Option<String> = row.try_get("transaction_id")?;
        let notes: Option<String> = row.try_get("notes")?;
        Ok(HoldingTransaction {
            id: Uuid::parse_str(&id_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            account_id: Uuid::parse_str(&acc_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            security_id: Uuid::parse_str(&sec_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            trade_type: Self::parse_trade_type(&type_str)?,
            quantity: Decimal::from_str(&qty_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            price: Decimal::from_str(&price_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            amount: Decimal::from_str(&amt_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            fee: Decimal::from_str(&fee_str).map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            trade_date: NaiveDate::parse_from_str(&date_str, "%Y-%m-%d")
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            transaction_id: txn_id.map(|s| Uuid::parse_str(&s)).transpose()
                .map_err(|e| sqlx::Error::Decode(format!("{}", e).into()))?,
            notes,
        })
    }
}

impl HoldingRepository for SqliteHoldingRepository {
    async fn find_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<Holding>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, CAST(quantity AS TEXT) as quantity,
                    CAST(avg_cost AS TEXT) as avg_cost
             FROM holdings WHERE account_id = ? AND deleted_at IS NULL"
        ).bind(account_id.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_holding(r)).collect()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Holding>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, CAST(quantity AS TEXT) as quantity,
                    CAST(avg_cost AS TEXT) as avg_cost
             FROM holdings WHERE deleted_at IS NULL"
        ).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_holding(r)).collect()
    }

    async fn upsert(&self, h: &Holding) -> sqlx::Result<()> {
        sqlx::query(
            "INSERT INTO holdings (id, account_id, security_id, quantity, avg_cost, updated_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT(account_id, security_id) DO UPDATE SET
             quantity=excluded.quantity, avg_cost=excluded.avg_cost, updated_at=excluded.updated_at"
        )
        .bind(h.id.to_string()).bind(h.account_id.to_string()).bind(h.security_id.to_string())
        .bind(h.quantity.to_string()).bind(h.avg_cost.to_string()).bind(Utc::now().to_rfc3339())
        .execute(&self.pool).await?;
        Ok(())
    }

    async fn soft_delete(&self, id: Uuid) -> sqlx::Result<bool> {
        let r = sqlx::query("UPDATE holdings SET deleted_at=? WHERE id=? AND deleted_at IS NULL")
            .bind(Utc::now().to_rfc3339()).bind(id.to_string()).execute(&self.pool).await?;
        Ok(r.rows_affected() > 0)
    }

    async fn create_transaction(&self, txn: &HoldingTransaction) -> sqlx::Result<()> {
        sqlx::query(
            "INSERT INTO holding_transactions (id, account_id, security_id, type, quantity, price, amount, fee, trade_date, transaction_id, notes, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(txn.id.to_string()).bind(txn.account_id.to_string()).bind(txn.security_id.to_string())
        .bind(txn.trade_type.to_string()).bind(txn.quantity.to_string()).bind(txn.price.to_string())
        .bind(txn.amount.to_string()).bind(txn.fee.to_string()).bind(txn.trade_date.to_string())
        .bind(txn.transaction_id.map(|id| id.to_string())).bind(&txn.notes)
        .bind(Utc::now().to_rfc3339()).execute(&self.pool).await?;
        Ok(())
    }

    async fn find_transactions_by_account(&self, account_id: Uuid) -> sqlx::Result<Vec<HoldingTransaction>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity,
                    CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount,
                    CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes
             FROM holding_transactions WHERE account_id = ? AND deleted_at IS NULL ORDER BY trade_date DESC"
        ).bind(account_id.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_ht(r)).collect()
    }

    async fn find_transactions_by_holding(&self, account_id: Uuid, security_id: Uuid) -> sqlx::Result<Vec<HoldingTransaction>> {
        let rows = sqlx::query(
            "SELECT id, account_id, security_id, type, CAST(quantity AS TEXT) as quantity,
                    CAST(price AS TEXT) as price, CAST(amount AS TEXT) as amount,
                    CAST(fee AS TEXT) as fee, trade_date, transaction_id, notes
             FROM holding_transactions WHERE account_id = ? AND security_id = ? AND deleted_at IS NULL ORDER BY trade_date DESC"
        ).bind(account_id.to_string()).bind(security_id.to_string()).fetch_all(&self.pool).await?;
        rows.iter().map(|r| Self::row_to_ht(r)).collect()
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: zero errors

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/infrastructure/repositories/holding_repository.rs
git commit -m "feat: add SqliteHoldingRepository"
```

---

### Task 7: DTOs

**Files:**
- Create: `src-tauri/src/application/dtos/holding_dto.rs`
- Modify: `src-tauri/src/application/dtos/mod.rs`

- [ ] **Step 1: Create holding_dto.rs**

```rust
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoldingTransactionDto {
    pub id: Uuid,
    pub account_id: Uuid,
    pub security_id: Uuid,
    pub symbol: String,
    pub trade_type: String,
    pub quantity: Decimal,
    pub price: Decimal,
    pub amount: Decimal,
    pub fee: Decimal,
    pub trade_date: NaiveDate,
    pub transaction_id: Option<Uuid>,
    pub notes: Option<String>,
}
```

- [ ] **Step 2: Update mod.rs**

Add:
```rust
mod holding_dto;
pub use holding_dto::*;
```

- [ ] **Step 3: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: zero errors

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/application/dtos/holding_dto.rs src-tauri/src/application/dtos/mod.rs
git commit -m "feat: add holding DTOs"
```

---

### Task 8: HoldingService — BUY/SELL Logic

**Files:**
- Create: `src-tauri/src/application/services/holding_service.rs`

- [ ] **Step 1: Create holding_service.rs**

```rust
use crate::application::dtos::{
    CreateSecurityDto, HoldingDto, HoldingTradeDto, HoldingTransactionDto, SecurityDto,
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
        let total_money = Money::new(amount, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        let fee_money = Money::new(dto.fee, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        let total_with_fee = Money::new(amount + dto.fee, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;

        let entries = vec![
            TransactionEntry::new(dto.account_id, "1101", Some(total_money), None, &security.name)
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(dto.account_id, "5301", Some(fee_money), None, "Trade fee")
                .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?,
            TransactionEntry::new(dto.account_id, "1002", None, Some(total_with_fee), &format!("Buy {}", security.symbol))
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
        let mut holdings = self.holding_repo.find_by_account(dto.account_id).await?;
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

        let realized_pnl = holding.apply_sell(&ht);

        // Double-entry: Debit 1002 (bank) net_proceeds, Credit 1101 (asset) cost_basis, P&L to 4201/5101
        let net_proceeds = Money::new(amount - dto.fee, &account.currency_code)
            .map_err(|e| HoldingServiceError::ValidationError(e.to_string()))?;
        let cost_basis = Money::new(holding.avg_cost * dto.quantity, &account.currency_code)
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
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: zero errors

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/application/services/holding_service.rs
git commit -m "feat: add HoldingService with BUY/SELL + double-entry"
```

---

### Task 9: Tauri Commands + Registration

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/holding_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Create holding_commands.rs**

```rust
use crate::application::{
    dtos::{CreateSecurityDto, HoldingDto, HoldingTradeDto, SecurityDto},
    services::HoldingService,
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteHoldingRepository, SqliteSecurityRepository,
    SqliteTransactionRepository,
};
use rust_decimal::Decimal;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePool, SqlitePoolOptions};
use std::{str::FromStr, sync::Arc};
use tauri::State;
use uuid::Uuid;

pub struct HoldingAppState {
    pub pool: SqlitePool,
    holding_service: HoldingService,
}

impl HoldingAppState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let security_repo = Arc::new(SqliteSecurityRepository::new(pool.clone()));
        let holding_repo = Arc::new(SqliteHoldingRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        Self {
            holding_service: HoldingService::new(security_repo, holding_repo, account_repo, transaction_repo),
            pool,
        }
    }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<HoldingAppState> {
    Ok(HoldingAppState::from_pool(pool))
}

#[tauri::command]
pub async fn create_security(state: State<'_, HoldingAppState>, dto: CreateSecurityDto) -> Result<SecurityDto, String> {
    state.holding_service.create_security(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_securities(state: State<'_, HoldingAppState>) -> Result<Vec<SecurityDto>, String> {
    state.holding_service.list_securities().await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_security_price(state: State<'_, HoldingAppState>, id: Uuid, price: Decimal) -> Result<(), String> {
    state.holding_service.update_security_price(id, price).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn buy_holding(state: State<'_, HoldingAppState>, dto: HoldingTradeDto) -> Result<Uuid, String> {
    state.holding_service.buy(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn sell_holding(state: State<'_, HoldingAppState>, dto: HoldingTradeDto) -> Result<Uuid, String> {
    state.holding_service.sell(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_holdings(state: State<'_, HoldingAppState>) -> Result<Vec<HoldingDto>, String> {
    state.holding_service.list_holdings().await.map_err(|e| e.to_string())
}
```

- [ ] **Step 2: Update tauri_commands/mod.rs**

Add:
```rust
pub mod holding_commands;
pub use holding_commands::{
    buy_holding, create_security, list_holdings, list_securities, sell_holding,
    update_security_price, HoldingAppState,
};
```

- [ ] **Step 3: Update main.rs**

Add to imports:
```rust
holding_commands::{
    buy_holding, create_default_state_from_pool as create_holding_default_state,
    create_security, list_holdings, list_securities, sell_holding, update_security_price,
    HoldingAppState,
},
```

Add state creation (after `debt_state`):
```rust
let holding_state = create_holding_default_state(pool.clone()).await.expect("...");
```

Add `manage(holding_state)` to builder and register commands:
```rust
create_security, list_securities, update_security_price,
buy_holding, sell_holding, list_holdings,
```

- [ ] **Step 4: Verify compilation**

Run: `cargo check --lib 2>&1 | tail -5` from `src-tauri/`
Expected: zero errors

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/presentation/tauri_commands/holding_commands.rs \
        src-tauri/src/presentation/tauri_commands/mod.rs \
        src-tauri/src/main.rs
git commit -m "feat: add holding Tauri commands"
```

---

### Task 10: Frontend Types + API

**Files:**
- Create: `src/lib/tauri/holding.ts`

- [ ] **Step 1: Create holding.ts**

```typescript
import { invokeTauri } from '../tauri';

export type SecurityType = 'stock' | 'fund' | 'etf' | 'bond' | 'gold' | 'option' | 'other';

export interface CreateSecurityDto {
  symbol: string;
  name: string;
  security_type: SecurityType;
  exchange?: string | null;
  currency_code: string;
}

export interface SecurityDto {
  id: string;
  symbol: string;
  name: string;
  security_type: SecurityType;
  exchange?: string | null;
  currency_code: string;
  current_price?: number | null;
}

export interface HoldingTradeDto {
  account_id: string;
  security_id: string;
  direction: 'BUY' | 'SELL';
  quantity: number;
  price: number;
  fee: number;
  trade_date: string;
  notes?: string | null;
}

export interface HoldingDto {
  id: string;
  account_id: string;
  account_name: string;
  security_id: string;
  symbol: string;
  security_name: string;
  security_type: SecurityType;
  quantity: number;
  avg_cost: number;
  current_price?: number | null;
  market_value?: number | null;
  unrealized_pnl?: number | null;
  currency_code: string;
}

export const createSecurity = (dto: CreateSecurityDto) =>
  invokeTauri<SecurityDto>('create_security', { dto });

export const listSecurities = () =>
  invokeTauri<SecurityDto[]>('list_securities');

export const updateSecurityPrice = (id: string, price: number) =>
  invokeTauri<void>('update_security_price', { id, price });

export const buyHolding = (dto: HoldingTradeDto) =>
  invokeTauri<string>('buy_holding', { dto });

export const sellHolding = (dto: HoldingTradeDto) =>
  invokeTauri<string>('sell_holding', { dto });

export const listHoldings = () =>
  invokeTauri<HoldingDto[]>('list_holdings');
```

- [ ] **Step 2: Verify TypeScript**

Run: `npx tsc --noEmit --pretty 2>&1 | tail -3`
Expected: no new errors

- [ ] **Step 3: Commit**

```bash
git add src/lib/tauri/holding.ts
git commit -m "feat: add frontend holding API types and functions"
```

---

### Task 11: HoldingTradeForm + HoldingsPage + Dashboard

**Files:**
- Create: `src/components/HoldingTradeForm.tsx`
- Create: `src/pages/HoldingsPage.tsx`
- Modify: `src/pages/HomePage.tsx`
- Modify: `src/i18n/locales/en.json`, `zh.json`

- [ ] **Step 1: Create HoldingTradeForm**

A simple form following DebtForm pattern. Fields: account selector (Investment type), security selector, BUY/SELL toggle, quantity, price, fee, trade date.

- [ ] **Step 2: Create HoldingsPage**

Portfolio table grouped by security_type. Columns: symbol, name, quantity, avg_cost, current_price, market_value, unrealized_pnl, pnl_pct. BUY/SELL buttons per holding. Update price inline.

- [ ] **Step 3: Modify HomePage**

Add holdings summary cards in dashboard (after debt cards). Group by security_type with total market_value and unrealized_pnl.

- [ ] **Step 4: Add i18n keys**

Add all new translation keys to en.json and zh.json.

- [ ] **Step 5: Verify TypeScript + Rust**

Run: `npx tsc --noEmit --pretty` and `cargo check --lib`
Expected: zero errors

- [ ] **Step 6: Commit**

```bash
git add src/components/HoldingTradeForm.tsx src/pages/HoldingsPage.tsx \
        src/pages/HomePage.tsx src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add HoldingsPage, HoldingTradeForm, and dashboard summary"
```

---

### Self-Review

1. **Spec coverage:** All P0 requirements covered — DB schema, domain models, repositories, service with BUY/SELL, Tauri commands, frontend types, UI components, dashboard integration.

2. **Placeholder scan:** No TBD or TODO. All code blocks have complete implementations.

3. **Type consistency:** `SecurityType` enum matches across Rust and TypeScript. `HoldingTradeDto.direction` uses "BUY"/"SELL" consistently. IDs are Uuid in Rust, string in TypeScript.

4. **Task 11** contains the frontend UI code. Given the length, it references patterns from DebtForm/DebtsPage without full code. The form should follow the existing pattern.
