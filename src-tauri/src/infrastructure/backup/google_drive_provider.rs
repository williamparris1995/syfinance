use std::path::Path;
use std::time::Duration;

use async_trait::async_trait;
use reqwest::Client;
use tracing::{error, info};

use super::cloud_provider::{CloudBackupInfo, CloudError, CloudProvider};
use super::oauth::{self, OAuthConfig};

pub struct GoogleDriveProvider {
    client: Client,
    access_token: String,
    refresh_token: Option<String>,
    remote_path: String,
    oauth_config: OAuthConfig,
}

impl GoogleDriveProvider {
    pub fn new(
        access_token: String,
        refresh_token: Option<String>,
        remote_path: String,
        client_id: String,
    ) -> Self {
        let oauth_config = oauth::get_oauth_config("google_drive", &client_id, None);
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
                info!("google drive access token expired, attempting refresh");
                match oauth::refresh_access_token(&self.oauth_config, &refresh).await {
                    Ok(tokens) => {
                        self.access_token = tokens.access_token;
                        if tokens.refresh_token.is_some() {
                            self.refresh_token = tokens.refresh_token;
                        }
                        info!("google drive token refreshed successfully");
                    }
                    Err(e) => {
                        error!(error = %e, "Failed to refresh Google Drive token");
                        return Err(CloudError::AuthFailed(format!("token refresh failed: {e}")));
                    }
                }
            }
        }
        Ok(())
    }

    /// Find or create the backup folder and return its ID.
    async fn ensure_folder(&self) -> Result<String, CloudError> {
        let folder_name = self.remote_path.trim_matches('/');

        // Search for existing folder
        let query = format!(
            "name='{}' and mimeType='application/vnd.google-apps.folder' and trashed=false",
            folder_name
        );

        let response = self
            .client
            .get("https://www.googleapis.com/drive/v3/files")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .query(&[
                ("q", query.as_str()),
                ("spaces", "drive"),
                ("fields", "files(id, name)"),
            ])
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            let result: serde_json::Value = response
                .json()
                .await
                .map_err(|e| CloudError::ConnectionFailed(format!("failed to parse response: {e}")))?;

            if let Some(files) = result.get("files").and_then(|f| f.as_array()) {
                if let Some(first) = files.first() {
                    if let Some(id) = first.get("id").and_then(|i| i.as_str()) {
                        return Ok(id.to_string());
                    }
                }
            }
        }

        // Create folder
        let body = serde_json::json!({
            "name": folder_name,
            "mimeType": "application/vnd.google-apps.folder",
        });

        let response = self
            .client
            .post("https://www.googleapis.com/drive/v3/files")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .header("Content-Type", "application/json")
            .body(body.to_string())
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            let result: serde_json::Value = response
                .json()
                .await
                .map_err(|e| CloudError::ConnectionFailed(format!("failed to parse folder creation response: {e}")))?;

            result
                .get("id")
                .and_then(|i| i.as_str())
                .map(|id| id.to_string())
                .ok_or_else(|| CloudError::UploadFailed("failed to create backup folder".to_string()))
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            Err(CloudError::UploadFailed(format!(
                "failed to create folder with status {status}: {body}"
            )))
        }
    }

    /// Find a file by name in the backup folder.
    async fn find_file_by_name(&self, folder_id: &str, name: &str) -> Option<String> {
        let query = format!(
            "name='{}' and '{}' in parents and trashed=false",
            name, folder_id
        );

        let response = self
            .client
            .get("https://www.googleapis.com/drive/v3/files")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .query(&[
                ("q", query.as_str()),
                ("spaces", "drive"),
                ("fields", "files(id)"),
            ])
            .send()
            .await
            .ok()?;

        if response.status().is_success() {
            let result: serde_json::Value = response.json().await.ok()?;
            result
                .get("files")
                .and_then(|f| f.as_array())?
                .first()?
                .get("id")
                .and_then(|i| i.as_str())
                .map(|id| id.to_string())
        } else {
            None
        }
    }
}

#[async_trait]
impl CloudProvider for GoogleDriveProvider {
    fn name(&self) -> &str {
        "Google Drive"
    }

