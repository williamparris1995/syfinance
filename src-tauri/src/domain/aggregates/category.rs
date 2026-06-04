use crate::domain::value_objects::SyncMetadata;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::fmt;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum CategoryType {
    Income,
    Expense,
}

impl fmt::Display for CategoryType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Income => write!(f, "income"),
            Self::Expense => write!(f, "expense"),
        }
    }
}

impl CategoryType {
    #[allow(clippy::should_implement_trait)]
    pub fn from_str(s: &str) -> Result<Self, CategoryError> {
        match s.to_lowercase().as_str() {
            "income" => Ok(CategoryType::Income),
            "expense" => Ok(CategoryType::Expense),
            _ => Err(CategoryError::InvalidCategoryType(s.to_string())),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Category {
    pub id: Uuid,
    pub name: String,
    pub category_type: CategoryType,
    pub icon: String,
    pub color: String,
    pub parent_id: Option<Uuid>,
    pub is_system: bool,
    pub sort_order: i32,
    pub sync_metadata: SyncMetadata,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CategoryError {
    EmptyName,
    InvalidCategoryType(String),
    DeletedCategory,
}

impl fmt::Display for CategoryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyName => write!(f, "category name cannot be empty"),
            Self::InvalidCategoryType(t) => write!(f, "invalid category type: {}", t),
            Self::DeletedCategory => write!(f, "cannot mutate a deleted category"),
        }
    }
}

impl std::error::Error for CategoryError {}

impl Category {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: Uuid,
        name: impl Into<String>,
        category_type: CategoryType,
        icon: impl Into<String>,
        color: impl Into<String>,
        is_system: bool,
        sort_order: i32,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, CategoryError> {
        let name = name.into().trim().to_string();
        if name.is_empty() {
            return Err(CategoryError::EmptyName);
        }
        Ok(Self {
            id,
            name,
            category_type,
            icon: icon.into(),
            color: color.into(),
            parent_id: None,
            is_system,
            sort_order,
            sync_metadata,
        })
    }

    pub fn update_name(&mut self, name: impl Into<String>) -> Result<(), CategoryError> {
        self.ensure_not_deleted()?;
        let name = name.into().trim().to_string();
        if name.is_empty() {
            return Err(CategoryError::EmptyName);
        }
        self.name = name;
        self.touch();
        Ok(())
    }

    pub fn update_icon(&mut self, icon: impl Into<String>) {
        self.icon = icon.into();
        self.touch();
    }

    pub fn update_color(&mut self, color: impl Into<String>) {
        self.color = color.into();
        self.touch();
    }

    pub fn update_parent(&mut self, parent_id: Option<Uuid>) {
        self.parent_id = parent_id;
        self.touch();
    }

    #[allow(dead_code)]
    pub fn soft_delete(&mut self) {
        self.sync_metadata.mark_deleted();
    }

    fn ensure_not_deleted(&self) -> Result<(), CategoryError> {
        if self.sync_metadata.is_deleted() {
            Err(CategoryError::DeletedCategory)
        } else {
            Ok(())
        }
    }

    pub(crate) fn touch(&mut self) {
        self.sync_metadata.updated_at = Utc::now();
        self.sync_metadata.synced_at = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn metadata() -> SyncMetadata {
        SyncMetadata::new(Uuid::new_v4())
    }

    #[test]
    fn category_new_success() {
        let category = Category::new(
            Uuid::new_v4(),
            "餐饮",
            CategoryType::Expense,
            "🍔",
            "#F59E0B",
            false,
            1,
            metadata(),
        )
        .unwrap();
        assert_eq!(category.name, "餐饮");
        assert_eq!(category.category_type, CategoryType::Expense);
        assert!(!category.is_system);
    }

    #[test]
    fn category_empty_name_fails() {
        let result = Category::new(
            Uuid::new_v4(),
            "",
            CategoryType::Expense,
            "🍔",
            "#F59E0B",
            false,
            1,
            metadata(),
        );
        assert!(matches!(result, Err(CategoryError::EmptyName)));
    }

    #[test]
    fn category_update_name() {
        let mut category = Category::new(
            Uuid::new_v4(),
            "餐饮",
            CategoryType::Expense,
            "🍔",
            "#F59E0B",
            false,
            1,
            metadata(),
        )
        .unwrap();

        category.update_name("工作餐").unwrap();
        assert_eq!(category.name, "工作餐");
    }

    #[test]
    fn category_soft_delete() {
        let mut category = Category::new(
            Uuid::new_v4(),
            "餐饮",
            CategoryType::Expense,
            "🍔",
            "#F59E0B",
            false,
            1,
            metadata(),
        )
        .unwrap();

        category.soft_delete();
        assert!(category.sync_metadata.is_deleted());
        assert!(category.update_name("test").is_err());
    }
}
