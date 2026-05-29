#![allow(dead_code)]

use rust_decimal::Decimal;
use std::{error::Error, fmt};

#[derive(Debug, Clone, PartialEq)]
pub struct Currency {
    pub id: String,
    pub code: String,
    pub name: String,
    pub symbol: String,
    pub exchange_rate: Decimal,
    pub is_active: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CurrencyValidationError {
    InvalidCode(String),
}

impl fmt::Display for CurrencyValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidCode(code) => write!(f, "invalid currency code: {code}"),
        }
    }
}

impl Error for CurrencyValidationError {}

impl Currency {
    pub fn new(
        id: impl Into<String>,
        code: impl Into<String>,
        name: impl Into<String>,
        symbol: impl Into<String>,
        exchange_rate: Decimal,
    ) -> Result<Self, CurrencyValidationError> {
        let code = code.into();

        if !is_valid_currency_code(&code) {
            return Err(CurrencyValidationError::InvalidCode(code));
        }

        Ok(Self {
            id: id.into(),
            code,
            name: name.into(),
            symbol: symbol.into(),
            exchange_rate,
            is_active: true,
        })
    }

    pub fn deactivate(&mut self) {
        self.is_active = false;
    }

    pub fn activate(&mut self) {
        self.is_active = true;
    }

    pub fn update_exchange_rate(&mut self, new_rate: Decimal) {
        self.exchange_rate = new_rate;
    }
}

fn is_valid_currency_code(code: &str) -> bool {
    code.len() == 3 && code.chars().all(|character| character.is_ascii_uppercase())
}

#[cfg(test)]
mod tests {
    use super::Currency;
    use rust_decimal::Decimal;

    #[test]
    fn accepts_valid_iso_4217_codes() {
        for code in ["CNY", "USD", "EUR"] {
            let currency = Currency::new("test-id", code, "Test", "$", Decimal::new(1, 0)).unwrap();

            assert_eq!(currency.code, code);
        }
    }

    #[test]
    fn rejects_invalid_iso_4217_codes() {
        for code in ["cn", "US", "123"] {
            assert!(Currency::new("test-id", code, "Test", "$", Decimal::new(1, 0)).is_err());
        }
    }

    #[test]
    fn test_currency_creation() {
        let currency = Currency::new("test-id", "USD", "美元", "$", Decimal::new(725, 2)).unwrap();
        assert_eq!(currency.id, "test-id");
        assert_eq!(currency.code, "USD");
        assert_eq!(currency.name, "美元");
        assert_eq!(currency.symbol, "$");
        assert!(currency.is_active);
    }

    #[test]
    fn test_deactivate_and_activate() {
        let mut currency =
            Currency::new("test-id", "USD", "美元", "$", Decimal::new(725, 2)).unwrap();
        assert!(currency.is_active);

        currency.deactivate();
        assert!(!currency.is_active);

        currency.activate();
        assert!(currency.is_active);
    }

    #[test]
    fn test_update_exchange_rate() {
        let mut currency =
            Currency::new("test-id", "USD", "美元", "$", Decimal::new(725, 2)).unwrap();
        assert_eq!(currency.exchange_rate, Decimal::new(725, 2));

        currency.update_exchange_rate(Decimal::new(730, 2));
        assert_eq!(currency.exchange_rate, Decimal::new(730, 2));
    }
}
