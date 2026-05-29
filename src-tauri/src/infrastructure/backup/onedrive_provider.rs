use std::path::Path;

use super::cloud_provider::{CloudBackupInfo, CloudError, CloudProvider};

pub struct OneDriveProvider {
    #[allow(dead_code)]
    access_token: String,
    #[allow(dead_code)]
    remote_path: String,
}

impl OneDriveProvider {
    pub fn new(access_token: String, remote_path: String) -> Self {
        Self {
            access_token,
            remote_path,
        }
    }
}

impl CloudProvider for OneDriveProvider {
    fn name(&self) -> &str {
        "OneDrive"
    }

    fn test_connection(&self) -> Result<(), CloudError> {
        Err(CloudError::NotConfigured)
    }

    fn upload(&self, _local_path: &Path, _remote_name: &str) -> Result<(), CloudError> {
        Err(CloudError::NotConfigured)
    }

    fn download(&self, _remote_name: &str, _local_path: &Path) -> Result<(), CloudError> {
        Err(CloudError::NotConfigured)
    }

    fn list_backups(&self) -> Result<Vec<CloudBackupInfo>, CloudError> {
        Err(CloudError::NotConfigured)
    }

    fn delete(&self, _remote_name: &str) -> Result<(), CloudError> {
        Err(CloudError::NotConfigured)
    }
}
