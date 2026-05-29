#![allow(dead_code)]

use rust_decimal::Decimal;
use std::{error::Error, fmt};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Money {
    pub amount: Decimal,
    pub currency_code: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MoneyValidationError {
    InvalidCurrencyCode(String),
    CurrencyMismatch { left: String, right: String },
}

impl fmt::Display for MoneyValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidCurrencyCode(code) => write!(f, "invalid currency code: {code}"),
            Self::CurrencyMismatch { left, right } => {
                write!(f, "currency mismatch: {left} != {right}")
            }
        }
    }
}

impl Error for MoneyValidationError {}

impl Money {
    pub fn new(
        amount: Decimal,
        currency_code: impl Into<String>,
    ) -> Result<Self, MoneyValidationError> {
        let currency_code = currency_code.into();

        if !is_valid_currency_code(&currency_code) {
            return Err(MoneyValidationError::InvalidCurrencyCode(currency_code));
        }

        Ok(Self {
            amount,
            currency_code,
        })
    }

    pub fn add(&self, other: &Self) -> Result<Self, MoneyValidationError> {
        self.ensure_same_currency(other)?;

        Self::new(self.amount + other.amount, self.currency_code.clone())
    }

    pub fn subtract(&self, other: &Self) -> Result<Self, MoneyValidationError> {
        self.ensure_same_currency(other)?;

        Self::new(self.amount - other.amount, self.currency_code.clone())
    }

    pub fn convert_to(
        &self,
        target_currency: impl Into<String>,
        exchange_rate: Decimal,
    ) -> Result<Self, MoneyValidationError> {
        let target_currency = target_currency.into();

        if !is_valid_currency_code(&target_currency) {
            return Err(MoneyValidationError::InvalidCurrencyCode(target_currency));
        }

        Self::new(self.amount * exchange_rate, target_currency)
    }

    pub fn eq(&self, other: &Self) -> Result<bool, MoneyValidationError> {
        self.ensure_same_currency(other)?;
        Ok(self.amount == other.amount)
    }

    pub fn gt(&self, other: &Self) -> Result<bool, MoneyValidationError> {
        self.ensure_same_currency(other)?;
        Ok(self.amount > other.amount)
    }

    pub fn lt(&self, other: &Self) -> Result<bool, MoneyValidationError> {
        self.ensure_same_currency(other)?;
        Ok(self.amount < other.amount)
    }

    fn ensure_same_currency(&self, other: &Self) -> Result<(), MoneyValidationError> {
        if self.currency_code == other.currency_code {
            Ok(())
        } else {
            Err(MoneyValidationError::CurrencyMismatch {
                left: self.currency_code.clone(),
                right: other.currency_code.clone(),
            })
        }
    }
}

impl fmt::Display for Money {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let symbol = currency_symbol(&self.currency_code);
        let formatted = format_amount(self.amount.round_dp(2));
        write!(f, "{symbol}{formatted}")
    }
}

fn is_valid_currency_code(code: &str) -> bool {
    code.len() == 3 && code.chars().all(|character| character.is_ascii_uppercase())
}

fn currency_symbol(code: &str) -> &'static str {
    match code {
        "CNY" => "¥",
        "JPY" => "¥",
        "USD" => "$",
        "EUR" => "€",
        "GBP" => "£",
        _ => "",
    }
}

fn format_amount(amount: Decimal) -> String {
    let fixed = format!("{amount:.2}");
    let (sign, body) = if let Some(stripped) = fixed.strip_prefix('-') {
        ("-", stripped)
    } else {
        ("", fixed.as_str())
    };

    let mut parts = body.split('.');
    let integer = parts.next().unwrap_or_default();
    let fraction = parts.next().unwrap_or("00");

    format!("{sign}{}.{}", add_thousands_separators(integer), fraction)
}

fn add_thousands_separators(integer: &str) -> String {
    let mut grouped = String::new();

    for (index, character) in integer.chars().rev().enumerate() {
        if index != 0 && index % 3 == 0 {
            grouped.push(',');
        }
        grouped.push(character);
    }

    grouped.chars().rev().collect()
}

