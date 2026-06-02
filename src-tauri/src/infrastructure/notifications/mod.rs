pub mod notification_service;

// Re-exports form the library's public API surface, used by tests and external consumers.
#[allow(unused_imports)]
pub use notification_service::{
    NotificationError, NotificationSender, NotificationService, TauriNotificationSender,
};
