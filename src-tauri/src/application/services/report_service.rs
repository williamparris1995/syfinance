use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use std::sync::Arc;
use tracing::info;

pub struct ReportService {
    pool: Arc<SqlitePool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YoyMonthData {
    pub month: u32,
    pub year1_income: String,
    pub year1_expense: String,
    pub year2_income: String,
    pub year2_expense: String,
    pub income_change_pct: Option<f64>,
    pub expense_change_pct: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct YoyComparison {
    pub year1: u32,
    pub year2: u32,
    pub months: Vec<YoyMonthData>,
}

impl ReportService {
    pub fn new(pool: Arc<SqlitePool>) -> Self {
        Self { pool }
    }

    pub async fn get_yoy_comparison(
        &self,
        year1: u32,
        year2: u32,
    ) -> Result<YoyComparison, String> {
        info!(year1 = year1, year2 = year2, "Computing YoY comparison");

        let rows: Vec<(i32, i32, String, String)> = sqlx::query_as(
            "SELECT
                CAST(strftime('%Y', t.transaction_date) AS INTEGER) as yr,
                CAST(strftime('%m', t.transaction_date) AS INTEGER) as mo,
                CAST(COALESCE(SUM(CASE
                    WHEN e.credit_amount IS NOT NULL AND a.account_type = 'Income' THEN e.credit_amount
                    ELSE 0
                END), 0) AS TEXT) as income,
                CAST(COALESCE(SUM(CASE
                    WHEN e.debit_amount IS NOT NULL AND a.account_type = 'Expense' THEN e.debit_amount
                    ELSE 0
                END), 0) AS TEXT) as expense
            FROM transactions t
            JOIN transaction_entries e ON e.transaction_id = t.id AND e.deleted_at IS NULL
            JOIN accounts a ON e.account_id = a.id
            WHERE t.deleted_at IS NULL
              AND (CAST(strftime('%Y', t.transaction_date) AS INTEGER) = ?1 OR CAST(strftime('%Y', t.transaction_date) AS INTEGER) = ?2)
            GROUP BY yr, mo
            ORDER BY yr, mo",
        )
        .bind(year1 as i32)
        .bind(year2 as i32)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute YoY data: {}", e))?;

        let mut months = Vec::new();
        for mo in 1..=12u32 {
            let y1_row = rows
                .iter()
                .find(|(yr, m, _, _)| *yr == year1 as i32 && *m == mo as i32);
            let y2_row = rows
                .iter()
                .find(|(yr, m, _, _)| *yr == year2 as i32 && *m == mo as i32);

            let y1_income: f64 = y1_row
                .map(|(_, _, inc, _)| inc.parse().unwrap_or(0.0))
                .unwrap_or(0.0);
            let y1_expense: f64 = y1_row
                .map(|(_, _, _, exp)| exp.parse().unwrap_or(0.0))
                .unwrap_or(0.0);
            let y2_income: f64 = y2_row
                .map(|(_, _, inc, _)| inc.parse().unwrap_or(0.0))
                .unwrap_or(0.0);
            let y2_expense: f64 = y2_row
                .map(|(_, _, _, exp)| exp.parse().unwrap_or(0.0))
                .unwrap_or(0.0);

            let income_change = if y1_income > 0.0 {
                Some(((y2_income - y1_income) / y1_income) * 100.0)
            } else {
                None
            };
            let expense_change = if y1_expense > 0.0 {
                Some(((y2_expense - y1_expense) / y1_expense) * 100.0)
            } else {
                None
            };

            months.push(YoyMonthData {
                month: mo,
                year1_income: format!("{:.2}", y1_income),
                year1_expense: format!("{:.2}", y1_expense),
                year2_income: format!("{:.2}", y2_income),
                year2_expense: format!("{:.2}", y2_expense),
                income_change_pct: income_change,
                expense_change_pct: expense_change,
            });
        }

        Ok(YoyComparison {
            year1,
            year2,
            months,
        })
    }
}
