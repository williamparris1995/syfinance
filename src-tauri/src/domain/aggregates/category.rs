use crate::domain::value_objects::SyncMetadata;
use chrono::{DateTime, Utc};
use std::{error::Error, fmt};

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CategoryEvent {
    CategoryCreated {
        category_id: String,
        name: String,
        category_type: CategoryType,
    },
    CategoryUpdated {
        category_id: String,
    },
    CategoryDeleted {
        category_id: String,
        deleted_at: DateTime<Utc>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CategoryError {
    EmptyName,
    EmptyIcon,
    InvalidColor,
    EmptyChartCode,
    DeletedCategory,
    CircularParentReference,
}

impl fmt::Display for CategoryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyName => write!(f, "category name cannot be empty"),
            Self::EmptyIcon => write!(f, "category icon cannot be empty"),
            Self::InvalidColor => write!(
                f,
                "category color must be a valid hex color (e.g., #FF5733)"
            ),
            Self::EmptyChartCode => write!(f, "chart code cannot be empty"),
            Self::DeletedCategory => write!(f, "cannot mutate a deleted category"),
            Self::CircularParentReference => write!(f, "category cannot be its own parent"),
        }
    }
}

impl Error for CategoryError {}

#[derive(Debug, Clone)]
pub struct Category {
    pub id: String,
    pub name: String,
    pub icon: String,
    pub color: String,
    pub category_type: CategoryType,
    pub chart_code: String,
    pub parent_id: Option<String>,
    pub sync_metadata: SyncMetadata,
    pub(crate) pending_events: Vec<CategoryEvent>,
}

impl Category {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: String,
        name: impl Into<String>,
        icon: impl Into<String>,
        color: impl Into<String>,
        category_type: CategoryType,
        chart_code: impl Into<String>,
        parent_id: Option<String>,
        sync_metadata: SyncMetadata,
    ) -> Result<Self, CategoryError> {
        let name = name.into().trim().to_string();
        let icon = icon.into().trim().to_string();
        let color = color.into().trim().to_string();
        let chart_code = chart_code.into().trim().to_string();

        if name.is_empty() {
            return Err(CategoryError::EmptyName);
        }

        if icon.is_empty() {
            return Err(CategoryError::EmptyIcon);
        }

        if !is_valid_hex_color(&color) {
            return Err(CategoryError::InvalidColor);
        }

        if chart_code.is_empty() {
            return Err(CategoryError::EmptyChartCode);
        }

        if let Some(ref parent_id) = parent_id {
            if parent_id == &id {
                return Err(CategoryError::CircularParentReference);
            }
        }

        let mut category = Self {
            id: id.clone(),
            name: name.clone(),
            icon,
            color,
            category_type: category_type.clone(),
            chart_code,
            parent_id,
            sync_metadata,
            pending_events: Vec::new(),
        };

        category
            .pending_events
            .push(CategoryEvent::CategoryCreated {
                category_id: id,
                name,
                category_type,
            });

        Ok(category)
    }

    pub fn update(
        &mut self,
        name: impl Into<String>,
        icon: impl Into<String>,
        color: impl Into<String>,
    ) -> Result<(), CategoryError> {
        self.ensure_not_deleted()?;

        let name = name.into().trim().to_string();
        let icon = icon.into().trim().to_string();
        let color = color.into().trim().to_string();

        if name.is_empty() {
            return Err(CategoryError::EmptyName);
        }

        if icon.is_empty() {
            return Err(CategoryError::EmptyIcon);
        }

        if !is_valid_hex_color(&color) {
            return Err(CategoryError::InvalidColor);
        }

        self.name = name;
        self.icon = icon;
        self.color = color;
        self.touch();

        self.pending_events.push(CategoryEvent::CategoryUpdated {
            category_id: self.id.clone(),
        });

        Ok(())
    }

    pub fn change_parent(&mut self, parent_id: Option<String>) -> Result<(), CategoryError> {
        self.ensure_not_deleted()?;

        if let Some(ref pid) = parent_id {
            if pid == &self.id {
                return Err(CategoryError::CircularParentReference);
            }
        }

        self.parent_id = parent_id;
        self.touch();

        self.pending_events.push(CategoryEvent::CategoryUpdated {
            category_id: self.id.clone(),
        });

        Ok(())
    }

    pub fn soft_delete(&mut self) -> Result<(), CategoryError> {
        self.ensure_not_deleted()?;
        self.sync_metadata.mark_deleted();

        if let Some(deleted_at) = self.sync_metadata.deleted_at {
            self.pending_events.push(CategoryEvent::CategoryDeleted {
                category_id: self.id.clone(),
                deleted_at,
            });
        }

        Ok(())
    }

    pub fn pull_events(&mut self) -> Vec<CategoryEvent> {
        std::mem::take(&mut self.pending_events)
    }

    fn ensure_not_deleted(&self) -> Result<(), CategoryError> {
        if self.sync_metadata.is_deleted() {
            Err(CategoryError::DeletedCategory)
        } else {
            Ok(())
        }
    }

    fn touch(&mut self) {
        self.sync_metadata.updated_at = Utc::now();
        self.sync_metadata.synced_at = None;
    }
}

