use crate::domain::aggregates::{Category, CategoryError, CategoryType};
use crate::domain::repositories::CategoryRepository;
use crate::domain::value_objects::SyncMetadata;
use std::sync::Arc;
use uuid::Uuid;

pub struct CategoryService<R: CategoryRepository> {
    category_repo: Arc<R>,
}

impl<R: CategoryRepository> CategoryService<R> {
    pub fn new(category_repo: Arc<R>) -> Self {
        Self { category_repo }
    }

    pub async fn create_category(
        &self,
        name: String,
        icon: String,
        color: String,
        category_type: CategoryType,
        chart_code: String,
        parent_id: Option<String>,
    ) -> Result<Category, CategoryServiceError> {
        let category = Category::new(
            Uuid::new_v4().to_string(),
            name,
            icon,
            color,
            category_type,
            chart_code,
            parent_id,
            SyncMetadata::new(Uuid::new_v4()),
        )?;

        self.category_repo.create(&category).await?;

        Ok(category)
    }

    pub async fn update_category(
        &self,
        id: String,
        name: String,
        icon: String,
        color: String,
    ) -> Result<Category, CategoryServiceError> {
        let mut category = self
            .category_repo
            .find_by_id(&id)
            .await?
            .ok_or(CategoryServiceError::CategoryNotFound(id.clone()))?;

        category.update(name, icon, color)?;

        self.category_repo.update(&category).await?;

        Ok(category)
    }

    pub async fn delete_category(&self, id: String) -> Result<(), CategoryServiceError> {
        let mut category = self
            .category_repo
            .find_by_id(&id)
            .await?
            .ok_or(CategoryServiceError::CategoryNotFound(id.clone()))?;

        category.soft_delete()?;

        self.category_repo.update(&category).await?;

        Ok(())
    }

    pub async fn get_category(&self, id: String) -> Result<Category, CategoryServiceError> {
        let category = self
            .category_repo
            .find_by_id(&id)
            .await?
            .ok_or(CategoryServiceError::CategoryNotFound(id.clone()))?;

        Ok(category)
    }

    pub async fn list_categories(&self) -> Result<Vec<Category>, CategoryServiceError> {
        let categories = self.category_repo.find_all().await?;
        Ok(categories)
    }

    pub async fn list_categories_by_type(
        &self,
        category_type: CategoryType,
    ) -> Result<Vec<Category>, CategoryServiceError> {
        let categories = self.category_repo.find_by_type(category_type).await?;
        Ok(categories)
    }

    pub async fn list_categories_by_parent(
        &self,
        parent_id: Option<String>,
    ) -> Result<Vec<Category>, CategoryServiceError> {
        let categories = self
            .category_repo
            .find_by_parent(parent_id.as_deref())
            .await?;
        Ok(categories)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum CategoryServiceError {
    #[error("Category not found: {0}")]
    CategoryNotFound(String),

    #[error("Category domain error: {0}")]
    CategoryError(#[from] CategoryError),

    #[error("Database error: {0}")]
    DatabaseError(#[from] sqlx::Error),
}
