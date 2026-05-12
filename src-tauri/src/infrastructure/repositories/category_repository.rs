use crate::domain::{
    aggregates::{Category, CategoryType},
    repositories::CategoryRepository,
    value_objects::SyncMetadata,
};
use chrono::{DateTime, Utc};
use sqlx::{sqlite::SqlitePool, Row};
use std::str::FromStr;
use uuid::Uuid;

#[derive(Clone)]
pub struct SqliteCategoryRepository {
    pool: SqlitePool,
}

impl SqliteCategoryRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_category(row: &sqlx::sqlite::SqliteRow) -> Result<Category, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let name: String = row.try_get("name")?;
        let icon: String = row.try_get("icon")?;
        let color: String = row.try_get("color")?;

        let category_type_str: String = row.try_get("category_type")?;
        let category_type = match category_type_str.as_str() {
            "income" => CategoryType::Income,
            "expense" => CategoryType::Expense,
            _ => {
                return Err(sqlx::Error::Decode(
                    format!("Invalid category type: {}", category_type_str).into(),
                ))
            }
        };

        let chart_code: String = row.try_get("chart_code")?;
        let parent_id: Option<String> = row.try_get("parent_id")?;

        let updated_at: String = row.try_get("updated_at")?;
        let deleted_at: Option<String> = row.try_get("deleted_at")?;
        let device_id: Option<String> = row.try_get("device_id")?;
        let synced_at: Option<String> = row.try_get("synced_at")?;

        let parse_sqlite_datetime = |s: &str| -> Result<DateTime<Utc>, chrono::ParseError> {
            if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
                return Ok(dt.with_timezone(&Utc));
            }
            chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S")
                .map(|ndt| DateTime::<Utc>::from_naive_utc_and_offset(ndt, Utc))
        };

        let updated_at_parsed =
            parse_sqlite_datetime(&updated_at).map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let deleted_at_parsed = deleted_at
            .map(|s| parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let device_id_parsed = device_id
            .map(|s| Uuid::from_str(&s).map_err(|e| sqlx::Error::Decode(Box::new(e))))
            .transpose()?;

        let synced_at_parsed = synced_at
            .map(|s| parse_sqlite_datetime(&s))
            .transpose()
            .map_err(|e| sqlx::Error::Decode(Box::new(e)))?;

        let sync_metadata = SyncMetadata {
            updated_at: updated_at_parsed,
            deleted_at: deleted_at_parsed,
            device_id: device_id_parsed.unwrap_or_else(Uuid::new_v4),
            synced_at: synced_at_parsed,
        };

        Ok(Category {
            id,
            name,
            icon,
            color,
            category_type,
            chart_code,
            parent_id,
            sync_metadata,
            pending_events: Vec::new(),
        })
    }
}

impl CategoryRepository for SqliteCategoryRepository {
    async fn create(&self, category: &Category) -> sqlx::Result<()> {
        sqlx::query(
            r#"
            INSERT INTO categories (
                id, name, icon, color, category_type, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&category.id)
        .bind(&category.name)
        .bind(&category.icon)
        .bind(&category.color)
        .bind(category.category_type.to_string())
        .bind(&category.chart_code)
        .bind(category.parent_id.as_ref())
        .bind(category.sync_metadata.updated_at.to_rfc3339())
        .bind(category.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
        .bind(category.sync_metadata.device_id.to_string())
        .bind(category.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn update(&self, category: &Category) -> sqlx::Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE categories
            SET 
                name = ?,
                icon = ?,
                color = ?,
                parent_id = ?,
                updated_at = ?,
                deleted_at = ?,
                device_id = ?,
                synced_at = ?
            WHERE id = ?
            "#,
        )
        .bind(&category.name)
        .bind(&category.icon)
        .bind(&category.color)
        .bind(category.parent_id.as_ref())
        .bind(category.sync_metadata.updated_at.to_rfc3339())
        .bind(category.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()))
        .bind(category.sync_metadata.device_id.to_string())
        .bind(category.sync_metadata.synced_at.map(|dt| dt.to_rfc3339()))
        .bind(&category.id)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Category>> {
        let row = sqlx::query(
            r#"
            SELECT
                id, name, icon, color, category_type, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            FROM categories
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        row.map(|row| Self::row_to_category(&row)).transpose()
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Category>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, name, icon, color, category_type, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            FROM categories
            WHERE deleted_at IS NULL
            ORDER BY name ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_category).collect()
    }

    async fn find_by_type(&self, category_type: CategoryType) -> sqlx::Result<Vec<Category>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, name, icon, color, category_type, chart_code, parent_id,
                updated_at, deleted_at, device_id, synced_at
            FROM categories
            WHERE category_type = ? AND deleted_at IS NULL
            ORDER BY name ASC
            "#,
        )
        .bind(category_type.to_string())
        .fetch_all(&self.pool)
        .await?;

        rows.iter().map(Self::row_to_category).collect()
    }

    async fn find_by_parent(&self, parent_id: Option<&str>) -> sqlx::Result<Vec<Category>> {
        let rows = match parent_id {
            Some(pid) => {
                sqlx::query(
                    r#"
                    SELECT
                        id, name, icon, color, category_type, chart_code, parent_id,
                        updated_at, deleted_at, device_id, synced_at
                    FROM categories
                    WHERE parent_id = ? AND deleted_at IS NULL
                    ORDER BY name ASC
                    "#,
                )
                .bind(pid)
                .fetch_all(&self.pool)
                .await?
            }
            None => {
                sqlx::query(
                    r#"
                    SELECT
                        id, name, icon, color, category_type, chart_code, parent_id,
                        updated_at, deleted_at, device_id, synced_at
                    FROM categories
                    WHERE parent_id IS NULL AND deleted_at IS NULL
                    ORDER BY name ASC
                    "#,
                )
                .fetch_all(&self.pool)
                .await?
            }
        };

        rows.iter().map(Self::row_to_category).collect()
    }

    async fn soft_delete(&self, id: &str) -> sqlx::Result<bool> {
        let now = Utc::now().to_rfc3339();
        let result = sqlx::query(
            r#"
            UPDATE categories
            SET deleted_at = ?
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(&now)
        .bind(id)
        .execute(&self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }
}
