use std::path::Path;
use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use tracing::{error, info};

use super::cloud_provider::{CloudBackupInfo, CloudError, CloudProvider};
use super::oauth::{self, OAuthConfig};

pub struct OneDriveProvider {
    client: Client,
    access_token: String,
    refresh_token: Option<String>,
    remote_path: String,
    oauth_config: OAuthConfig,
}

impl OneDriveProvider {
    pub fn new(
        access_token: String,
        refresh_token: Option<String>,
        remote_path: String,
        client_id: String,
    ) -> Self {
        let oauth_config = oauth::get_oauth_config("onedrive", &client_id, None);
        let client = Client::builder()
            .timeout(Duration::from_secs(60))
            .build()
            .unwrap_or_default();

        Self {
            client,
            access_token,
            refresh_token,
            remote_path,
            oauth_config,
        }
    }

    /// Ensure the access token is valid, refreshing if necessary.
    async fn ensure_valid_token(&mut self) -> Result<(), CloudError> {
        if let Some(refresh) = self.refresh_token.clone() {
            if oauth::is_token_expired(None) {
                info!("onedrive access token expired, attempting refresh");
                match oauth::refresh_access_token(&self.oauth_config, &refresh).await {
                    Ok(tokens) => {
                        self.access_token = tokens.access_token;
                        if tokens.refresh_token.is_some() {
                            self.refresh_token = tokens.refresh_token;
                        }
                        info!("onedrive token refreshed successfully");
                    }
                    Err(e) => {
                        error!(error = %e, "Failed to refresh OneDrive token");
                        return Err(CloudError::AuthFailed(format!("token refresh failed: {e}")));
                    }
                }
            }
        }
        Ok(())
    }

    /// Build the remote item path for Microsoft Graph API.
    fn remote_item_path(&self, name: &str) -> String {
        let folder = self.remote_path.trim_matches('/');
        format!("{}:/{}/{}", Self::drive_root(), folder, name)
    }

    fn remote_folder_path(&self) -> String {
        let folder = self.remote_path.trim_matches('/');
        format!("{}:/{}", Self::drive_root(), folder)
    }

    fn drive_root() -> &'static str {
        "https://graph.microsoft.com/v1.0/me/drive/root"
    }
}

#[async_trait]
impl CloudProvider for OneDriveProvider {
    fn name(&self) -> &str {
        "OneDrive"
    }

    async fn test_connection(&self) -> Result<(), CloudError> {
        let response = self
            .client
            .get("https://graph.microsoft.com/v1.0/me/drive")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!(status = %status, body = %body, "OneDrive connection test failed");
            match status.as_u16() {
                401 => Err(CloudError::AuthFailed("invalid access token".to_string())),
                _ => Err(CloudError::ConnectionFailed(format!(
                    "OneDrive returned status {status}"
                ))),
            }
        }
    }

    async fn upload(&self, local_path: &Path, remote_name: &str) -> Result<(), CloudError> {
        let data = tokio::fs::read(local_path)
            .await
            .map_err(|e| CloudError::UploadFailed(format!("failed to read file: {e}")))?;

        let url = format!("{}:/{}", self.remote_item_path(remote_name), "");

        let response = self
            .client
            .put(&url)
            .header("Authorization", format!("Bearer {}", self.access_token))
            .header("Content-Type", "application/octet-stream")
            .body(data)
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            info!(remote = %remote_name, "uploaded to OneDrive");
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!(status = %status, body = %body, "OneDrive upload failed");
            Err(CloudError::UploadFailed(format!(
                "upload failed with status {status}: {body}"
            )))
        }
    }

    async fn download(&self, remote_name: &str, local_path: &Path) -> Result<(), CloudError> {
        let url = format!("{}:/content", self.remote_item_path(remote_name));

        let response = self
            .client
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.access_token))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            let data = response
                .bytes()
                .await
                .map_err(|e| CloudError::DownloadFailed(format!("failed to read body: {e}")))?;

            tokio::fs::write(local_path, &data)
                .await
                .map_err(|e| CloudError::DownloadFailed(format!("failed to write file: {e}")))?;

            info!(remote = %remote_name, "downloaded from OneDrive");
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            Err(CloudError::DownloadFailed(format!(
                "download failed with status {status}: {body}"
            )))
        }
    }

    async fn list_backups(&self) -> Result<Vec<CloudBackupInfo>, CloudError> {
        let url = format!("{}/children", self.remote_folder_path());

        let response = self
            .client
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.access_token))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(CloudError::ConnectionFailed(format!(
                "list folder failed with status {status}: {body}"
            )));
        }

        let result: serde_json::Value = response
            .json()
            .await
            .map_err(|e| CloudError::ConnectionFailed(format!("failed to parse response: {e}")))?;

        let entries = match result.get("value").and_then(|v| v.as_array()) {
            Some(arr) => arr,
            None => return Ok(vec![]),
        };

        let mut backups = Vec::new();
        for entry in entries {
            // Skip folders
            let is_folder = entry
                .get("folder")
                .is_some();
            if is_folder {
                continue;
            }

            let name = match entry.get("name").and_then(|n| n.as_str()) {
                Some(n) => n.to_string(),
                None => continue,
            };

            if !name.ends_with(".enc") {
                continue;
            }

            let size = entry
                .get("size")
                .and_then(|s| s.as_u64())
                .unwrap_or(0);

            let last_modified = entry
                .get("lastModifiedDateTime")
                .and_then(|m| m.as_str())
                .map(|s| s.to_string());

            backups.push(CloudBackupInfo {
                name,
                size,
                last_modified,
            });
        }

        Ok(backups)
    }

    async fn delete(&self, remote_name: &str) -> Result<(), CloudError> {
        // First get the item ID by path
        let meta_url = self.remote_item_path(remote_name);
        let response = self
            .client
            .get(&meta_url)
            .header("Authorization", format!("Bearer {}", self.access_token))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(CloudError::UploadFailed(format!(
                "failed to get file ID with status {status}: {body}"
            )));
        }

        let meta: serde_json::Value = response
            .json()
            .await
            .map_err(|e| CloudError::UploadFailed(format!("failed to parse metadata: {e}")))?;

        let item_id = meta
            .get("id")
            .and_then(|i| i.as_str())
            .ok_or_else(|| CloudError::UploadFailed("no item ID in response".to_string()))?;

        let delete_url = format!(
            "https://graph.microsoft.com/v1.0/me/drive/items/{}",
            item_id
        );

        let response = self
            .client
            .delete(&delete_url)
            .header("Authorization", format!("Bearer {}", self.access_token))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            info!(remote = %remote_name, "deleted from OneDrive");
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            Err(CloudError::UploadFailed(format!(
                "delete failed with status {status}: {body}"
            )))
        }
    }
}