#[cfg(test)]
mod tests {
    use super::{Money, MoneyValidationError};
    use proptest::prelude::*;
    use rust_decimal::Decimal;

    fn money(amount_cents: i64, currency: &str) -> Money {
        Money::new(Decimal::new(amount_cents, 2), currency).unwrap()
    }

    fn money_strategy(currency: &'static str) -> impl Strategy<Value = Money> {
        (-100_0000i64..=100_0000i64).prop_map(move |cents| money(cents, currency))
    }

    mod money {
        use super::*;

        mod arithmetic {
            use super::*;

            #[test]
            fn creates_valid_money() {
                let money = Money::new(Decimal::new(123456, 2), "CNY").unwrap();

                assert_eq!(money.amount, Decimal::new(123456, 2));
                assert_eq!(money.currency_code, "CNY");
            }

            #[test]
            fn accepts_high_precision_amount() {
                let money = Money::new(Decimal::new(12345, 3), "CNY").unwrap();

                assert_eq!(money.amount, Decimal::new(12345, 3));
            }

            #[test]
            fn rejects_invalid_currency_code() {
                let error = Money::new(Decimal::new(100, 2), "cn").unwrap_err();

                assert!(matches!(
                    error,
                    MoneyValidationError::InvalidCurrencyCode(_)
                ));
            }

            #[test]
            fn adds_and_subtracts_same_currency() {
                let left = money(123_456, "CNY");
                let right = money(10_044, "CNY");

                let sum = left.add(&right).unwrap();
                let difference = left.subtract(&right).unwrap();

                assert_eq!(sum.amount, Decimal::new(133_500, 2));
                assert_eq!(difference.amount, Decimal::new(113_412, 2));
            }

            #[test]
            fn rejects_cross_currency_arithmetic() {
                let left = money(1_000, "CNY");
                let right = money(1_000, "USD");

                assert!(matches!(
                    left.add(&right),
                    Err(MoneyValidationError::CurrencyMismatch { .. })
                ));
                assert!(matches!(
                    left.subtract(&right),
                    Err(MoneyValidationError::CurrencyMismatch { .. })
                ));
            }

            #[test]
            fn converts_currency_with_exchange_rate() {
                let money = money(100_000, "USD");

                let converted = money.convert_to("CNY", Decimal::new(725, 2)).unwrap();

                assert_eq!(converted.currency_code, "CNY");
                assert_eq!(converted.amount, Decimal::new(725_000, 2));
            }

            #[test]
            fn displays_with_currency_symbol_and_grouping() {
                let money = money(123_456, "CNY");

                assert_eq!(money.to_string(), "¥1,234.56");
            }

            #[test]
            fn compares_same_currency() {
                let left = money(500, "CNY");
                let right = money(700, "CNY");

                assert!(!left.eq(&right).unwrap());
                assert!(left.lt(&right).unwrap());
                assert!(right.gt(&left).unwrap());
            }

            #[test]
            fn rejects_cross_currency_comparison() {
                let left = money(500, "CNY");
                let right = money(700, "USD");

                assert!(matches!(
                    left.eq(&right),
                    Err(MoneyValidationError::CurrencyMismatch { .. })
                ));
                assert!(matches!(
                    left.gt(&right),
                    Err(MoneyValidationError::CurrencyMismatch { .. })
                ));
                assert!(matches!(
                    left.lt(&right),
                    Err(MoneyValidationError::CurrencyMismatch { .. })
                ));
            }
        }

        mod properties {
            use super::*;

            proptest! {
                #[test]
                fn addition_is_commutative(a in money_strategy("CNY"), b in money_strategy("CNY")) {
                    prop_assert_eq!(a.add(&b).unwrap(), b.add(&a).unwrap());
                }

                #[test]
                fn addition_is_associative(a in money_strategy("CNY"), b in money_strategy("CNY"), c in money_strategy("CNY")) {
                    let left = a.add(&b).unwrap().add(&c).unwrap();
                    let right = a.add(&b.add(&c).unwrap()).unwrap();

                    prop_assert_eq!(left, right);
                }
            }
        }
    }
}
