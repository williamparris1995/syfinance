# Phase 1: 多币种系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现多币种支持，包括实时汇率、多币种账户、自动转换和多币种报告

**Architecture:** 扩展现有货币系统，添加汇率数据源集成、货币转换服务和多币种报告功能。采用 Repository 模式管理货币数据，Service 模式处理转换逻辑。

**Tech Stack:** Rust (Tauri), SQLite, TypeScript (React), ExchangeRate-API

---

## 文件结构映射

### 新增文件
```
src-tauri/
├── src/
│   ├── domain/
│   │   ├── aggregates/
│   │   │   └── currency.rs           # 货币聚合根
│   │   └── value_objects/
│   │       ├── exchange_rate.rs      # 汇率值对象
│   │       └── money.rs              # 金额值对象（扩展）
│   ├── infrastructure/
│   │   ├── repositories/
│   │   │   └── currency_repository.rs # 货币仓库
│   │   └── services/
│   │       └── exchange_rate_service.rs # 汇率服务
│   └── presentation/
│       └── tauri_commands/
│           └── currency_commands.rs  # 货币命令
└── migrations/
    └── 20260527000001_create_currencies_table.sql

src/
├── lib/
│   ├── tauri/
│   │   └── currency.ts              # 货币 API 封装
│   └── currency.ts                  # 货币工具函数
├── hooks/
│   └── useCurrency.ts               # 多币种 Hook
└── components/
    └── CurrencyConverter.tsx         # 货币转换组件
```

### 修改文件
```
src-tauri/src/domain/aggregates/account.rs  # 添加货币字段
src-tauri/src/infrastructure/repositories/account_repository.rs  # 更新查询
src/lib/tauri/account.ts                    # 更新 API 类型
src/components/AccountForm.tsx              # 添加货币选择
src/pages/AccountsPage.tsx                  # 显示多币种余额
```

---

## Task 1: 扩展货币数据库表

**Files:**
- Create: `src-tauri/migrations/20260527000014_extend_currencies_table.sql`

- [ ] **Step 1: 创建扩展迁移文件**

```sql
-- src-tauri/migrations/20260527000014_extend_currencies_table.sql
-- 添加 name 列
ALTER TABLE currencies ADD COLUMN name VARCHAR(50) NOT NULL DEFAULT '';

-- 添加 is_active 列
ALTER TABLE currencies ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;

-- 添加 created_at 列
ALTER TABLE currencies ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- 添加 updated_at 列（重命名现有的 updated_at）
ALTER TABLE currencies RENAME COLUMN updated_at TO updated_at;

-- 更新现有货币的 name 字段
UPDATE currencies SET name = '人民币' WHERE code = 'CNY';
UPDATE currencies SET name = '美元' WHERE code = 'USD';
UPDATE currencies SET name = '欧元' WHERE code = 'EUR';

-- 插入新的默认货币
INSERT OR IGNORE INTO currencies (id, code, name, symbol, exchange_rate) VALUES
    (lower(hex(randomblob(16))), 'GBP', '英镑', '£', 9.20),
    (lower(hex(randomblob(16))), 'JPY', '日元', '¥', 0.048);
```

- [ ] **Step 2: 运行迁移**

Run: `cd src-tauri && cargo run --bin migrate`
Expected: 迁移成功，currencies 表已扩展

- [ ] **Step 3: 验证表结构**

Run: `sqlite3 src-tauri/target/debug/finance.db ".schema currencies"`
Expected: 显示扩展后的 currencies 表结构，包含 name, is_active, created_at, updated_at 列

- [ ] **Step 4: 提交**

```bash
git add src-tauri/migrations/20260527000014_extend_currencies_table.sql
git commit -m "feat: extend currencies table with name, is_active, and timestamps"
```

---

## Task 2: 创建货币领域模型

**Files:**
- Create: `src-tauri/src/domain/aggregates/currency.rs`
- Create: `src-tauri/src/domain/value_objects/exchange_rate.rs`

- [ ] **Step 1: 创建汇率值对象**

```rust
// src-tauri/src/domain/value_objects/exchange_rate.rs
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExchangeRate {
    rate: f64,
    updated_at: chrono::NaiveDateTime,
}

impl ExchangeRate {
    pub fn new(rate: f64, updated_at: chrono::NaiveDateTime) -> Result<Self, String> {
        if rate <= 0.0 {
            return Err("Exchange rate must be positive".to_string());
        }
        Ok(Self { rate, updated_at })
    }

    pub fn rate(&self) -> f64 {
        self.rate
    }

    pub fn updated_at(&self) -> &chrono::NaiveDateTime {
        &self.updated_at
    }

    pub fn is_stale(&self, max_age_hours: i64) -> bool {
        let now = chrono::Utc::now().naive_utc();
        let duration = now - self.updated_at;
        duration.num_hours() > max_age_hours
    }
}

impl fmt::Display for ExchangeRate {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.rate)
    }
}
```

- [ ] **Step 2: 创建货币聚合根**

