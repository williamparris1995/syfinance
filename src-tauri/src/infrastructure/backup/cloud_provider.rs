use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, thiserror::Error)]
pub enum CloudError {
    #[error("connection failed: {0}")]
    ConnectionFailed(String),
    #[error("authentication failed: {0}")]
    AuthFailed(String),
    #[error("upload failed: {0}")]
    UploadFailed(String),
    #[error("download failed: {0}")]
    DownloadFailed(String),
    #[error("not configured")]
    NotConfigured,
    #[error("network error: {0}")]
    NetworkError(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudBackupInfo {
    pub name: String,
    pub size: u64,
    pub last_modified: Option<String>,
}

#[async_trait]
pub trait CloudProvider: Send + Sync {
    // TODO: will be used when provider name display is implemented
    #[allow(dead_code)]
    fn name(&self) -> &str;
    async fn test_connection(&self) -> Result<(), CloudError>;
    async fn upload(&self, local_path: &Path, remote_name: &str) -> Result<(), CloudError>;
    async fn download(&self, remote_name: &str, local_path: &Path) -> Result<(), CloudError>;
    async fn list_backups(&self) -> Result<Vec<CloudBackupInfo>, CloudError>;
    // TODO: will be used when remote backup deletion is implemented
    #[allow(dead_code)]
    async fn delete(&self, remote_name: &str) -> Result<(), CloudError>;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudPreset {
    pub id: &'static str,
    pub name: &'static str,
    pub protocol: &'static str,
    pub default_server: &'static str,
    pub default_port: u16,
    pub use_https: bool,
    pub auth_type: &'static str,
}

/// Persisted cloud storage configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudSettings {
    pub provider: String,
    pub server_url: Option<String>,
    pub port: Option<i64>,
    pub username: Option<String>,
    pub password: Option<String>,
    pub remote_path: Option<String>,
    pub access_token: Option<String>,
    pub refresh_token: Option<String>,
    pub auto_upload: Option<String>,
    pub enabled: Option<bool>,
}

pub fn get_presets() -> Vec<CloudPreset> {
    vec![
        CloudPreset {
            id: "webdav",
            name: "Custom WebDAV",
            protocol: "webdav",
            default_server: "",
            default_port: 443,
            use_https: true,
            auth_type: "password",
        },
        CloudPreset {
            id: "nextcloud",
            name: "NextCloud",
            protocol: "webdav",
            default_server: "/remote.php/dav/files/",
            default_port: 443,
            use_https: true,
            auth_type: "app_password",
        },
        CloudPreset {
            id: "synology",
            name: "Synology",
            protocol: "webdav",
            default_server: "",
            default_port: 5006,
            use_https: false,
            auth_type: "password",
        },
        CloudPreset {
            id: "jianguoyun",
            name: "Nutstore",
            protocol: "webdav",
            default_server: "https://dav.jianguoyun.com/dav/",
            default_port: 443,
            use_https: true,
            auth_type: "app_password",
        },
        CloudPreset {
            id: "box",
            name: "Box",
            protocol: "webdav",
            default_server: "https://dav.box.com/dav/",
            default_port: 443,
            use_https: true,
            auth_type: "password",
        },
        CloudPreset {
            id: "dropbox",
            name: "Dropbox",
            protocol: "dropbox",
            default_server: "https://api.dropboxapi.com",
            default_port: 443,
            use_https: true,
            auth_type: "oauth2",
        },
        CloudPreset {
            id: "google_drive",
            name: "Google Drive",
            protocol: "google_drive",
            default_server: "https://www.googleapis.com",
            default_port: 443,
            use_https: true,
            auth_type: "oauth2",
        },
        CloudPreset {
            id: "onedrive",
            name: "OneDrive",
            protocol: "onedrive",
            default_server: "https://graph.microsoft.com",
            default_port: 443,
            use_https: true,
            auth_type: "oauth2",
        },
    ]
}
