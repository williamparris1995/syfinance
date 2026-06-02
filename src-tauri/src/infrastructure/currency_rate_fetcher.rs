use rust_decimal::Decimal;
use sqlx::SqlitePool;
use std::collections::HashMap;
use tracing::info;

pub struct CurrencyRateFetcher;

impl CurrencyRateFetcher {
    /// Fetch latest exchange rates from a free API.
    /// The API returns USD-based rates. We convert to CNY-based for our system
    /// where exchange_rate = "how much CNY equals 1 unit of this currency".
    /// Free API, no key required.
    pub async fn fetch_rates() -> Result<HashMap<String, Decimal>, String> {
        let client = reqwest::Client::new();
        let response = client
            .get("https://api.exchangerate-api.com/v4/latest/USD")
            .send()
            .await
            .map_err(|e| format!("Failed to fetch rates: {}", e))?;

        let body: serde_json::Value = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse rates response: {}", e))?;

        let rates = body
            .get("rates")
            .and_then(|r| r.as_object())
            .ok_or("No rates found in response")?;

        let mut result = HashMap::new();

        // Get USD to CNY rate as our base conversion factor
        let usd_to_cny = rates
            .get("CNY")
            .and_then(|v| v.as_f64())
            .ok_or("CNY rate not found")?;

        // Convert all rates to CNY-based: rate_in_cny = usd_to_cny / usd_to_target
        for (code, value) in rates {
            if let Some(rate) = value.as_f64() {
                if rate > 0.0 {
                    // Convert from USD-based to CNY-based
                    let rate_in_cny = usd_to_cny / rate;
                    if let Ok(decimal) = Decimal::try_from(rate_in_cny) {
                        result.insert(code.to_string(), decimal);
                    }
                }
            }
        }

        // Add CNY itself as 1.0
        result.insert("CNY".to_string(), Decimal::ONE);

        info!(currencies_fetched = result.len(), "Fetched exchange rates");
        Ok(result)
    }

    /// Update exchange rates in the database for currencies that exist
    pub async fn update_rates_in_db(
        pool: &SqlitePool,
        rates: &HashMap<String, Decimal>,
    ) -> Result<usize, String> {
        let mut updated = 0;

        for (code, rate) in rates {
            let result = sqlx::query(
                "UPDATE currencies SET exchange_rate = ?, updated_at = datetime('now') WHERE code = ?"
            )
            .bind(rate.to_string())
            .bind(code)
            .execute(pool)
            .await
            .map_err(|e| format!("Failed to update rate for {}: {}", code, e))?;

            if result.rows_affected() > 0 {
                updated += 1;
                info!(currency = %code, rate = %rate, "Updated exchange rate");
            }
        }

        info!(updated_count = updated, "Exchange rate update complete");
        Ok(updated)
    }
}
