use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use pbkdf2::pbkdf2_hmac;
use sha2::Sha256;
use std::fmt;

const NONCE_SIZE: usize = 12;
const SALT_SIZE: usize = 32;
const KEY_SIZE: usize = 32;
const PBKDF2_ITERATIONS: u32 = 100_000;

#[derive(Debug)]
pub enum EncryptionError {
    EncryptionFailed(String),
    DecryptionFailed(String),
    InvalidData(String),
    KeyDerivationFailed(String),
}

impl fmt::Display for EncryptionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EncryptionFailed(msg) => write!(f, "encryption failed: {}", msg),
            Self::DecryptionFailed(msg) => write!(f, "decryption failed: {}", msg),
            Self::InvalidData(msg) => write!(f, "invalid data: {}", msg),
            Self::KeyDerivationFailed(msg) => write!(f, "key derivation failed: {}", msg),
        }
    }
}

impl std::error::Error for EncryptionError {}

/// 应用层加密服务
/// 使用 AES-256-GCM 加密敏感数据
pub struct EncryptionService {
    master_key: [u8; KEY_SIZE],
}

impl EncryptionService {
    /// 从密码派生主密钥
    pub fn from_password(password: &str, salt: &[u8]) -> Result<Self, EncryptionError> {
        if salt.len() != SALT_SIZE {
            return Err(EncryptionError::KeyDerivationFailed(format!(
                "salt must be {} bytes",
                SALT_SIZE
            )));
        }

        let mut master_key = [0u8; KEY_SIZE];
        pbkdf2_hmac::<Sha256>(
            password.as_bytes(),
            salt,
            PBKDF2_ITERATIONS,
            &mut master_key,
        );

        Ok(Self { master_key })
    }

    /// 生成随机盐
    pub fn generate_salt() -> [u8; SALT_SIZE] {
        use aes_gcm::aead::rand_core::RngCore;
        let mut salt = [0u8; SALT_SIZE];
        OsRng.fill_bytes(&mut salt);
        salt
    }

    /// 加密数据
    /// 返回格式: nonce (12 bytes) + ciphertext
    pub fn encrypt(&self, plaintext: &str) -> Result<Vec<u8>, EncryptionError> {
        let cipher = Aes256Gcm::new_from_slice(&self.master_key)
            .map_err(|e| EncryptionError::EncryptionFailed(e.to_string()))?;

        // 生成随机 nonce
        use aes_gcm::aead::rand_core::RngCore;
        let mut nonce_bytes = [0u8; NONCE_SIZE];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);

        // 加密
        let ciphertext = cipher
            .encrypt(nonce, plaintext.as_bytes())
            .map_err(|e| EncryptionError::EncryptionFailed(e.to_string()))?;

        // 组合 nonce + ciphertext
        let mut result = Vec::with_capacity(NONCE_SIZE + ciphertext.len());
        result.extend_from_slice(&nonce_bytes);
        result.extend_from_slice(&ciphertext);

        Ok(result)
    }

    /// 解密数据
    /// 输入格式: nonce (12 bytes) + ciphertext
    pub fn decrypt(&self, encrypted_data: &[u8]) -> Result<String, EncryptionError> {
        if encrypted_data.len() < NONCE_SIZE {
            return Err(EncryptionError::InvalidData(
                "encrypted data too short".to_string(),
            ));
        }

        let cipher = Aes256Gcm::new_from_slice(&self.master_key)
            .map_err(|e| EncryptionError::DecryptionFailed(e.to_string()))?;

        // 分离 nonce 和 ciphertext
        let (nonce_bytes, ciphertext) = encrypted_data.split_at(NONCE_SIZE);
        let nonce = Nonce::from_slice(nonce_bytes);

        // 解密
        let plaintext = cipher
            .decrypt(nonce, ciphertext)
            .map_err(|e| EncryptionError::DecryptionFailed(e.to_string()))?;

        String::from_utf8(plaintext)
            .map_err(|e| EncryptionError::DecryptionFailed(format!("invalid UTF-8: {}", e)))
    }

    /// 加密并编码为十六进制字符串
    pub fn encrypt_to_hex(&self, plaintext: &str) -> Result<String, EncryptionError> {
        let encrypted = self.encrypt(plaintext)?;
        Ok(hex::encode(encrypted))
    }

    /// 从十六进制字符串解密
    pub fn decrypt_from_hex(&self, hex_string: &str) -> Result<String, EncryptionError> {
        let encrypted = hex::decode(hex_string)
            .map_err(|e| EncryptionError::InvalidData(format!("invalid hex: {}", e)))?;
        self.decrypt(&encrypted)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypt_decrypt() {
        let password = "test_password";
        let salt = EncryptionService::generate_salt();
        let service = EncryptionService::from_password(password, &salt).unwrap();

        let plaintext = "Hello, World!";
        let encrypted = service.encrypt(plaintext).unwrap();
        let decrypted = service.decrypt(&encrypted).unwrap();

        assert_eq!(plaintext, decrypted);
    }

    #[test]
    fn test_encrypt_decrypt_hex() {
        let password = "test_password";
        let salt = EncryptionService::generate_salt();
        let service = EncryptionService::from_password(password, &salt).unwrap();

        let plaintext = "Sensitive data 敏感数据";
        let encrypted_hex = service.encrypt_to_hex(plaintext).unwrap();
        let decrypted = service.decrypt_from_hex(&encrypted_hex).unwrap();

        assert_eq!(plaintext, decrypted);
    }

    #[test]
    fn test_different_passwords_produce_different_keys() {
        let salt = EncryptionService::generate_salt();
        let service1 = EncryptionService::from_password("password1", &salt).unwrap();
        let service2 = EncryptionService::from_password("password2", &salt).unwrap();

        let plaintext = "test";
        let encrypted1 = service1.encrypt(plaintext).unwrap();

        // service2 无法解密 service1 的数据
        assert!(service2.decrypt(&encrypted1).is_err());
    }

    #[test]
    fn test_invalid_data() {
        let password = "test_password";
        let salt = EncryptionService::generate_salt();
        let service = EncryptionService::from_password(password, &salt).unwrap();

        // 数据太短
        assert!(service.decrypt(&[1, 2, 3]).is_err());

        // 无效的十六进制
        assert!(service.decrypt_from_hex("invalid_hex").is_err());
    }
}

