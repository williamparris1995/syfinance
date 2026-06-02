use crate::application::{
    dtos::{
        CreateSecurityDto, DividendDto, HoldingDto, HoldingTradeDto, HoldingTransactionDto,
        SecurityDto, SplitDto, UpdateHoldingTradeRequest,
    },
    services::HoldingService,
};
use crate::infrastructure::repositories::{
    SqliteAccountRepository, SqliteHoldingRepository, SqliteSecurityRepository,
    SqliteTransactionRepository,
};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;
use uuid::Uuid;

pub struct AppState {
    // TODO: will be used when holding commands need direct pool access
    #[allow(dead_code)]
    pub pool: SqlitePool,
    holding_service: HoldingService,
}

impl AppState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let security_repo = Arc::new(SqliteSecurityRepository::new(pool.clone()));
        let holding_repo = Arc::new(SqliteHoldingRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let transaction_repo = Arc::new(SqliteTransactionRepository::new(pool.clone()));
        Self {
            holding_service: HoldingService::new(
                security_repo,
                holding_repo,
                account_repo,
                transaction_repo,
            ),
            pool,
        }
    }

    pub fn service(&self) -> &HoldingService {
        &self.holding_service
    }
    // TODO: will be used when holding commands need direct pool access
    #[allow(dead_code)]
    pub fn pool(&self) -> &SqlitePool {
        &self.pool
    }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<AppState> {
    Ok(AppState::from_pool(pool))
}

#[tauri::command]
pub async fn create_security(
    state: State<'_, AppState>,
    dto: CreateSecurityDto,
) -> Result<SecurityDto, String> {
    state
        .service()
        .create_security(dto)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_securities(state: State<'_, AppState>) -> Result<Vec<SecurityDto>, String> {
    state
        .service()
        .list_securities()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_security_price(
    state: State<'_, AppState>,
    id: Uuid,
    price: Decimal,
) -> Result<(), String> {
    state
        .service()
        .update_security_price(id, price)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn buy_holding(state: State<'_, AppState>, dto: HoldingTradeDto) -> Result<Uuid, String> {
    state.service().buy(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn sell_holding(
    state: State<'_, AppState>,
    dto: HoldingTradeDto,
) -> Result<Uuid, String> {
    state.service().sell(dto).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_holdings(state: State<'_, AppState>) -> Result<Vec<HoldingDto>, String> {
    state
        .service()
        .list_holdings()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn list_holding_transactions(
    state: State<'_, AppState>,
    holding_id: Uuid,
) -> Result<Vec<HoldingTransactionDto>, String> {
    state
        .service()
        .list_holding_transactions(holding_id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn delete_holding_trade(
    state: State<'_, AppState>,
    holding_transaction_id: Uuid,
) -> Result<(), String> {
    state
        .service()
        .delete_holding_trade(holding_transaction_id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_holding_trade(
    state: State<'_, AppState>,
    request: UpdateHoldingTradeRequest,
) -> Result<(), String> {
    state
        .service()
        .update_holding_trade(request)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn record_dividend(
    state: State<'_, AppState>,
    dto: DividendDto,
) -> Result<String, String> {
    state
        .service()
        .record_dividend(dto)
        .await
        .map(|id| id.to_string())
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn record_split(
    state: State<'_, AppState>,
    dto: SplitDto,
) -> Result<(), String> {
    state
        .service()
        .record_split(dto)
        .await
        .map_err(|e| e.to_string())
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SearchResult {
    pub symbol: String,
    pub name: String,
    pub exchange: String,
    pub exchange_display: String,
    pub security_type: String,
}

#[tauri::command]
pub async fn search_securities(query: String) -> Result<Vec<SearchResult>, String> {
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0")
        .build()
        .map_err(|e| e.to_string())?;

    let url = format!(
        "https://query1.finance.yahoo.com/v1/finance/search?q={}&quotesCount=10&newsCount=0",
        urlencoding::encode(&query)
    );

    let resp = client.get(&url).send().await.map_err(|e| e.to_string())?;
    let body: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;

    let empty = vec![];
    let quotes = body["quotes"].as_array().unwrap_or(&empty);

    let results: Vec<SearchResult> = quotes
        .iter()
        .filter_map(|q| {
            let quote_type = q["quoteType"].as_str().unwrap_or("");
            let security_type = match quote_type {
                "EQUITY" => "stock",
                "ETF" => "etf",
                "MUTUALFUND" => "fund",
                "BOND" | "DEBT" => "bond",
                "OPTION" => "option",
                _ => "other",
            };

            let symbol = q["symbol"].as_str()?.to_string();
            let name = q["longname"]
                .as_str()
                .or_else(|| q["shortname"].as_str())?
                .to_string();
            let exchange = q["exchange"].as_str().unwrap_or("").to_string();
            let exchange_display = q["exchDisp"].as_str().unwrap_or(&exchange).to_string();

            Some(SearchResult {
                symbol,
                name,
                exchange,
                exchange_display,
                security_type: security_type.to_string(),
            })
        })
        .collect();

    Ok(results)
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PriceResult {
    pub symbol: String,
    pub price: f64,
}

#[tauri::command]
pub async fn fetch_security_price(
    symbol: String,
    exchange: Option<String>,
) -> Result<Option<PriceResult>, String> {
    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0")
        .build()
        .map_err(|e| e.to_string())?;

    // Use exchange suffix for more accurate lookup (e.g., 600519.SS for Shanghai)
    let yahoo_symbol = match exchange.as_deref() {
        Some("SHA" | "SHH") => format!("{}.SS", symbol),
        Some("SHE" | "SHZ") => format!("{}.SZ", symbol),
        Some("HKG") => format!("{}.HK", symbol),
        _ => symbol.clone(),
    };

    let url = format!(
        "https://query1.finance.yahoo.com/v8/finance/chart/{}?range=1d&interval=1d",
        urlencoding::encode(&yahoo_symbol)
    );

    let resp = client.get(&url).send().await.map_err(|e| e.to_string())?;
    let body: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;

    let result = body["chart"]["result"][0].as_object();
    match result {
        Some(chart) => {
            let meta = &chart["meta"];
            let price = meta["regularMarketPrice"].as_f64();
            match price {
                Some(p) => Ok(Some(PriceResult {
                    symbol: yahoo_symbol,
                    price: p,
                })),
                None => Ok(None),
            }
        }
        None => Ok(None),
    }
}
