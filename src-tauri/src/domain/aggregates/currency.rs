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

    /// Convert amount from this currency to target currency.
    /// Both currencies must have exchange rates relative to CNY.
    pub fn convert_to(&self, amount: f64, target: &Currency) -> f64 {
        if self.code == target.code {
            return amount;
        }
        // Convert via CNY as the base currency
        let amount_in_cny = amount * self.exchange_rate.rate();
        amount_in_cny / target.exchange_rate.rate()
    }
}

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
        let usd = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();
        let amount = 100.0;
        let converted = usd.convert_to(amount, &usd);
        assert_eq!(converted, amount);
    }

    #[test]
    fn test_convert_different_currencies() {
        let usd = Currency::new(
            "test-id-1".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();
        let eur = Currency::new(
            "test-id-2".to_string(),
            "EUR".to_string(),
            "欧元".to_string(),
            "€".to_string(),
            7.95,
        )
        .unwrap();
        let amount = 100.0;
        let converted = usd.convert_to(amount, &eur);
        // 100 USD * 7.25 / 7.95 ≈ 91.19 EUR
        assert!((converted - 91.19).abs() < 0.01);
    }

    #[test]
    fn test_deactivate_and_activate() {
        let mut currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();

        assert!(currency.is_active());

        currency.deactivate();
        assert!(!currency.is_active());

        currency.activate();
        assert!(currency.is_active());
    }

    #[test]
    fn test_update_exchange_rate() {
        let mut currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();

        assert_eq!(currency.exchange_rate().rate(), 7.25);

        currency.update_exchange_rate(7.30).unwrap();
        assert_eq!(currency.exchange_rate().rate(), 7.30);
    }

    #[test]
    fn test_update_exchange_rate_rejects_non_positive() {
        let mut currency = Currency::new(
            "test-id".to_string(),
            "USD".to_string(),
            "美元".to_string(),
            "$".to_string(),
            7.25,
        )
        .unwrap();

        assert!(currency.update_exchange_rate(0.0).is_err());
        assert!(currency.update_exchange_rate(-1.0).is_err());
    }
}