```rust
// src-tauri/src/domain/aggregates/currency.rs
use serde::{Deserialize, Serialize};
use super::super::value_objects::exchange_rate::ExchangeRate;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Currency {
    id: String,
    code: String,
    name: String,
    symbol: String,
    exchange_rate: ExchangeRate,
    is_active: bool,
}

impl Currency {
    pub fn new(
        id: String,
        code: String,
        name: String,
        symbol: String,
        exchange_rate: f64,
    ) -> Result<Self, String> {
        if code.len() != 3 {
            return Err("Currency code must be 3 characters".to_string());
        }

        let rate = ExchangeRate::new(exchange_rate, chrono::Utc::now().naive_utc())?;

        Ok(Self {
            id,
            code: code.to_uppercase(),
            name,
            symbol,
            exchange_rate: rate,
            is_active: true,
        })
    }

    pub fn id(&self) -> &str {
        &self.id
    }

    pub fn code(&self) -> &str {
        &self.code
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn symbol(&self) -> &str {
        &self.symbol
    }

    pub fn exchange_rate(&self) -> &ExchangeRate {
        &self.exchange_rate
    }

    pub fn is_active(&self) -> bool {
        self.is_active
    }

    pub fn update_exchange_rate(&mut self, new_rate: f64) -> Result<(), String> {
        self.exchange_rate = ExchangeRate::new(new_rate, chrono::Utc::now().naive_utc())?;
        Ok(())
    }

    pub fn deactivate(&mut self) {
        self.is_active = false;
    }

    pub fn activate(&mut self) {
        self.is_active = true;
    }

    /// 转换金额到目标货币
    pub fn convert_to(&self, amount: f64, target: &Currency) -> f64 {
        if self.code == target.code {
            return amount;
        }
        // 先转换为 CNY，再转换为目标货币
        let amount_in_cny = amount * self.exchange_rate.rate();
        amount_in_cny / target.exchange_rate.rate()
    }
}
```

- [ ] **Step 3: 编写单元测试**

```rust
// src-tauri/src/domain/aggregates/currency.rs (在文件末尾添加)
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_currency_creation() {
        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        );
        assert!(currency.is_ok());
        let currency = currency.unwrap();
        assert_eq!(currency.id(), "test-id");
        assert_eq!(currency.code(), "USD");
        assert_eq!(currency.name(), "美元");
        assert_eq!(currency.symbol(), "$");
    }

    #[test]
    fn test_currency_code_must_be_3_chars() {
        let currency = Currency::new(
            "test-id".to_string(),
            "US".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        );
        assert!(currency.is_err());
    }

    #[test]
    fn test_exchange_rate_must_be_positive() {
        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            -1.0,
        );
        assert!(currency.is_err());
    }

    #[test]
    fn test_convert_same_currency() {
        let usd = Currency::new("test-id".to_string(), "USD".to_string(), "美元".to_string(), "$".to_string(), 7.25).unwrap();
        let amount = 100.0;
        let converted = usd.convert_to(amount, &usd);
        assert_eq!(converted, amount);
    }

    #[test]
    fn test_convert_different_currencies() {
        let usd = Currency::new("test-id-1".to_string(), "USD".to_string(), "美元".to_string(), "$".to_string(), 7.25).unwrap();
        let eur = Currency::new("test-id-2".to_string(), "EUR".to_string(), "欧元".to_string(), "€".to_string(), 7.95).unwrap();
        let amount = 100.0;
        let converted = usd.convert_to(amount, &eur);
        // 100 USD * 7.25 / 7.95 ≈ 91.19 EUR
        assert!((converted - 91.19).abs() < 0.01);
    }
}
```

- [ ] **Step 4: 运行测试**

Run: `cd src-tauri && cargo test domain::aggregates::currency`
Expected: 所有测试通过

- [ ] **Step 5: 提交**

```bash
git add src-tauri/src/domain/aggregates/currency.rs
git add src-tauri/src/domain/value_objects/exchange_rate.rs
git commit -m "feat: add currency domain model with exchange rate"
```

---

## Task 3: 创建货币仓库

**Files:**
- Create: `src-tauri/src/infrastructure/repositories/currency_repository.rs`

- [ ] **Step 1: 创建货币仓库接口**

```rust
// src-tauri/src/infrastructure/repositories/currency_repository.rs
use async_trait::async_trait;
use crate::domain::aggregates::currency::Currency;

#[async_trait]
pub trait CurrencyRepository {
    async fn find_all(&self) -> Result<Vec<Currency>, String>;
    async fn find_by_code(&self, code: &str) -> Result<Option<Currency>, String>;
    async fn find_active(&self) -> Result<Vec<Currency>, String>;
    async fn save(&self, currency: &Currency) -> Result<(), String>;
    async fn update_exchange_rate(&self, code: &str, rate: f64) -> Result<(), String>;
    async fn delete(&self, code: &str) -> Result<(), String>;
}
```

- [ ] **Step 2: 创建 SQLite 实现**

