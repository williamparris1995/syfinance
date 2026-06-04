use crate::application::dtos::{CategoryDto, CreateCategoryDto, UpdateCategoryDto};
use crate::domain::aggregates::{Category, CategoryType};
use crate::domain::repositories::CategoryRepository;
use std::sync::Arc;
use uuid::Uuid;

pub struct CategoryService<R: CategoryRepository> {
    repo: Arc<R>,
}

impl<R: CategoryRepository> CategoryService<R> {
    pub fn new(repo: Arc<R>) -> Self {
        Self { repo }
    }

    pub async fn list_categories(
        &self,
        category_type: Option<String>,
    ) -> Result<Vec<CategoryDto>, CategoryServiceError> {
        let ct = category_type.and_then(|t| match t.to_lowercase().as_str() {
            "income" => Some(CategoryType::Income),
            "expense" => Some(CategoryType::Expense),
            _ => None,
        });
        let categories = self.repo.list_by_type(ct, false).await?;
        Ok(categories.into_iter().map(|c| c.into()).collect())
    }

    pub async fn create_category(
        &self,
        dto: CreateCategoryDto,
    ) -> Result<CategoryDto, CategoryServiceError> {
        let category_type = match dto.category_type.to_lowercase().as_str() {
            "income" => CategoryType::Income,
            "expense" => CategoryType::Expense,
            _ => return Err(CategoryServiceError::InvalidCategoryType(dto.category_type)),
        };
        let category = Category::new(
            Uuid::new_v4(),
            dto.name,
            category_type,
            dto.icon,
            dto.color,
            false,
            0,
            crate::domain::value_objects::SyncMetadata::new(Uuid::new_v4()),
        )
        .map_err(|e| CategoryServiceError::DomainError(e.to_string()))?;
        self.repo.save(&category).await?;
        Ok(category.into())
    }

    pub async fn update_category(
        &self,
        id: Uuid,
        dto: UpdateCategoryDto,
    ) -> Result<CategoryDto, CategoryServiceError> {
        let mut category = self
            .repo
            .find_by_id(id)
            .await?
            .ok_or(CategoryServiceError::NotFound(id))?;

        if let Some(name) = dto.name {
            category
                .update_name(name)
                .map_err(|e| CategoryServiceError::DomainError(e.to_string()))?;
        }
        if let Some(icon) = dto.icon {
            category.update_icon(icon);
        }
        if let Some(color) = dto.color {
            category.update_color(color);
        }
        if let Some(parent_id) = dto.parent_id {
            category.update_parent(Some(parent_id));
        }
        if let Some(sort_order) = dto.sort_order {
            category.sort_order = sort_order;
            category.touch();
        }

        self.repo.save(&category).await?;
        Ok(category.into())
    }

    pub async fn delete_category(&self, id: Uuid) -> Result<(), CategoryServiceError> {
        let category = self
            .repo
            .find_by_id(id)
            .await?
            .ok_or(CategoryServiceError::NotFound(id))?;
        if category.is_system {
            return Err(CategoryServiceError::CannotDeleteSystem);
        }
        self.repo.soft_delete(id).await?;
        Ok(())
    }
}

#[derive(Debug, thiserror::Error)]
pub enum CategoryServiceError {
    #[error("invalid category type: {0}")]
    InvalidCategoryType(String),
    #[error("category not found: {0}")]
    NotFound(Uuid),
    #[error("cannot delete system category")]
    CannotDeleteSystem,
    #[error("domain error: {0}")]
    DomainError(String),
    #[error("repository error: {0}")]
    RepositoryError(#[from] sqlx::Error),
}

impl From<Category> for CategoryDto {
    fn from(c: Category) -> Self {
        Self {
            id: c.id,
            name: c.name,
            category_type: c.category_type.to_string(),
            icon: c.icon,
            color: c.color,
            parent_id: c.parent_id,
            is_system: c.is_system,
            sort_order: c.sort_order,
        }
    }
}
