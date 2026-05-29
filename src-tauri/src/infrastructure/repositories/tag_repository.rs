use crate::domain::aggregates::tag::Tag;
use crate::domain::repositories::TagRepository;
use sqlx::{Row, SqlitePool};

#[derive(Clone)]
pub struct SqliteTagRepository {
    pool: SqlitePool,
}

impl SqliteTagRepository {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_tag(row: &sqlx::sqlite::SqliteRow) -> Result<Tag, sqlx::Error> {
        let id: String = row.try_get("id")?;
        let name: String = row.try_get("name")?;
        let color: String = row.try_get("color")?;
        Ok(Tag { id, name, color })
    }
}

impl TagRepository for SqliteTagRepository {
    async fn create(&self, tag: &Tag) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query("INSERT INTO tags (id, name, color, created_at) VALUES (?, ?, ?, ?)")
            .bind(&tag.id)
            .bind(&tag.name)
            .bind(&tag.color)
            .bind(&now)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn find_all(&self) -> sqlx::Result<Vec<Tag>> {
        let rows = sqlx::query("SELECT id, name, color FROM tags ORDER BY name")
            .fetch_all(&self.pool)
            .await?;
        rows.iter().map(Self::row_to_tag).collect()
    }

    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Tag>> {
        let row = sqlx::query("SELECT id, name, color FROM tags WHERE id = ?")
            .bind(id)
            .fetch_optional(&self.pool)
            .await?;
        row.map(|r| Self::row_to_tag(&r)).transpose()
    }

    async fn delete(&self, id: &str) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM tags WHERE id = ?")
            .bind(id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn add_to_transaction(&self, transaction_id: &str, tag_id: &str) -> sqlx::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query("INSERT OR IGNORE INTO transaction_tags (transaction_id, tag_id, created_at) VALUES (?, ?, ?)")
            .bind(transaction_id)
            .bind(tag_id)
            .bind(&now)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn remove_from_transaction(
        &self,
        transaction_id: &str,
        tag_id: &str,
    ) -> sqlx::Result<()> {
        sqlx::query("DELETE FROM transaction_tags WHERE transaction_id = ? AND tag_id = ?")
            .bind(transaction_id)
            .bind(tag_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn find_by_transaction(&self, transaction_id: &str) -> sqlx::Result<Vec<Tag>> {
        let rows = sqlx::query(
            r#"
            SELECT t.id, t.name, t.color
            FROM tags t
            JOIN transaction_tags tt ON t.id = tt.tag_id
            WHERE tt.transaction_id = ?
            ORDER BY t.name
            "#,
        )
        .bind(transaction_id)
        .fetch_all(&self.pool)
        .await?;
        rows.iter().map(Self::row_to_tag).collect()
    }
}