```rust
// src-tauri/src/infrastructure/repositories/currency_repository.rs (继续)
use sqlx::SqlitePool;
use chrono::NaiveDateTime;

pub struct SqliteCurrencyRepository {
    pool: SqlitePool,
}

impl SqliteCurrencyRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl CurrencyRepository for SqliteCurrencyRepository {
    async fn find_all(&self) -> Result<Vec<Currency>, String> {
        let rows = sqlx::query_as!(
            CurrencyRow,
            r#"
            SELECT id, code, name, symbol, exchange_rate, updated_at, is_active
            FROM currencies
            ORDER BY code
            "#
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch currencies: {}", e))?;

        let currencies = rows
            .into_iter()
            .map(|row| {
                Currency::new(row.id, row.code, row.name, row.symbol, row.exchange_rate)
                    .map_err(|e| format!("Invalid currency data: {}", e))
            })
            .collect::<Result<Vec<_>, _>>()?;

        Ok(currencies)
    }

    async fn find_by_code(&self, code: &str) -> Result<Option<Currency>, String> {
        let row = sqlx::query_as!(
            CurrencyRow,
            r#"
            SELECT id, code, name, symbol, exchange_rate, updated_at, is_active
            FROM currencies
            WHERE code = ?
            "#,
            code
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch currency: {}", e))?;

        match row {
            Some(row) => {
                let currency = Currency::new(row.id, row.code, row.name, row.symbol, row.exchange_rate)
                    .map_err(|e| format!("Invalid currency data: {}", e))?;
                Ok(Some(currency))
            }
            None => Ok(None),
        }
    }

    async fn find_active(&self) -> Result<Vec<Currency>, String> {
        let rows = sqlx::query_as!(
            CurrencyRow,
            r#"
            SELECT id, code, name, symbol, exchange_rate, updated_at, is_active
            FROM currencies
            WHERE is_active = TRUE
            ORDER BY code
            "#
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch active currencies: {}", e))?;

        let currencies = rows
            .into_iter()
            .map(|row| {
                Currency::new(row.id, row.code, row.name, row.symbol, row.exchange_rate)
                    .map_err(|e| format!("Invalid currency data: {}", e))
            })
            .collect::<Result<Vec<_>, _>>()?;

        Ok(currencies)
    }

    async fn save(&self, currency: &Currency) -> Result<(), String> {
        sqlx::query!(
            r#"
            INSERT INTO currencies (id, code, name, symbol, exchange_rate, updated_at, is_active)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (code) DO UPDATE SET
                name = excluded.name,
                symbol = excluded.symbol,
                exchange_rate = excluded.exchange_rate,
                updated_at = excluded.updated_at,
                is_active = excluded.is_active
            "#,
            currency.id(),
            currency.code(),
            currency.name(),
            currency.symbol(),
            currency.exchange_rate().rate(),
            currency.exchange_rate().updated_at(),
            currency.is_active()
        )
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to save currency: {}", e))?;

        Ok(())
    }

    async fn update_exchange_rate(&self, code: &str, rate: f64) -> Result<(), String> {
        let now = chrono::Utc::now().naive_utc();
        sqlx::query!(
            r#"
            UPDATE currencies
            SET exchange_rate = ?, updated_at = ?
            WHERE code = ?
            "#,
            rate,
            now,
            code
        )
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to update exchange rate: {}", e))?;

        Ok(())
    }

    async fn delete(&self, code: &str) -> Result<(), String> {
        sqlx::query!("DELETE FROM currencies WHERE code = ?", code)
            .execute(&self.pool)
            .await
            .map_err(|e| format!("Failed to delete currency: {}", e))?;

        Ok(())
    }
}

#[derive(sqlx::FromRow)]
struct CurrencyRow {
    id: String,
    code: String,
    name: String,
    symbol: String,
    exchange_rate: f64,
    updated_at: NaiveDateTime,
    is_active: bool,
}
```

- [ ] **Step 3: 编写集成测试**

```rust
// src-tauri/src/infrastructure/repositories/currency_repository.rs (在文件末尾添加)
#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn setup_test_db() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .connect(":memory:")
            .await
            .unwrap();

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS currencies (
                id TEXT PRIMARY KEY NOT NULL,
                code VARCHAR(3) NOT NULL UNIQUE,
                name VARCHAR(50) NOT NULL DEFAULT '',
                symbol VARCHAR(10) NOT NULL,
                exchange_rate DECIMAL(20,10) NOT NULL DEFAULT 1.0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CHECK (exchange_rate > 0)
            )
            "#
        )
        .execute(&pool)
        .await
        .unwrap();

        pool
    }

    #[tokio::test]
    async fn test_save_and_find_currency() {
        let pool = setup_test_db().await;
        let repo = SqliteCurrencyRepository::new(pool);

        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        ).unwrap();

        repo.save(&currency).await.unwrap();

        let found = repo.find_by_code("USD").await.unwrap();
        assert!(found.is_some());
        let found = found.unwrap();
        assert_eq!(found.id(), "test-id");
        assert_eq!(found.code(), "USD");
        assert_eq!(found.name(), "美元");
    }

    #[tokio::test]
    async fn test_update_exchange_rate() {
        let pool = setup_test_db().await;
        let repo = SqliteCurrencyRepository::new(pool);

        let currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        ).unwrap();

        repo.save(&currency).await.unwrap();

        repo.update_exchange_rate("USD", 7.30).await.unwrap();

        let found = repo.find_by_code("USD").await.unwrap().unwrap();
        assert!((found.exchange_rate().rate() - 7.30).abs() < 0.001);
    }
}
```

