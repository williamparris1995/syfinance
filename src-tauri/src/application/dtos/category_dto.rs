use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryDto {
    pub id: Uuid,
    pub name: String,
    pub category_type: String,
    pub icon: String,
    pub color: String,
    pub parent_id: Option<Uuid>,
    pub is_system: bool,
    pub sort_order: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateCategoryDto {
    pub name: String,
    pub category_type: String,
    pub icon: String,
    pub color: String,
    pub parent_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateCategoryDto {
    pub name: Option<String>,
    pub icon: Option<String>,
    pub color: Option<String>,
    pub parent_id: Option<Uuid>,
    pub sort_order: Option<i32>,
}
