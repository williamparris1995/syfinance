pub mod backup_service;
pub mod cloud_provider;
pub mod dropbox_provider;
pub mod google_drive_provider;
pub mod oauth;
pub mod onedrive_provider;
pub mod webdav_provider;

// Re-exports form the library's public API surface, used by tests and external consumers.
#[allow(unused_imports)]
pub use backup_service::{BackupService, RestoreResult, RestoreTableResult, TableRestoreStats};
#[allow(unused_imports)]
pub use cloud_provider::{CloudBackupInfo, CloudError, CloudProvider, CloudSettings};

use dropbox_provider::DropboxProvider;
use google_drive_provider::GoogleDriveProvider;
use onedrive_provider::OneDriveProvider;
use webdav_provider::WebDavProvider;

/// Build a CloudProvider from saved cloud settings.
///
/// Supports WebDAV-based providers (webdav, nextcloud, synology, jianguoyun, box)
/// and OAuth-based providers (dropbox, google_drive, onedrive).
/// Returns `Err(CloudError::NotConfigured)` for unconfigured provider types.
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
        "dropbox" => {
            let access_token = settings
                .access_token
                .clone()
                .ok_or(CloudError::NotConfigured)?;
            let remote_path = settings
                .remote_path
                .clone()
                .unwrap_or_else(|| "finance-app/backups".to_string());
            let client_id = settings.username.clone().unwrap_or_default();
            Ok(Box::new(DropboxProvider::new(
                access_token,
                settings.refresh_token.clone(),
                remote_path,
                client_id,
            )))
        }
        "google_drive" => {
            let access_token = settings
                .access_token
                .clone()
                .ok_or(CloudError::NotConfigured)?;
            let remote_path = settings
                .remote_path
                .clone()
                .unwrap_or_else(|| "finance-app-backups".to_string());
            let client_id = settings.username.clone().unwrap_or_default();
            Ok(Box::new(GoogleDriveProvider::new(
                access_token,
                settings.refresh_token.clone(),
                remote_path,
                client_id,
            )))
        }
        "onedrive" => {
            let access_token = settings
                .access_token
                .clone()
                .ok_or(CloudError::NotConfigured)?;
            let remote_path = settings
                .remote_path
                .clone()
                .unwrap_or_else(|| "finance-app/backups".to_string());
            let client_id = settings.username.clone().unwrap_or_default();
            Ok(Box::new(OneDriveProvider::new(
                access_token,
                settings.refresh_token.clone(),
                remote_path,
                client_id,
            )))
        }
        _ => Err(CloudError::NotConfigured),
    }
}