- [ ] **Step 4: 运行测试**

Run: `cd src-tauri && cargo test infrastructure::repositories::currency_repository`
Expected: 所有测试通过

- [ ] **Step 5: 提交**

```bash
git add src-tauri/src/infrastructure/repositories/currency_repository.rs
git commit -m "feat: add currency repository with SQLite implementation"
```

---

## Task 4: 创建汇率服务

**Files:**
- Create: `src-tauri/src/infrastructure/services/exchange_rate_service.rs`

- [ ] **Step 1: 创建汇率服务接口**

```rust
// src-tauri/src/infrastructure/services/exchange_rate_service.rs
use async_trait::async_trait;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct ExchangeRateResponse {
    pub rates: std::collections::HashMap<String, f64>,
    pub base: String,
    pub timestamp: i64,
}

#[async_trait]
pub trait ExchangeRateService {
    async fn fetch_rates(&self, base_currency: &str) -> Result<ExchangeRateResponse, String>;
    async fn fetch_rate(&self, from: &str, to: &str) -> Result<f64, String>;
}
```

- [ ] **Step 2: 创建 HTTP 实现**

```rust
// src-tauri/src/infrastructure/services/exchange_rate_service.rs (继续)
use reqwest::Client;

pub struct HttpExchangeRateService {
    client: Client,
    api_key: String,
    base_url: String,
}

impl HttpExchangeRateService {
    pub fn new(api_key: String) -> Self {
        Self {
            client: Client::new(),
            api_key,
            base_url: "https://v6.exchangerate-api.com/v6".to_string(),
        }
    }
}

#[async_trait]
impl ExchangeRateService for HttpExchangeRateService {
    async fn fetch_rates(&self, base_currency: &str) -> Result<ExchangeRateResponse, String> {
        let url = format!("{}/{}/latest/{}", self.base_url, self.api_key, base_currency);

        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to fetch exchange rates: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("API returned status: {}", response.status()));
        }

        let data: ExchangeRateResponse = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse response: {}", e))?;

        Ok(data)
    }

    async fn fetch_rate(&self, from: &str, to: &str) -> Result<f64, String> {
        let response = self.fetch_rates(from).await?;
        response.rates
            .get(to)
            .copied()
            .ok_or_else(|| format!("Rate not found for {} to {}", from, to))
    }
}
```

- [ ] **Step 3: 创建本地缓存包装器**

```rust
// src-tauri/src/infrastructure/services/exchange_rate_service.rs (继续)
use std::sync::Mutex;
use std::collections::HashMap;
use chrono::{DateTime, Utc};

pub struct CachedExchangeRateService {
    inner: Box<dyn ExchangeRateService + Send + Sync>,
    cache: Mutex<HashMap<String, (f64, DateTime<Utc>)>>,
    cache_duration_hours: i64,
}

impl CachedExchangeRateService {
    pub fn new(inner: Box<dyn ExchangeRateService + Send + Sync>, cache_duration_hours: i64) -> Self {
        Self {
            inner,
            cache: Mutex::new(HashMap::new()),
            cache_duration_hours,
        }
    }

    fn get_cache_key(&self, from: &str, to: &str) -> String {
        format!("{}_{}", from, to)
    }

    fn is_cache_valid(&self, cached_at: &DateTime<Utc>) -> bool {
        let now = Utc::now();
        let duration = now - *cached_at;
        duration.num_hours() < self.cache_duration_hours
    }
}

#[async_trait]
impl ExchangeRateService for CachedExchangeRateService {
    async fn fetch_rates(&self, base_currency: &str) -> Result<ExchangeRateResponse, String> {
        // 对于批量获取，直接委托给内部服务
        self.inner.fetch_rates(base_currency).await
    }

    async fn fetch_rate(&self, from: &str, to: &str) -> Result<f64, String> {
        let cache_key = self.get_cache_key(from, to);

        // 检查缓存
        {
            let cache = self.cache.lock().unwrap();
            if let Some((rate, cached_at)) = cache.get(&cache_key) {
                if self.is_cache_valid(cached_at) {
                    return Ok(*rate);
                }
            }
        }

        // 缓存未命中，获取新汇率
        let rate = self.inner.fetch_rate(from, to).await?;

        // 更新缓存
        {
            let mut cache = self.cache.lock().unwrap();
            cache.insert(cache_key, (rate, Utc::now()));
        }

        Ok(rate)
    }
}
```

- [ ] **Step 4: 编写测试**

