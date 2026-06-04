use crate::domain::aggregates::{Category, CategoryType};
use crate::domain::repositories::CategoryRepository;
use async_trait::async_trait;
use sqlx::SqlitePool;
use uuid::Uuid;

pub struct SqliteCategoryRepository {
    pool: SqlitePool,
}

impl SqliteCategoryRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl CategoryRepository for SqliteCategoryRepository {
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Category>, sqlx::Error> {
        let row = sqlx::query_as::<_, CategoryRow>(
            r#"
            SELECT id, name, category_type, icon, color, parent_id,
                   is_system, sort_order, updated_at, deleted_at,
                   device_id
            FROM categories
            WHERE id = ? AND deleted_at IS NULL
            "#,
        )
        .bind(id.as_bytes().to_vec())
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(row_to_category))
    }

    async fn list_by_type(
        &self,
        category_type: Option<CategoryType>,
        _include_deleted: bool,
    ) -> Result<Vec<Category>, sqlx::Error> {
        let mut query = String::from(
            "SELECT id, name, category_type, icon, color, parent_id,
             is_system, sort_order, updated_at, deleted_at,
             device_id
             FROM categories WHERE deleted_at IS NULL",
        );

        if let Some(ct) = category_type {
            query.push_str(" AND category_type = ?");
            let rows = sqlx::query_as::<_, CategoryRow>(&query)
                .bind(ct.to_string())
                .fetch_all(&self.pool)
                .await?;
            Ok(rows.into_iter().map(row_to_category).collect())
        } else {
            let rows = sqlx::query_as::<_, CategoryRow>(&query)
                .fetch_all(&self.pool)
                .await?;
            Ok(rows.into_iter().map(row_to_category).collect())
        }
    }

    async fn save(&self, category: &Category) -> Result<(), sqlx::Error> {
        let device_id_str = category.sync_metadata.device_id.to_string();
        sqlx::query(
            r#"
            INSERT INTO categories (id, name, category_type, icon, color, parent_id,
                                   is_system, sort_order, updated_at,
                                   deleted_at, device_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                category_type = excluded.category_type,
                icon = excluded.icon,
                color = excluded.color,
                parent_id = excluded.parent_id,
                is_system = excluded.is_system,
                sort_order = excluded.sort_order,
                updated_at = excluded.updated_at,
                deleted_at = excluded.deleted_at,
                device_id = excluded.device_id
            "#,
        )
        .bind(category.id.as_bytes().to_vec())
        .bind(&category.name)
        .bind(category.category_type.to_string())
        .bind(&category.icon)
        .bind(&category.color)
        .bind(category.parent_id.map(|id| id.as_bytes().to_vec()))
        .bind(category.is_system)
        .bind(category.sort_order)
        .bind(category.sync_metadata.updated_at)
        .bind(category.sync_metadata.deleted_at)
        .bind(&device_id_str)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn soft_delete(&self, id: Uuid) -> Result<(), sqlx::Error> {
        sqlx::query("UPDATE categories SET deleted_at = datetime('now') WHERE id = ?")
            .bind(id.as_bytes().to_vec())
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}

fn row_to_category(row: CategoryRow) -> Category {
    let device_id = row
        .device_id
        .map(|s| Uuid::parse_str(&s).unwrap_or_else(|_| Uuid::new_v4()))
        .unwrap_or_else(Uuid::new_v4);

    Category {
        id: Uuid::from_bytes(row.id.try_into().unwrap()),
        name: row.name,
        category_type: CategoryType::from_str(&row.category_type).unwrap(),
        icon: row.icon,
        color: row.color,
        parent_id: row
            .parent_id
            .map(|b| Uuid::from_bytes(b.try_into().unwrap())),
        is_system: row.is_system,
        sort_order: row.sort_order,
        sync_metadata: crate::domain::value_objects::SyncMetadata {
            updated_at: row.updated_at,
            deleted_at: row.deleted_at,
            device_id,
            synced_at: None,
        },
    }
}

#[derive(sqlx::FromRow)]
struct CategoryRow {
    id: Vec<u8>,
    name: String,
    category_type: String,
    icon: String,
    color: String,
    parent_id: Option<Vec<u8>>,
    is_system: bool,
    sort_order: i32,
    updated_at: chrono::DateTime<chrono::Utc>,
    deleted_at: Option<chrono::DateTime<chrono::Utc>>,
    device_id: Option<String>,
}
