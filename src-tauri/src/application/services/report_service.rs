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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceSheetItem {
    pub account_id: String,
    pub account_name: String,
    pub account_type: String,
    pub balance: String,
    pub currency_code: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceSheet {
    pub as_of_date: String,
    pub assets: Vec<BalanceSheetItem>,
    pub liabilities: Vec<BalanceSheetItem>,
    pub total_assets: String,
    pub total_liabilities: String,
    pub equity: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeStatementItem {
    pub account_id: String,
    pub account_name: String,
    pub amount: String,
    pub transaction_count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeStatement {
    pub start_date: String,
    pub end_date: String,
    pub income: Vec<IncomeStatementItem>,
    pub expenses: Vec<IncomeStatementItem>,
    pub total_income: String,
    pub total_expenses: String,
    pub net_income: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DashboardSummary {
    pub start_date: String,
    pub end_date: String,
    pub total_income: String,
    pub total_expenses: String,
    pub net_savings: String,
    pub income_by_category: Vec<IncomeStatementItem>,
    pub expense_by_category: Vec<IncomeStatementItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonthlyTrendItem {
    pub month: String,
    pub income: String,
    pub expenses: String,
    pub expense_categories: serde_json::Value,
    pub income_categories: serde_json::Value,
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
                    WHEN e.credit_amount IS NOT NULL AND a.account_type = 'income' THEN e.credit_amount
                    ELSE 0
                END), 0) AS TEXT) as income,
                CAST(COALESCE(SUM(CASE
                    WHEN e.debit_amount IS NOT NULL AND a.account_type = 'expense' THEN e.debit_amount
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

    pub async fn get_balance_sheet(
        &self,
        as_of_date: &str,
    ) -> Result<BalanceSheet, String> {
        info!(as_of_date = as_of_date, "Computing balance sheet");

        let rows: Vec<(String, String, String, String, String)> = sqlx::query_as(
            "SELECT
                a.id,
                a.name,
                a.account_type,
                a.currency_code,
                CAST(a.initial_balance + COALESCE(SUM(
                    CASE
                        WHEN e.debit_amount IS NOT NULL THEN e.debit_amount
                        WHEN e.credit_amount IS NOT NULL THEN -e.credit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as balance
            FROM accounts a
            LEFT JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
            LEFT JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                AND t.transaction_date <= ?1
            WHERE a.deleted_at IS NULL
            GROUP BY a.id
            ORDER BY a.name",
        )
        .bind(as_of_date)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute balance sheet: {}", e))?;

        let mut assets = Vec::new();
        let mut liabilities = Vec::new();
        let mut total_assets = rust_decimal::Decimal::ZERO;
        let mut total_liabilities = rust_decimal::Decimal::ZERO;

        for (id, name, account_type, currency, balance_str) in &rows {
            let balance: rust_decimal::Decimal = balance_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let is_asset = matches!(
                account_type.as_str(),
                "cash" | "bank" | "investment" | "prepaid"
            );
            let is_liability = matches!(
                account_type.as_str(),
                "creditcard" | "borrowedin"
            );

            if is_asset && balance > rust_decimal::Decimal::ZERO {
                total_assets += balance;
                assets.push(BalanceSheetItem {
                    account_id: id.clone(),
                    account_name: name.clone(),
                    account_type: account_type.clone(),
                    balance: balance.to_string(),
                    currency_code: currency.clone(),
                });
            } else if is_liability && balance < rust_decimal::Decimal::ZERO {
                let abs_balance = -balance;
                total_liabilities += abs_balance;
                liabilities.push(BalanceSheetItem {
                    account_id: id.clone(),
                    account_name: name.clone(),
                    account_type: account_type.clone(),
                    balance: abs_balance.to_string(),
                    currency_code: currency.clone(),
                });
            }
        }

        let equity = total_assets - total_liabilities;

        Ok(BalanceSheet {
            as_of_date: as_of_date.to_string(),
            assets,
            liabilities,
            total_assets: total_assets.to_string(),
            total_liabilities: total_liabilities.to_string(),
            equity: equity.to_string(),
        })
    }

    pub async fn get_income_statement(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> Result<IncomeStatement, String> {
        info!(start_date = start_date, end_date = end_date, "Computing income statement");

        let rows: Vec<(String, String, String, String, i64)> = sqlx::query_as(
            "SELECT
                a.id,
                a.name,
                a.account_type,
                CAST(COALESCE(SUM(
                    CASE
                        WHEN a.account_type = 'income' AND e.credit_amount IS NOT NULL THEN e.credit_amount
                        WHEN a.account_type = 'expense' AND e.debit_amount IS NOT NULL THEN e.debit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as amount,
                COUNT(DISTINCT e.transaction_id) as tx_count
            FROM accounts a
            JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
            JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                AND t.transaction_date >= ?1 AND t.transaction_date <= ?2
            WHERE a.deleted_at IS NULL
              AND a.account_type IN ('income', 'expense')
              AND a.ownership = 'external'
            GROUP BY a.id
            ORDER BY a.name",
        )
        .bind(start_date)
        .bind(end_date)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute income statement: {}", e))?;

        let mut income = Vec::new();
        let mut expenses = Vec::new();
        let mut total_income = rust_decimal::Decimal::ZERO;
        let mut total_expenses = rust_decimal::Decimal::ZERO;

        for (id, name, account_type, amount_str, tx_count) in &rows {
            let amount: rust_decimal::Decimal = amount_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let item = IncomeStatementItem {
                account_id: id.clone(),
                account_name: name.clone(),
                amount: amount.to_string(),
                transaction_count: *tx_count,
            };
            if account_type == "income" {
                total_income += amount;
                income.push(item);
            } else if account_type == "expense" {
                total_expenses += amount;
                expenses.push(item);
            }
        }

        let net_income = total_income - total_expenses;

        Ok(IncomeStatement {
            start_date: start_date.to_string(),
            end_date: end_date.to_string(),
            income,
            expenses,
            total_income: total_income.to_string(),
            total_expenses: total_expenses.to_string(),
            net_income: net_income.to_string(),
        })
    }

    pub async fn get_dashboard_summary(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> Result<DashboardSummary, String> {
        info!(start_date = start_date, end_date = end_date, "Computing dashboard summary");

        let rows: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT
                a.id,
                a.name,
                a.account_type,
                CAST(COALESCE(SUM(
                    CASE
                        WHEN a.account_type = 'income' AND e.credit_amount IS NOT NULL THEN e.credit_amount
                        WHEN a.account_type = 'expense' AND e.debit_amount IS NOT NULL THEN e.debit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as amount
            FROM accounts a
            JOIN transaction_entries e ON e.account_id = a.id AND e.deleted_at IS NULL
            JOIN transactions t ON t.id = e.transaction_id AND t.deleted_at IS NULL
                AND t.transaction_date >= ?1 AND t.transaction_date <= ?2
            WHERE a.deleted_at IS NULL
              AND a.account_type IN ('income', 'expense')
              AND a.ownership = 'external'
            GROUP BY a.id
            ORDER BY amount DESC",
        )
        .bind(start_date)
        .bind(end_date)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute dashboard summary: {}", e))?;

        let mut total_income = rust_decimal::Decimal::ZERO;
        let mut total_expenses = rust_decimal::Decimal::ZERO;
        let mut income_by_category = Vec::new();
        let mut expense_by_category = Vec::new();

        for (id, name, account_type, amount_str) in &rows {
            let amount: rust_decimal::Decimal = amount_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let item = IncomeStatementItem {
                account_id: id.clone(),
                account_name: name.clone(),
                amount: amount.to_string(),
                transaction_count: 0,
            };
            if account_type == "income" {
                total_income += amount;
                income_by_category.push(item);
            } else if account_type == "expense" {
                total_expenses += amount;
                expense_by_category.push(item);
            }
        }

        let net_savings = total_income - total_expenses;

        Ok(DashboardSummary {
            start_date: start_date.to_string(),
            end_date: end_date.to_string(),
            total_income: total_income.to_string(),
            total_expenses: total_expenses.to_string(),
            net_savings: net_savings.to_string(),
            income_by_category,
            expense_by_category,
        })
    }

    pub async fn get_monthly_trend(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> Result<Vec<MonthlyTrendItem>, String> {
        info!(start_date = start_date, end_date = end_date, "Computing monthly trend");

        let rows: Vec<(String, String, String, String)> = sqlx::query_as(
            "SELECT
                strftime('%Y-%m', t.transaction_date) as month,
                a.name as account_name,
                a.account_type,
                CAST(COALESCE(SUM(
                    CASE
                        WHEN a.account_type = 'expense' AND e.debit_amount IS NOT NULL THEN e.debit_amount
                        WHEN a.account_type = 'income' AND e.credit_amount IS NOT NULL THEN e.credit_amount
                        ELSE 0
                    END
                ), 0) AS TEXT) as amount
            FROM transactions t
            JOIN transaction_entries e ON e.transaction_id = t.id AND e.deleted_at IS NULL
            JOIN accounts a ON e.account_id = a.id
            WHERE t.deleted_at IS NULL
              AND t.transaction_date >= ?1 AND t.transaction_date <= ?2
              AND a.deleted_at IS NULL AND a.ownership = 'external'
              AND a.account_type IN ('income', 'expense')
            GROUP BY month, a.id
            ORDER BY month, a.name",
        )
        .bind(start_date)
        .bind(end_date)
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| format!("Failed to compute monthly trend: {}", e))?;

        // Pivot into per-month structure
        let mut month_map: std::collections::BTreeMap<String, (rust_decimal::Decimal, rust_decimal::Decimal, serde_json::Map<String, serde_json::Value>, serde_json::Map<String, serde_json::Value>)> = std::collections::BTreeMap::new();

        for (month, account_name, account_type, amount_str) in &rows {
            let amount: rust_decimal::Decimal = amount_str.parse().unwrap_or(rust_decimal::Decimal::ZERO);
            let entry = month_map.entry(month.clone()).or_insert((
                rust_decimal::Decimal::ZERO,
                rust_decimal::Decimal::ZERO,
                serde_json::Map::new(),
                serde_json::Map::new(),
            ));

            if account_type == "income" {
                entry.0 += amount;
                entry.3.insert(account_name.clone(), serde_json::Value::String(amount.to_string()));
            } else if account_type == "expense" {
                entry.1 += amount;
                entry.2.insert(account_name.clone(), serde_json::Value::String(amount.to_string()));
            }
        }

        let result: Vec<MonthlyTrendItem> = month_map
            .into_iter()
            .map(|(month, (income, expenses, exp_cats, inc_cats))| MonthlyTrendItem {
                month,
                income: income.to_string(),
                expenses: expenses.to_string(),
                expense_categories: serde_json::Value::Object(exp_cats),
                income_categories: serde_json::Value::Object(inc_cats),
            })
            .collect();

        Ok(result)
    }
}