```rust
// src-tauri/src/infrastructure/services/exchange_rate_service.rs (在文件末尾添加)
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::mock;

    mock! {
        ExchangeRateServiceImpl {}

        #[async_trait]
        impl ExchangeRateService for ExchangeRateServiceImpl {
            async fn fetch_rates(&self, base_currency: &str) -> Result<ExchangeRateResponse, String>;
            async fn fetch_rate(&self, from: &str, to: &str) -> Result<f64, String>;
        }
    }

    #[tokio::test]
    async fn test_cached_service_returns_cached_value() {
        let mut mock = MockExchangeRateServiceImpl::new();
        mock.expect_fetch_rate()
            .times(1)
            .returning(|_, _| Ok(7.25));

        let service = CachedExchangeRateService::new(Box::new(mock), 24);

        // 第一次调用
        let rate1 = service.fetch_rate("USD", "CNY").await.unwrap();
        assert_eq!(rate1, 7.25);

        // 第二次调用应该使用缓存
        let rate2 = service.fetch_rate("USD", "CNY").await.unwrap();
        assert_eq!(rate2, 7.25);
    }
}
```

- [ ] **Step 5: 运行测试**

Run: `cd src-tauri && cargo test infrastructure::services::exchange_rate_service`
Expected: 所有测试通过

- [ ] **Step 6: 提交**

```bash
git add src-tauri/src/infrastructure/services/exchange_rate_service.rs
git commit -m "feat: add exchange rate service with caching"
```

---

## Task 5: 创建 Tauri 命令

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/currency_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`

- [ ] **Step 1: 创建货币命令**

```rust
// src-tauri/src/presentation/tauri_commands/currency_commands.rs
use tauri::State;
use crate::infrastructure::repositories::currency_repository::CurrencyRepository;
use crate::infrastructure::services::exchange_rate_service::ExchangeRateService;
use crate::domain::aggregates::currency::Currency;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct CurrencyDto {
    pub id: String,
    pub code: String,
    pub name: String,
    pub symbol: String,
    pub exchange_rate: f64,
    pub is_active: bool,
}

impl From<Currency> for CurrencyDto {
    fn from(currency: Currency) -> Self {
        Self {
            id: currency.id().to_string(),
            code: currency.code().to_string(),
            name: currency.name().to_string(),
            symbol: currency.symbol().to_string(),
            exchange_rate: currency.exchange_rate().rate(),
            is_active: currency.is_active(),
        }
    }
}

#[derive(Deserialize)]
pub struct CreateCurrencyDto {
    pub code: String,
    pub name: String,
    pub symbol: String,
    pub exchange_rate: f64,
}

#[tauri::command]
pub async fn list_currencies(
    repo: State<'_, Box<dyn CurrencyRepository + Send + Sync>>,
) -> Result<Vec<CurrencyDto>, String> {
    let currencies = repo.find_all().await?;
    Ok(currencies.into_iter().map(CurrencyDto::from).collect())
}

#[tauri::command]
pub async fn get_currency(
    code: String,
    repo: State<'_, Box<dyn CurrencyRepository + Send + Sync>>,
) -> Result<Option<CurrencyDto>, String> {
    let currency = repo.find_by_code(&code).await?;
    Ok(currency.map(CurrencyDto::from))
}

#[tauri::command]
pub async fn create_currency(
    dto: CreateCurrencyDto,
    repo: State<'_, Box<dyn CurrencyRepository + Send + Sync>>,
) -> Result<CurrencyDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let currency = Currency::new(id, dto.code, dto.name, dto.symbol, dto.exchange_rate)?;
    repo.save(&currency).await?;
    Ok(CurrencyDto::from(currency))
}

#[tauri::command]
pub async fn update_exchange_rate(
    code: String,
    rate: f64,
    repo: State<'_, Box<dyn CurrencyRepository + Send + Sync>>,
) -> Result<(), String> {
    repo.update_exchange_rate(&code, rate).await
}

#[tauri::command]
pub async fn fetch_latest_rates(
    exchange_service: State<'_, Box<dyn ExchangeRateService + Send + Sync>>,
    repo: State<'_, Box<dyn CurrencyRepository + Send + Sync>>,
) -> Result<Vec<CurrencyDto>, String> {
    // 获取最新汇率
    let response = exchange_service.fetch_rates("CNY").await?;

    // 更新数据库中的汇率
    for (code, rate) in response.rates {
        if let Err(e) = repo.update_exchange_rate(&code, rate).await {
            eprintln!("Failed to update rate for {}: {}", code, e);
        }
    }

    // 返回更新后的货币列表
    let currencies = repo.find_all().await?;
    Ok(currencies.into_iter().map(CurrencyDto::from).collect())
}

#[tauri::command]
pub async fn convert_currency(
    amount: f64,
    from_code: String,
    to_code: String,
    repo: State<'_, Box<dyn CurrencyRepository + Send + Sync>>,
) -> Result<f64, String> {
    let from_currency = repo.find_by_code(&from_code).await?
        .ok_or_else(|| format!("Currency not found: {}", from_code))?;
    let to_currency = repo.find_by_code(&to_code).await?
        .ok_or_else(|| format!("Currency not found: {}", to_code))?;

    Ok(from_currency.convert_to(amount, &to_currency))
}
```

- [ ] **Step 2: 更新命令模块**

```rust
// src-tauri/src/presentation/tauri_commands/mod.rs
pub mod account_commands;
pub mod currency_commands;
pub mod debt_commands;
pub mod holding_commands;
pub mod prepaid_commands;
pub mod subscription_commands;
pub mod sync_commands;
pub mod transaction_commands;

