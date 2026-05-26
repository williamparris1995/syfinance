# Asset Holdings System — Design Spec

## Summary

Add a transaction-driven holdings/positions layer to Investment accounts, enabling tracking of individual securities (stocks, funds, bonds, gold, options, etc.) at atomic granularity. Each buy/sell generates a double-entry accounting transaction, keeping account balances and holding quantities consistent.

## Motivation

- Current `Investment` account type stores only a balance number — no visibility into what assets are held
- No way to answer "how much did my Tencent stock gain?"
- No portfolio-level view across asset classes
- Industry standard (Quicken, GNUCash, FINOS) is a two-level model: Account (container) → Holdings (positions)

## Design

### Data Model

```
accounts (1) ─── (N) holdings ─── (1) securities
                       │
                  holding_transactions (BUY/SELL/DIVIDEND/SPLIT)
                       │
                  transaction_id → transactions (double-entry)
```

**securities（品种主数据）** — reference data, shared across accounts

| Column | Type | Note |
|--------|------|------|
| id | TEXT PK | UUID |
| symbol | VARCHAR(50) | e.g. "00700.HK" |
| name | VARCHAR(100) | "腾讯控股" |
| type | VARCHAR(20) | stock/fund/etf/bond/gold/option/other |
| exchange | VARCHAR(30) | HKEX/SSE/SZSE |
| currency_code | VARCHAR(3) | FK to currencies |

**holdings（持仓聚合）** — derived from transactions, not directly editable

| Column | Type | Note |
|--------|------|------|
| id | TEXT PK | UUID |
| account_id | TEXT FK | → accounts(id) |
| security_id | TEXT FK | → securities(id) |
| quantity | DECIMAL(20,8) | Current position size |
| avg_cost | DECIMAL(20,4) | Weighted average cost basis |

UNIQUE(account_id, security_id) — one position per security per account.

**holding_transactions（交易记录）** — append-only ledger

| Column | Type | Note |
|--------|------|------|
| id | TEXT PK | UUID |
| account_id | TEXT FK | → accounts(id) |
| security_id | TEXT FK | → securities(id) |
| type | VARCHAR(10) | BUY/SELL/DIVIDEND/SPLIT |
| quantity | DECIMAL(20,8) | |
| price | DECIMAL(20,4) | |
| amount | DECIMAL(20,2) | quantity × price |
| fee | DECIMAL(20,2) | |
| trade_date | DATE | |
| transaction_id | TEXT FK | → transactions(id), links to double-entry |

### Computed Fields (not stored)

- `market_value = quantity × current_price`
- `unrealized_pnl = (current_price - avg_cost) × quantity`
- `pnl_pct = (current_price - avg_cost) / avg_cost × 100`

### Process: BUY

1. User fills HoldingTradeForm: select Investment account, select security, direction=BUY, quantity, price, fee, trade_date
2. System:
   a. Creates double-entry Transaction: Debit 1101 (financial asset) quantity×price, Debit 5301 (fee), Credit 1002 (bank)
   b. Creates holding_transaction record (type=BUY)
   c. Updates or creates holding: quantity += n, avg_cost = weighted_avg(old_cost, new_cost)
3. Dashboard reflects new holding in portfolio view

### Process: SELL

1. User fills form: direction=SELL, quantity ≤ holding.quantity, price, fee
2. System:
   a. Creates Transaction: Debit 1002 (bank) quantity×price - fee, Credit 1101 (financial asset) quantity×avg_cost, realized_pnl to 4201/5101
   b. Creates holding_transaction (type=SELL)
   c. Updates holding: quantity -= n. If quantity = 0, soft-delete holding.
3. Realized P&L = (sell_price - avg_cost) × quantity - fee

### Process: Current Price Update

1. User updates security's `current_price` (manually for P0)
2. All holdings of that security recalculate market_value and unrealized_pnl
3. Dashboard charts reflect new values

### Initial Seeding

P0 seeds common securities:
- 00700.HK 腾讯控股, 600519.SH 贵州茅台, 000001.SZ 平安银行
- 510050.SH 上证50ETF, 159915.SZ 创业板ETF
- AU9999 黄金现货

### Out of Scope (P1-P4)

- Auto market price API
- Dividend reinvestment
- Tax lot tracking (FIFO/LIFO)
- Multi-currency auto-conversion
- Options Greeks
- CSV import from brokers
