use crate::domain::aggregates::{Category, CategoryType};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateCategoryDto {
    pub name: String,
    pub icon: String,
    pub color: String,
    pub category_type: CategoryType,
    pub chart_code: String,
    pub parent_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateCategoryDto {
    pub name: Option<String>,
    pub icon: Option<String>,
    pub color: Option<String>,
    pub parent_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryDto {
    pub id: String,
    pub name: String,
    pub icon: String,
    pub color: String,
    pub category_type: CategoryType,
    pub chart_code: String,
    pub parent_id: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

impl From<Category> for CategoryDto {
    fn from(category: Category) -> Self {
        Self {
            id: category.id,
            name: category.name,
            icon: category.icon,
            color: category.color,
            category_type: category.category_type,
            chart_code: category.chart_code,
            parent_id: category.parent_id,
            created_at: category.sync_metadata.updated_at.to_rfc3339(),
            updated_at: category.sync_metadata.updated_at.to_rfc3339(),
            deleted_at: category.sync_metadata.deleted_at.map(|dt| dt.to_rfc3339()),
        }
    }
}