// 在 main.rs 中注册命令
// .invoke_handler(tauri::generate_handler![
//     currency_commands::list_currencies,
//     currency_commands::get_currency,
//     currency_commands::create_currency,
//     currency_commands::update_exchange_rate,
//     currency_commands::fetch_latest_rates,
//     currency_commands::convert_currency,
//     // ... 其他命令
// ])
```

- [ ] **Step 3: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/currency_commands.rs
git add src-tauri/src/presentation/tauri_commands/mod.rs
git commit -m "feat: add currency Tauri commands"
```

---

## Task 6: 创建前端 API 封装

**Files:**
- Create: `src/lib/tauri/currency.ts`
- Create: `src/lib/currency.ts`

- [ ] **Step 1: 创建 Tauri API 封装**

```typescript
// src/lib/tauri/currency.ts
import { invoke } from '@tauri-apps/api/tauri';

export interface CurrencyDto {
  id: string;
  code: string;
  name: string;
  symbol: string;
  exchange_rate: number;
  is_active: boolean;
}

export interface CreateCurrencyDto {
  code: string;
  name: string;
  symbol: string;
  exchange_rate: number;
}

export async function listCurrencies(): Promise<CurrencyDto[]> {
  return invoke('list_currencies');
}

export async function getCurrency(code: string): Promise<CurrencyDto | null> {
  return invoke('get_currency', { code });
}

export async function createCurrency(dto: CreateCurrencyDto): Promise<CurrencyDto> {
  return invoke('create_currency', { dto });
}

export async function updateExchangeRate(code: string, rate: number): Promise<void> {
  return invoke('update_exchange_rate', { code, rate });
}

export async function fetchLatestRates(): Promise<CurrencyDto[]> {
  return invoke('fetch_latest_rates');
}

export async function convertCurrency(
  amount: number,
  fromCode: string,
  toCode: string
): Promise<number> {
  return invoke('convert_currency', { amount, fromCode, toCode });
}
```

- [ ] **Step 2: 创建货币工具函数**

```typescript
// src/lib/currency.ts
import { CurrencyDto } from './tauri/currency';

/**
 * 格式化货币金额
 */
export function formatCurrency(
  amount: number,
  currency: CurrencyDto,
  options?: Intl.NumberFormatOptions
): string {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: currency.code,
    currencyDisplay: 'narrowSymbol',
    ...options,
  }).format(amount);
}

/**
 * 获取货币符号
 */
export function getCurrencySymbol(code: string): string {
  const symbols: Record<string, string> = {
    CNY: '¥',
    USD: '$',
    EUR: '€',
    GBP: '£',
    JPY: '¥',
  };
  return symbols[code] || code;
}

/**
 * 计算多币种总资产
 */
export function calculateTotalBalanceInCNY(
  accounts: { balance: number; currency_code: string }[],
  currencies: CurrencyDto[]
): number {
  const cny = currencies.find(c => c.code === 'CNY');
  if (!cny) return 0;

  return accounts.reduce((total, account) => {
    const currency = currencies.find(c => c.code === account.currency_code);
    if (!currency) return total;

    // 转换为 CNY
    const balanceInCNY = account.balance * currency.exchange_rate / cny.exchange_rate;
    return total + balanceInCNY;
  }, 0);
}

/**
 * 转换金额
 */
export function convertAmount(
  amount: number,
  fromCurrency: CurrencyDto,
  toCurrency: CurrencyDto
): number {
  if (fromCurrency.code === toCurrency.code) return amount;
  return amount * fromCurrency.exchange_rate / toCurrency.exchange_rate;
}
```

- [ ] **Step 3: 创建多币种 Hook**

```typescript
// src/hooks/useCurrency.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listCurrencies,
  fetchLatestRates,
  convertCurrency,
  CurrencyDto,
} from '../lib/tauri/currency';
import { toast } from 'sonner';

export function useCurrencies() {
  return useQuery({
    queryKey: ['currencies'],
    queryFn: listCurrencies,
    staleTime: 1000 * 60 * 60, // 1 小时
  });
}

export function useFetchLatestRates() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: fetchLatestRates,
    onSuccess: (currencies) => {
      queryClient.setQueryData(['currencies'], currencies);
      toast.success('汇率已更新');
    },
    onError: (error) => {
      toast.error(`更新汇率失败: ${error}`);
    },
  });
}

export function useConvertCurrency() {
  return useMutation({
    mutationFn: ({
      amount,
      fromCode,
      toCode,
    }: {
      amount: number;
      fromCode: string;
      toCode: string;
    }) => convertCurrency(amount, fromCode, toCode),
  });
}
```

- [ ] **Step 4: 提交**

```bash
git add src/lib/tauri/currency.ts
git add src/lib/currency.ts
git add src/hooks/useCurrency.ts
git commit -m "feat: add currency frontend API and hooks"
```

---

## Task 7: 更新账户表单支持多币种

**Files:**
- Modify: `src/components/AccountForm.tsx`

- [ ] **Step 1: 添加货币选择到账户表单**

