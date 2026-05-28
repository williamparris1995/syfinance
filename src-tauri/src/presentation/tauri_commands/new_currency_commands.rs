use tauri::State;
use crate::infrastructure::repositories::new_currency_repository::NewCurrencyRepository;
use crate::infrastructure::services::exchange_rate_service::ExchangeRateService;
use crate::domain::aggregates::currency::Currency;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct NewCurrencyDto {
    pub id: String,
    pub code: String,
    pub name: String,
    pub symbol: String,
    pub exchange_rate: f64,
    pub is_active: bool,
}

impl From<Currency> for NewCurrencyDto {
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
pub struct CreateNewCurrencyDto {
    pub code: String,
    pub name: String,
    pub symbol: String,
    pub exchange_rate: f64,
}

#[tauri::command]
pub async fn new_list_currencies(
    repo: State<'_, Box<dyn NewCurrencyRepository + Send + Sync>>,
) -> Result<Vec<NewCurrencyDto>, String> {
    let currencies = repo.find_all().await?;
    Ok(currencies.into_iter().map(NewCurrencyDto::from).collect())
}

#[tauri::command]
pub async fn new_get_currency(
    code: String,
    repo: State<'_, Box<dyn NewCurrencyRepository + Send + Sync>>,
) -> Result<Option<NewCurrencyDto>, String> {
    let currency = repo.find_by_code(&code).await?;
    Ok(currency.map(NewCurrencyDto::from))
}

#[tauri::command]
pub async fn new_create_currency(
    dto: CreateNewCurrencyDto,
    repo: State<'_, Box<dyn NewCurrencyRepository + Send + Sync>>,
) -> Result<NewCurrencyDto, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let currency = Currency::new(id, dto.code, dto.name, dto.symbol, dto.exchange_rate)?;
    repo.save(&currency).await?;
    Ok(NewCurrencyDto::from(currency))
}

#[tauri::command]
pub async fn new_update_exchange_rate(
    code: String,
    rate: f64,
    repo: State<'_, Box<dyn NewCurrencyRepository + Send + Sync>>,
) -> Result<(), String> {
    repo.update_exchange_rate(&code, rate).await
}

#[tauri::command]
pub async fn new_fetch_latest_rates(
    exchange_service: State<'_, Box<dyn ExchangeRateService + Send + Sync>>,
    repo: State<'_, Box<dyn NewCurrencyRepository + Send + Sync>>,
) -> Result<Vec<NewCurrencyDto>, String> {
    // Fetch latest exchange rates
    let response = exchange_service.fetch_rates("CNY").await?;

    // Update rates in the database
    for (code, rate) in response.rates {
        if let Err(e) = repo.update_exchange_rate(&code, rate).await {
            eprintln!("Failed to update rate for {}: {}", code, e);
        }
    }

    // Return updated currency list
    let currencies = repo.find_all().await?;
    Ok(currencies.into_iter().map(NewCurrencyDto::from).collect())
}

#[tauri::command]
pub async fn new_convert_currency(
    amount: f64,
    from_code: String,
    to_code: String,
    repo: State<'_, Box<dyn NewCurrencyRepository + Send + Sync>>,
) -> Result<f64, String> {
    let from_currency = repo.find_by_code(&from_code).await?
        .ok_or_else(|| format!("Currency not found: {}", from_code))?;
    let to_currency = repo.find_by_code(&to_code).await?
        .ok_or_else(|| format!("Currency not found: {}", to_code))?;

    Ok(from_currency.convert_to(amount, &to_currency))
}
