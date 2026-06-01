use std::path::Path;
use std::time::Duration;

use async_trait::async_trait;

use super::cloud_provider::{CloudBackupInfo, CloudError, CloudProvider};

pub struct WebDavProvider {
    client: reqwest::Client,
    base_url: String,
    username: String,
    password: String,
    remote_path: String,
}

impl WebDavProvider {
    pub fn new(base_url: String, username: String, password: String, remote_path: String) -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .unwrap_or_default();

        Self {
            client,
            base_url,
            username,
            password,
            remote_path,
        }
    }

    fn remote_url(&self, remote_name: &str) -> String {
        format!(
            "{}/{}/{}",
            self.base_url.trim_end_matches('/'),
            self.remote_path.trim_matches('/'),
            remote_name
        )
    }

    fn collection_url(&self) -> String {
        format!(
            "{}/{}",
            self.base_url.trim_end_matches('/'),
            self.remote_path.trim_matches('/')
        )
        .trim_end_matches('/')
        .to_string()
            + "/"
    }
}

#[async_trait]
impl CloudProvider for WebDavProvider {
    fn name(&self) -> &str {
        "WebDAV"
    }

    async fn test_connection(&self) -> Result<(), CloudError> {
        let url = self.collection_url();
        let response = self
            .client
            .request(reqwest::Method::from_bytes(b"PROPFIND").unwrap(), &url)
            .header("Depth", "0")
            .basic_auth(&self.username, Some(&self.password))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        match response.status().as_u16() {
            207 => Ok(()),
            401 | 403 => Err(CloudError::AuthFailed("invalid credentials".to_string())),
            status => Err(CloudError::ConnectionFailed(format!(
                "unexpected status {status}"
            ))),
        }
    }

    async fn upload(&self, local_path: &Path, remote_name: &str) -> Result<(), CloudError> {
        let url = self.remote_url(remote_name);
        let data = tokio::fs::read(local_path)
            .await
            .map_err(|e| CloudError::UploadFailed(format!("failed to read file: {e}")))?;

        let response = self
            .client
            .put(&url)
            .basic_auth(&self.username, Some(&self.password))
            .body(data)
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() || response.status().as_u16() == 201 {
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            Err(CloudError::UploadFailed(format!(
                "upload failed with status {status}: {body}"
            )))
        }
    }

    async fn download(&self, remote_name: &str, local_path: &Path) -> Result<(), CloudError> {
        let url = self.remote_url(remote_name);
        let response = self
            .client
            .get(&url)
            .basic_auth(&self.username, Some(&self.password))
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

            Ok(())
        } else {
            let status = response.status();
            Err(CloudError::DownloadFailed(format!(
                "download failed with status {status}"
            )))
        }
    }

    async fn list_backups(&self) -> Result<Vec<CloudBackupInfo>, CloudError> {
        let url = self.collection_url();
        let response = self
            .client
            .request(reqwest::Method::from_bytes(b"PROPFIND").unwrap(), &url)
            .header("Depth", "1")
            .basic_auth(&self.username, Some(&self.password))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().as_u16() != 207 {
            let status = response.status();
            return Err(CloudError::ConnectionFailed(format!(
                "PROPFIND failed with status {status}"
            )));
        }

        let body = response
            .text()
            .await
            .map_err(|e| CloudError::ConnectionFailed(format!("failed to read body: {e}")))?;

        Ok(parse_propfind_response(&body))
    }

    async fn delete(&self, remote_name: &str) -> Result<(), CloudError> {
        let url = self.remote_url(remote_name);
        let response = self
            .client
            .delete(&url)
            .basic_auth(&self.username, Some(&self.password))
            .send()
            .await
            .map_err(|e| CloudError::NetworkError(e.to_string()))?;

        if response.status().is_success() || response.status().as_u16() == 204 {
            Ok(())
        } else {
            let status = response.status();
            Err(CloudError::UploadFailed(format!(
                "delete failed with status {status}"
            )))
        }
    }
}

/// Parse a WebDAV PROPFIND XML response and extract .enc backup files.
fn parse_propfind_response(xml: &str) -> Vec<CloudBackupInfo> {
    let mut backups = Vec::new();

    // Simple XML parsing without full XML parser dependency.
    // Each response entry is in a <d:response> or <response> block.
    for response_block in find_all_elements(xml, "response") {
        let href = match find_element_text(&response_block, "href") {
            Some(h) => h,
            None => continue,
        };

        // Extract filename from href (last path segment)
        let file_name = href
            .trim_end_matches('/')
            .rsplit('/')
            .next()
            .unwrap_or("")
            .to_string();

        // Only include .enc files
        if !file_name.ends_with(".enc") {
            continue;
        }

        let size = find_element_text(&response_block, "getcontentlength")
            .and_then(|s| s.parse::<u64>().ok())
            .unwrap_or(0);

        let last_modified = find_element_text(&response_block, "getlastmodified");

        backups.push(CloudBackupInfo {
            name: file_name,
            size,
            last_modified,
        });
    }

    backups
}

/// Find all occurrences of an XML element and return their inner content.
fn find_all_elements(xml: &str, tag: &str) -> Vec<String> {
    let mut results = Vec::new();

    // Try namespaced tag (d:tag) first, then plain tag
    for prefix in &["d:", "D:", ""] {
        let open = format!("<{prefix}{tag}");
        let close = format!("</{prefix}{tag}>");

        let mut search_from = 0;
        while let Some(start) = xml[search_from..].find(&open) {
            let abs_start = search_from + start;
            // Find end of opening tag (may have xmlns attributes)
            if let Some(tag_end) = xml[abs_start..].find('>') {
                let content_start = abs_start + tag_end + 1;
                if let Some(end) = xml[content_start..].find(&close) {
                    results.push(xml[content_start..content_start + end].to_string());
                    search_from = content_start + end + close.len();
                    continue;
                }
            }
            break;
        }

        if !results.is_empty() {
            return results;
        }
    }

    results
}

/// Find the text content of the first occurrence of an XML element.
fn find_element_text(xml: &str, tag: &str) -> Option<String> {
    for prefix in &["d:", "D:", ""] {
        let open = format!("<{prefix}{tag}");
        let close = format!("</{prefix}{tag}>");

        if let Some(start) = xml.find(&open) {
            if let Some(tag_end) = xml[start..].find('>') {
                let content_start = start + tag_end + 1;
                if let Some(end) = xml[content_start..].find(&close) {
                    return Some(xml[content_start..content_start + end].trim().to_string());
                }
            }
        }
    }
    None
}