    async fn test_connection(&self) -> Result<(), CloudError> {
        let response = self
            .client
            .get("https://www.googleapis.com/drive/v3/about")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .query(&[("fields", "user")])
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!(status = %status, body = %body, "Google Drive connection test failed");
            match status.as_u16() {
                401 => Err(CloudError::AuthFailed("invalid access token".to_string())),
                _ => Err(CloudError::ConnectionFailed(format!(
                    "Google Drive returned status {status}"
                ))),
            }
        }
    }

    async fn upload(&self, local_path: &Path, remote_name: &str) -> Result<(), CloudError> {
        let data = tokio::fs::read(local_path)
            .await
            .map_err(|e| CloudError::UploadFailed(format!("failed to read file: {e}")))?;

        let folder_id = self.ensure_folder().await?;

        // Check if file already exists (for overwrite)
        let existing_id = self.find_file_by_name(&folder_id, remote_name).await;

        if let Some(file_id) = existing_id {
            // Update existing file
            let response = self
                .client
                .patch(format!(
                    "https://www.googleapis.com/upload/drive/v3/files/{}?uploadType=media",
                    file_id
                ))
                .header("Authorization", format!("Bearer {}", self.access_token))
                .header("Content-Type", "application/octet-stream")
                .body(data)
                .send()
                .await
                .map_err(|e| CloudError::NetworkError(e.to_string()))?;

            if response.status().is_success() {
                info!(remote = %remote_name, "updated file on Google Drive");
                return Ok(());
            } else {
                let status = response.status();
                let body = response.text().await.unwrap_or_default();
                return Err(CloudError::UploadFailed(format!(
                    "update failed with status {status}: {body}"
                )));
            }
        }

        // Create new file with multipart upload
        let metadata = serde_json::json!({
            "name": remote_name,
            "parents": [folder_id],
        });

        let boundary = "finance_app_boundary";
        let mut body = Vec::new();
        body.extend_from_slice(format!("--{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n").as_bytes());
        body.extend_from_slice(metadata.to_string().as_bytes());
        body.extend_from_slice(format!("\r\n--{boundary}\r\nContent-Type: application/octet-stream\r\n\r\n").as_bytes());
        body.extend_from_slice(&data);
        body.extend_from_slice(format!("\r\n--{boundary}--\r\n").as_bytes());

        let response = self
            .client
            .post("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .header(
                "Content-Type",
                format!("multipart/related; boundary={boundary}"),
            )
            .body(body)
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            info!(remote = %remote_name, "uploaded to Google Drive");
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!(status = %status, body = %body, "Google Drive upload failed");
            Err(CloudError::UploadFailed(format!(
                "upload failed with status {status}: {body}"
            )))
        }
    }

    async fn download(&self, remote_name: &str, local_path: &Path) -> Result<(), CloudError> {
        let folder_id = self.ensure_folder().await?;
        let file_id = self
            .find_file_by_name(&folder_id, remote_name)
            .await
            .ok_or_else(|| {
                CloudError::DownloadFailed(format!("file not found: {remote_name}"))
            })?;

        let response = self
            .client
            .get(format!(
                "https://www.googleapis.com/drive/v3/files/{}?alt=media",
                file_id
            ))
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

            info!(remote = %remote_name, "downloaded from Google Drive");
            Ok(())
        } else {
            let status = response.status();
            Err(CloudError::DownloadFailed(format!(
                "download failed with status {status}"
            )))
        }
    }

    async fn list_backups(&self) -> Result<Vec<CloudBackupInfo>, CloudError> {
        let folder_id = self.ensure_folder().await?;

        let query = format!(
            "'{}' in parents and trashed=false",
            folder_id
        );

        let response = self
            .client
            .get("https://www.googleapis.com/drive/v3/files")
            .header("Authorization", format!("Bearer {}", self.access_token))
            .query(&[
                ("q", query.as_str()),
                ("spaces", "drive"),
                ("fields", "files(id, name, size, modifiedTime)"),
            ])
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(CloudError::ConnectionFailed(format!(
                "list files failed with status {status}: {body}"
            )));
        }

        let result: serde_json::Value = response
            .json()
            .await
            .map_err(|e| CloudError::ConnectionFailed(format!("failed to parse response: {e}")))?;

        let entries = match result.get("files").and_then(|f| f.as_array()) {
            Some(arr) => arr,
            None => return Ok(vec![]),
        };

        let mut backups = Vec::new();
        for entry in entries {
            let name = match entry.get("name").and_then(|n| n.as_str()) {
                Some(n) => n.to_string(),
                None => continue,
            };

            if !name.ends_with(".enc") {
                continue;
            }

            let size = entry
                .get("size")
                .and_then(|s| s.as_str())
                .and_then(|s| s.parse::<u64>().ok())
                .unwrap_or(0);

            let last_modified = entry
                .get("modifiedTime")
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
        let folder_id = self.ensure_folder().await?;
        let file_id = self
            .find_file_by_name(&folder_id, remote_name)
            .await
            .ok_or_else(|| {
                CloudError::UploadFailed(format!("file not found: {remote_name}"))
            })?;

        let response = self
            .client
            .delete(format!(
                "https://www.googleapis.com/drive/v3/files/{}",
                file_id
            ))
            .header("Authorization", format!("Bearer {}", self.access_token))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() {
            info!(remote = %remote_name, "deleted from Google Drive");
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
