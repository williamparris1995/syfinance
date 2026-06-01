pub mod backup_service;
pub mod cloud_provider;
pub mod dropbox_provider;
pub mod google_drive_provider;
pub mod onedrive_provider;
pub mod webdav_provider;

pub use backup_service::{BackupService, RestoreResult, RestoreTableResult, TableRestoreStats};
pub use cloud_provider::{CloudBackupInfo, CloudError, CloudProvider, CloudSettings};

use webdav_provider::WebDavProvider;

/// Build a CloudProvider from saved cloud settings.
///
/// Currently supports WebDAV-based providers only (webdav, nextcloud, synology, jianguoyun, box).
/// Returns `Err(CloudError::NotConfigured)` for unsupported or unconfigured provider types.
pub fn build_cloud_provider(
    settings: &CloudSettings,
) -> Result<Box<dyn CloudProvider>, CloudError> {
    match settings.provider.as_str() {
        "webdav" | "nextcloud" | "synology" | "jianguoyun" | "box" => {
            let base_url = settings
                .server_url
                .clone()
                .ok_or(CloudError::NotConfigured)?;
            let username = settings.username.clone().ok_or(CloudError::NotConfigured)?;
            let password = settings.password.clone().ok_or(CloudError::NotConfigured)?;
            let remote_path = settings
                .remote_path
                .clone()
                .unwrap_or_else(|| "backups".to_string());

            Ok(Box::new(WebDavProvider::new(
                base_url,
                username,
                password,
                remote_path,
            )))
        }
        _ => Err(CloudError::NotConfigured),
    }
}