```typescript
// src/components/AccountForm.tsx
// 在表单中添加货币选择字段

import { useCurrencies } from '../hooks/useCurrency';

// 在组件内部
const { data: currencies = [] } = useCurrencies();

// 在表单中添加
<div className="space-y-2">
  <Label>{t('accountForm.currency')}</Label>
  <Select
    value={watch('currency_code')}
    onValueChange={(value) => setValue('currency_code', value)}
  >
    <SelectTrigger>
      <SelectValue placeholder={t('accountForm.selectCurrency')} />
    </SelectTrigger>
    <SelectContent>
      {currencies.map((currency) => (
        <SelectItem key={currency.code} value={currency.code}>
          {currency.symbol} {currency.name} ({currency.code})
        </SelectItem>
      ))}
    </SelectContent>
  </Select>
</div>
```

- [ ] **Step 2: 提交**

```bash
git add src/components/AccountForm.tsx
git commit -m "feat: add currency selector to account form"
```

---

## Task 8: 更新账户页面显示多币种余额

**Files:**
- Modify: `src/pages/AccountsPage.tsx`
- Modify: `src/pages/HomePage.tsx`

- [ ] **Step 1: 更新账户页面显示**

```typescript
// src/pages/AccountsPage.tsx
import { formatCurrency } from '../lib/currency';
import { useCurrencies } from '../hooks/useCurrency';

// 在组件内部
const { data: currencies = [] } = useCurrencies();

// 在表格中显示余额时
<TableCell className="text-right">
  {formatCurrency(
    Number(account.current_balance),
    currencies.find(c => c.code === account.currency_code) || {
      code: account.currency_code,
      symbol: account.currency_code,
    }
  )}
</TableCell>
```

- [ ] **Step 2: 更新首页显示总资产**

```typescript
// src/pages/HomePage.tsx
import { calculateTotalBalanceInCNY, formatCurrency } from '../lib/currency';
import { useCurrencies } from '../hooks/useCurrency';

// 在组件内部
const { data: currencies = [] } = useCurrencies();

// 计算总资产（转换为 CNY）
const totalBalance = calculateTotalBalanceInCNY(
  accounts.map(a => ({
    balance: Number(a.current_balance),
    currency_code: a.currency_code,
  })),
  currencies
);

// 显示总资产
<div className="text-2xl font-bold tracking-tight">
  {formatCurrency(totalBalance, { code: 'CNY', symbol: '¥', name: '人民币', exchange_rate: 1, is_active: true })}
</div>
```

- [ ] **Step 3: 提交**

```bash
git add src/pages/AccountsPage.tsx
git add src/pages/HomePage.tsx
git commit -m "feat: display multi-currency balances in accounts and home pages"
```

---

## Task 9: 创建货币设置页面

**Files:**
- Create: `src/pages/CurrencySettingsPage.tsx`
- Modify: `src/router.tsx`

- [ ] **Step 1: 创建货币设置页面**