fn is_valid_hex_color(color: &str) -> bool {
    if !color.starts_with('#') || color.len() != 7 {
        return false;
    }

    color[1..].chars().all(|c| c.is_ascii_hexdigit())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn metadata() -> SyncMetadata {
        SyncMetadata::new(Uuid::new_v4())
    }

    mod category {
        use super::*;

        #[test]
        fn creates_valid_category() {
            let category = Category::new(
                Uuid::new_v4().to_string(),
                "餐饮",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            );

            assert!(category.is_ok());
            let category = category.unwrap();
            assert_eq!(category.name, "餐饮");
            assert_eq!(category.icon, "🍔");
            assert_eq!(category.color, "#FF5733");
            assert_eq!(category.chart_code, "5401");
        }

        #[test]
        fn rejects_empty_name() {
            let result = Category::new(
                Uuid::new_v4().to_string(),
                "  ",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            );

            assert!(matches!(result, Err(CategoryError::EmptyName)));
        }

        #[test]
        fn rejects_empty_icon() {
            let result = Category::new(
                Uuid::new_v4().to_string(),
                "餐饮",
                "",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            );

            assert!(matches!(result, Err(CategoryError::EmptyIcon)));
        }

        #[test]
        fn rejects_invalid_color() {
            let result = Category::new(
                Uuid::new_v4().to_string(),
                "餐饮",
                "🍔",
                "FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            );

            assert!(matches!(result, Err(CategoryError::InvalidColor)));
        }

        #[test]
        fn rejects_circular_parent_reference() {
            let id = Uuid::new_v4().to_string();
            let result = Category::new(
                id.clone(),
                "餐饮",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                Some(id),
                metadata(),
            );

            assert!(matches!(
                result,
                Err(CategoryError::CircularParentReference)
            ));
        }

        #[test]
        fn updates_category_fields() {
            let mut category = Category::new(
                Uuid::new_v4().to_string(),
                "餐饮",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            )
            .unwrap();

            category.pull_events();

            let result = category.update("外卖", "🍕", "#00FF00");
            assert!(result.is_ok());
            assert_eq!(category.name, "外卖");
            assert_eq!(category.icon, "🍕");
            assert_eq!(category.color, "#00FF00");

            let events = category.pull_events();
            assert_eq!(events.len(), 1);
            assert!(matches!(events[0], CategoryEvent::CategoryUpdated { .. }));
        }

        #[test]
        fn soft_delete_marks_deleted() {
            let mut category = Category::new(
                Uuid::new_v4().to_string(),
                "餐饮",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            )
            .unwrap();

            category.soft_delete().unwrap();

            assert!(category.sync_metadata.is_deleted());
        }

        #[test]
        fn cannot_update_deleted_category() {
            let mut category = Category::new(
                Uuid::new_v4().to_string(),
                "餐饮",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            )
            .unwrap();

            category.soft_delete().unwrap();

            let result = category.update("外卖", "🍕", "#00FF00");
            assert!(matches!(result, Err(CategoryError::DeletedCategory)));
        }
    }

    mod domain_events {
        use super::*;

        #[test]
        fn emits_created_event() {
            let category_id = Uuid::new_v4().to_string();
            let mut category = Category::new(
                category_id.clone(),
                "餐饮",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            )
            .unwrap();

            let events = category.pull_events();
            assert_eq!(events.len(), 1);
            assert!(matches!(
                events[0],
                CategoryEvent::CategoryCreated {
                    category_id: ref id,
                    ..
                } if id == &category_id
            ));
        }

        #[test]
        fn emits_deleted_event() {
            let category_id = Uuid::new_v4().to_string();
            let mut category = Category::new(
                category_id.clone(),
                "餐饮",
                "🍔",
                "#FF5733",
                CategoryType::Expense,
                "5401",
                None,
                metadata(),
            )
            .unwrap();

            category.pull_events();
            category.soft_delete().unwrap();

            let events = category.pull_events();
            assert_eq!(events.len(), 1);
            assert!(matches!(
                events[0],
                CategoryEvent::CategoryDeleted {
                    category_id: ref id,
                    ..
                } if id == &category_id
            ));
        }
    }
}
