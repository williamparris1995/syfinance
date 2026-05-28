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
