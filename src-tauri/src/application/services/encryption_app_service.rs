use crate::infrastructure::encryption::{EncryptionError, EncryptionService};
use keyring::Entry;
use sqlx::SqlitePool;
use std::sync::Mutex;

const KEYRING_SERVICE: &str = "finance-app";
const KEYRING_USERNAME: &str = "encryption-key";

#[derive(Debug, thiserror::Error)]
pub enum EncryptionAppError {
    #[error("encryption not enabled")]
    NotEnabled,
    #[error("encryption already enabled")]
    AlreadyEnabled,
    #[error("encryption locked")]
    // TODO: will be used when field-level encryption guard is added
    #[allow(dead_code)]
    Locked,
    #[error("invalid password")]
    InvalidPassword,
    #[error("keychain error: {0}")]
    KeychainError(String),
    #[error("database error: {0}")]
    DatabaseError(String),
    #[error("encryption error: {0}")]
    EncryptionError(#[from] EncryptionError),
}

pub struct EncryptionAppService {
    pool: SqlitePool,
    service: Mutex<Option<EncryptionService>>,
}

impl EncryptionAppService {
    const VERIFICATION_PAYLOAD: &str = "finance-app-encryption-verified-2026";

    pub fn new(pool: SqlitePool) -> Self {
        Self {
            pool,
            service: Mutex::new(None),
        }
    }

    pub async fn is_enabled(&self) -> Result<bool, EncryptionAppError> {
        let result = sqlx::query_as::<_, (String,)>("SELECT salt FROM encryption_settings LIMIT 1")
            .fetch_optional(&self.pool)
            .await
            .map_err(|e| EncryptionAppError::DatabaseError(e.to_string()))?;

        Ok(result.is_some())
    }

    pub fn is_unlocked(&self) -> bool {
        self.service.lock().unwrap().is_some()
    }

    pub async fn setup(&self, password: &str) -> Result<(), EncryptionAppError> {
        if self.is_enabled().await? {
            return Err(EncryptionAppError::AlreadyEnabled);
        }

        let salt = EncryptionService::generate_salt();
        let service = EncryptionService::from_password(password, &salt)?;

        let salt_hex = hex::encode(salt);
        sqlx::query(
            "INSERT INTO encryption_settings (salt, created_at) VALUES (?, datetime('now'))",
        )
        .bind(&salt_hex)
        .execute(&self.pool)
        .await
        .map_err(|e| EncryptionAppError::DatabaseError(e.to_string()))?;

        // Store master key in OS keychain
        let key_hex = hex::encode(service.master_key());
        let entry = Entry::new(KEYRING_SERVICE, KEYRING_USERNAME)
            .map_err(|e| EncryptionAppError::KeychainError(e.to_string()))?;
        entry
            .set_password(&key_hex)
            .map_err(|e| EncryptionAppError::KeychainError(e.to_string()))?;

        *self.service.lock().unwrap() = Some(service);

        // Store verification token for password verification on unlock
        let verification_token = self
            .service
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .encrypt_to_hex(Self::VERIFICATION_PAYLOAD)
            .map_err(EncryptionAppError::EncryptionError)?;

        sqlx::query("UPDATE encryption_settings SET verification_token = ?")
            .bind(&verification_token)
            .execute(&self.pool)
            .await
            .map_err(|e| EncryptionAppError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    pub async fn unlock(&self, password: &str) -> Result<(), EncryptionAppError> {
        let row = sqlx::query_as::<_, (String, Option<String>)>(
            "SELECT salt, verification_token FROM encryption_settings LIMIT 1",
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| EncryptionAppError::DatabaseError(e.to_string()))?
        .ok_or(EncryptionAppError::NotEnabled)?;

        let salt = hex::decode(&row.0)
            .map_err(|e| EncryptionAppError::DatabaseError(format!("invalid salt: {}", e)))?;
        let service = EncryptionService::from_password(password, &salt)?;

        // Verify password by decrypting the verification token
        if let Some(token) = row.1 {
            service
                .decrypt_from_hex(&token)
                .map_err(|_| EncryptionAppError::InvalidPassword)?;
        }

        *self.service.lock().unwrap() = Some(service);
        Ok(())
    }

    pub async fn unlock_with_keychain(&self) -> Result<(), EncryptionAppError> {
        let is_enabled = self.is_enabled().await?;
        if !is_enabled {
            return Err(EncryptionAppError::NotEnabled);
        }

        let entry = Entry::new(KEYRING_SERVICE, KEYRING_USERNAME)
            .map_err(|e| EncryptionAppError::KeychainError(e.to_string()))?;
        let key_hex = entry
            .get_password()
            .map_err(|e| EncryptionAppError::KeychainError(e.to_string()))?;

        let key_bytes = hex::decode(&key_hex)
            .map_err(|e| EncryptionAppError::KeychainError(format!("invalid key: {}", e)))?;

        let key: [u8; 32] = key_bytes
            .try_into()
            .map_err(|_| EncryptionAppError::KeychainError("invalid key length".to_string()))?;

        let service = EncryptionService::from_key(key);
        *self.service.lock().unwrap() = Some(service);
        Ok(())
    }

    pub fn lock(&self) -> Result<(), EncryptionAppError> {
        *self.service.lock().unwrap() = None;
        Ok(())
    }

    pub async fn disable(&self, password: &str) -> Result<(), EncryptionAppError> {
        self.unlock(password).await?;

        // Delete from keychain
        let entry = Entry::new(KEYRING_SERVICE, KEYRING_USERNAME)
            .map_err(|e| EncryptionAppError::KeychainError(e.to_string()))?;
        let _ = entry.delete_password();

        // Delete from database
        sqlx::query("DELETE FROM encryption_settings")
            .execute(&self.pool)
            .await
            .map_err(|e| EncryptionAppError::DatabaseError(e.to_string()))?;

        *self.service.lock().unwrap() = None;
        Ok(())
    }

    // TODO: will be used when field-level encryption is implemented
    #[allow(dead_code)]
    pub fn encrypt_field(&self, plaintext: &str) -> Result<String, EncryptionAppError> {
        let guard = self.service.lock().unwrap();
        let service = guard.as_ref().ok_or(EncryptionAppError::Locked)?;
        Ok(service.encrypt_to_hex(plaintext)?)
    }

    // TODO: will be used when field-level encryption is implemented
    #[allow(dead_code)]
    pub fn decrypt_field(&self, hex_ciphertext: &str) -> Result<String, EncryptionAppError> {
        let guard = self.service.lock().unwrap();
        let service = guard.as_ref().ok_or(EncryptionAppError::Locked)?;
        Ok(service.decrypt_from_hex(hex_ciphertext)?)
    }

    /// Return a cloned `EncryptionService` if encryption is unlocked, or `None`.
    pub fn get_encryption_service(&self) -> Option<EncryptionService> {
        let guard = self.service.lock().unwrap();
        guard
            .as_ref()
            .map(|svc| EncryptionService::from_key(*svc.master_key()))
    }
}
