#![allow(dead_code)]

use rust_decimal::Decimal;
use std::{error::Error, fmt};

#[derive(Debug, Clone, PartialEq)]
pub struct Currency {
    pub code: String,
    pub symbol: String,
    pub exchange_rate: Decimal,
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
        code: impl Into<String>,
        symbol: impl Into<String>,
        exchange_rate: Decimal,
    ) -> Result<Self, CurrencyValidationError> {
        let code = code.into();

        if !is_valid_currency_code(&code) {
            return Err(CurrencyValidationError::InvalidCode(code));
        }

        Ok(Self {
            code,
            symbol: symbol.into(),
            exchange_rate,
        })
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
            let currency = Currency::new(code, "$", Decimal::new(1, 0)).unwrap();

            assert_eq!(currency.code, code);
        }
    }

    #[test]
    fn rejects_invalid_iso_4217_codes() {
        for code in ["cn", "US", "123"] {
            assert!(Currency::new(code, "$", Decimal::new(1, 0)).is_err());
        }
    }
}
