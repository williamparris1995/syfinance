use std::path::Path;
use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use tracing::{error, info};

use super::cloud_provider::{CloudBackupInfo, CloudError, CloudProvider};
use super::oauth::{self, OAuthConfig};

// TODO: will be used when OAuth token refresh is implemented
#[allow(dead_code)]
pub struct DropboxProvider {
    client: Client,
    access_token: String,
    #[allow(dead_code)]
    refresh_token: Option<String>,
    remote_path: String,
    #[allow(dead_code)]
    oauth_config: OAuthConfig,
}

impl DropboxProvider {
    pub fn new(
        access_token: String,
        refresh_token: Option<String>,
        remote_path: String,
        client_id: String,
    ) -> Self {
        let oauth_config = oauth::get_oauth_config("dropbox", &client_id, None);
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
    // TODO: will be used when OAuth token refresh is implemented
    #[allow(dead_code)]
    async fn ensure_valid_token(&mut self) -> Result<(), CloudError> {
        if !oauth::is_token_expired(None) {
            return Ok(());
        }

        // If we have a refresh token, attempt refresh
        if let Some(refresh) = self.refresh_token.clone() {
            info!("dropbox access token expired, attempting refresh");
            match oauth::refresh_access_token(&self.oauth_config, &refresh).await {
                Ok(tokens) => {
                    self.access_token = tokens.access_token;
                    if tokens.refresh_token.is_some() {
                        self.refresh_token = tokens.refresh_token;
                    }
                    info!("dropbox token refreshed successfully");
                    Ok(())
                }
                Err(e) => {
                    error!(error = %e, "Failed to refresh Dropbox token");
                    Err(CloudError::AuthFailed(format!("token refresh failed: {e}")))
                }
            }
        } else {
            Ok(())
        }
    }

    fn remote_path_for(&self, name: &str) -> String {
        format!(
            "/{}/{}",
            self.remote_path.trim_matches('/'),
            name
        )
    }

    fn remote_folder_path(&self) -> String {
        format!("/{}", self.remote_path.trim_matches('/'))
    }
}

#[async_trait]
impl CloudProvider for DropboxProvider {
    fn name(&self) -> &str {
        "Dropbox"
    }

    async fn test_connection(&self) -> Result<(), CloudError> {
        let response = self
            .client
            .post("https://api.dropboxapi.com/2/users/get_current_account")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!(status = %status, body = %body, "Dropbox connection test failed");
            match status.as_u16() {
                401 => Err(CloudError::AuthFailed("invalid access token".to_string())),
                _ => Err(CloudError::ConnectionFailed(format!(
                    "Dropbox returned status {status}"
                ))),
            }
        }
    }

    async fn upload(&self, local_path: &Path, remote_name: &str) -> Result<(), CloudError> {
        let data = tokio::fs::read(local_path)
            .await
            .map_err(|e| CloudError::UploadFailed(format!("failed to read file: {e}")))?;

        let dropbox_path = self.remote_path_for(remote_name);
        let args = serde_json::json!({
            "path": dropbox_path,
            "mode": "overwrite",
            "autorename": false,
        });

        let response = self
            .client
            .post("https://content.dropboxapi.com/2/files/upload")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .header("Dropbox-API-Arg", args.to_string())
            .header("Content-Type", "application/octet-stream")
            .body(data)
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            info!(remote = %remote_name, "uploaded to Dropbox");
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!(status = %status, body = %body, "Dropbox upload failed");
            Err(CloudError::UploadFailed(format!(
                "upload failed with status {status}: {body}"
            )))
        }
    }

    async fn download(&self, remote_name: &str, local_path: &Path) -> Result<(), CloudError> {
        let dropbox_path = self.remote_path_for(remote_name);
        let args = serde_json::json!({
            "path": dropbox_path,
        });

        let response = self
            .client
            .post("https://content.dropboxapi.com/2/files/download")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .header("Dropbox-API-Arg", args.to_string())
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

            info!(remote = %remote_name, "downloaded from Dropbox");
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
        let folder_path = self.remote_folder_path();
        let body = serde_json::json!({
            "path": folder_path,
            "recursive": false,
        });

        let response = self
            .client
            .post("https://api.dropboxapi.com/2/files/list_folder")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .header("Content-Type", "application/json")
            .body(body.to_string())
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

        let entries = match result.get("entries").and_then(|e| e.as_array()) {
            Some(arr) => arr,
            None => return Ok(vec![]),
        };

        let mut backups = Vec::new();
        for entry in entries {
            let tag = entry
                .get(".tag")
                .and_then(|t| t.as_str())
                .unwrap_or("");
            if tag != "file" {
                continue;
            }

            let name = match entry.get("name").and_then(|n| n.as_str()) {
                Some(n) => n.to_string(),
                None => continue,
            };

            // Only include .enc files
            if !name.ends_with(".enc") {
                continue;
            }

            let size = entry
                .get("size")
                .and_then(|s| s.as_u64())
                .unwrap_or(0);

            let last_modified = entry
                .get("server_modified")
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
        let dropbox_path = self.remote_path_for(remote_name);
        let body = serde_json::json!({
            "path": dropbox_path,
        });

        let response = self
            .client
            .post("https://api.dropboxapi.com/2/files/delete_v2")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .header("Content-Type", "application/json")
            .body(body.to_string())
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            info!(remote = %remote_name, "deleted from Dropbox");
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