```typescript
// src/pages/CurrencySettingsPage.tsx
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import {
  listCurrencies,
  createCurrency,
  updateExchangeRate,
  fetchLatestRates,
  CurrencyDto,
  CreateCurrencyDto,
} from '../lib/tauri/currency';
import { formatCurrency } from '../lib/currency';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { RefreshCw, Plus } from 'lucide-react';

export function CurrencySettingsPage() {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const [isAdding, setIsAdding] = useState(false);
  const [newCurrency, setNewCurrency] = useState<CreateCurrencyDto>({
    code: '',
    name: '',
    symbol: '',
    exchange_rate: 1.0,
  });

  const { data: currencies = [], isLoading } = useQuery({
    queryKey: ['currencies'],
    queryFn: listCurrencies,
  });

  const fetchRatesMutation = useMutation({
    mutationFn: fetchLatestRates,
    onSuccess: (data) => {
      queryClient.setQueryData(['currencies'], data);
      toast.success(t('settings.exchangeRateUpdated'));
    },
    onError: (error) => {
      toast.error(String(error));
    },
  });

  const addCurrencyMutation = useMutation({
    mutationFn: createCurrency,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      setIsAdding(false);
      setNewCurrency({ code: '', name: '', symbol: '', exchange_rate: 1.0 });
      toast.success(t('settings.currencyAdded'));
    },
    onError: (error) => {
      toast.error(String(error));
    },
  });

  const handleAddCurrency = () => {
    if (!newCurrency.code || !newCurrency.name || !newCurrency.symbol) {
      toast.error(t('settings.fillAllFields'));
      return;
    }
    addCurrencyMutation.mutate(newCurrency);
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('settings.currencySettings')}</h1>
        <div className="flex gap-2">
          <Button
            variant="outline"
            onClick={() => fetchRatesMutation.mutate()}
            disabled={fetchRatesMutation.isPending}
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${fetchRatesMutation.isPending ? 'animate-spin' : ''}`} />
            {t('settings.updateExchangeRate')}
          </Button>
          <Button onClick={() => setIsAdding(true)}>
            <Plus className="h-4 w-4 mr-2" />
            {t('settings.addCurrency')}
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t('settings.currencies')}</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">{t('common.loading')}</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('settings.code')}</TableHead>
                  <TableHead>{t('common.name')}</TableHead>
                  <TableHead>{t('settings.symbol')}</TableHead>
                  <TableHead className="text-right">{t('settings.exchangeRate')}</TableHead>
                  <TableHead>{t('settings.lastUpdated')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {currencies.map((currency) => (
                  <TableRow key={currency.id}>
                    <TableCell className="font-mono">{currency.code}</TableCell>
                    <TableCell>{currency.name}</TableCell>
                    <TableCell>{currency.symbol}</TableCell>
                    <TableCell className="text-right">
                      {currency.exchange_rate.toFixed(6)}
                    </TableCell>
                    <TableCell>
                      {new Date(currency.updated_at).toLocaleString()}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {isAdding && (
        <Card className="mt-6">
          <CardHeader>
            <CardTitle>{t('settings.addCurrency')}</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-4 gap-4">
              <div>
                <Label>{t('settings.code')}</Label>
                <Input
                  value={newCurrency.code}
                  onChange={(e) => setNewCurrency({ ...newCurrency, code: e.target.value.toUpperCase() })}
                  placeholder="USD"
                  maxLength={3}
                />
              </div>
              <div>
                <Label>{t('common.name')}</Label>
                <Input
                  value={newCurrency.name}
                  onChange={(e) => setNewCurrency({ ...newCurrency, name: e.target.value })}
                  placeholder={t('settings.currencyNamePlaceholder')}
                />
              </div>
              <div>
                <Label>{t('settings.symbol')}</Label>
                <Input
                  value={newCurrency.symbol}
                  onChange={(e) => setNewCurrency({ ...newCurrency, symbol: e.target.value })}
                  placeholder="$"
                />
              </div>
              <div>
                <Label>{t('settings.exchangeRate')}</Label>
                <Input
                  type="number"
                  value={newCurrency.exchange_rate}
                  onChange={(e) => setNewCurrency({ ...newCurrency, exchange_rate: parseFloat(e.target.value) || 1.0 })}
                  step="0.000001"
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 mt-4">
              <Button variant="outline" onClick={() => setIsAdding(false)}>
                {t('common.cancel')}
              </Button>
              <Button onClick={handleAddCurrency} disabled={addCurrencyMutation.isPending}>
                {addCurrencyMutation.isPending ? t('common.saving') : t('common.save')}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
```

- [ ] **Step 2: 添加路由**

```typescript
// src/router.tsx
import { CurrencySettingsPage } from './pages/CurrencySettingsPage';

// 添加路由
const currencySettingsRoute = createRoute({
  getParentRoute: () => settingsRoute,
  path: 'currency',
  component: CurrencySettingsPage,
});

// 在路由树中添加
const routeTree = rootRoute.addChildren([
  // ... 其他路由
  settingsRoute.addChildren([currencySettingsRoute]),
]);
```

- [ ] **Step 3: 提交**

```bash
git add src/pages/CurrencySettingsPage.tsx
git add src/router.tsx
git commit -m "feat: add currency settings page"
```

---

## Task 10: 添加国际化支持

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: 添加英文翻译**

```json
// src/i18n/locales/en.json
{
  "settings": {
    // ... existing translations
    "currencySettings": "Currency Settings",
    "currencies": "Currencies",
    "code": "Code",
    "symbol": "Symbol",
    "exchangeRate": "Exchange Rate (to CNY)",
    "lastUpdated": "Last Updated",
    "addCurrency": "Add Currency",
    "currencyNamePlaceholder": "e.g., US Dollar",
    "exchangeRateUpdated": "Exchange rates updated",
    "currencyAdded": "Currency added successfully",
    "fillAllFields": "Please fill all fields",
    "updateExchangeRate": "Update Exchange Rates"
  }
}
```

- [ ] **Step 2: 添加中文翻译**

```json
// src/i18n/locales/zh.json
{
  "settings": {
    // ... existing translations
    "currencySettings": "货币设置",
    "currencies": "货币列表",
    "code": "代码",
    "symbol": "符号",
    "exchangeRate": "汇率（相对人民币）",
    "lastUpdated": "最后更新",
    "addCurrency": "添加货币",
    "currencyNamePlaceholder": "例如：美元",
    "exchangeRateUpdated": "汇率已更新",
    "currencyAdded": "货币添加成功",
    "fillAllFields": "请填写所有字段",
    "updateExchangeRate": "更新汇率"
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add src/i18n/locales/en.json
git add src/i18n/locales/zh.json
git commit -m "feat: add currency i18n translations"
```

---

## Phase 1 完成检查清单

- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 货币表创建成功
- [ ] 可以添加/编辑/删除货币
- [ ] 可以更新汇率
- [ ] 账户表单支持选择货币
- [ ] 账户页面显示多币种余额
- [ ] 首页总资产正确计算
- [ ] 货币设置页面功能完整
- [ ] 国际化支持完整
- [ ] 代码已提交并推送

---

## 下一步

Phase 1 完成后，进入 [Phase 2: 预算管理](./2026-05-27-phase2-budget.md)
