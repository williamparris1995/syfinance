package domain

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"errors"
	"io"

	"golang.org/x/crypto/scrypt"
)

// 文件格式(加密): [magic "YC1E" 4B][salt 32B][nonce 12B][AES-GCM ciphertext + 16B tag]
const (
	magic    = "YC1E"
	saltLen  = 32
	nonceLen = 12
	keyLen   = 32 // AES-256
	scryptN  = 32768
	scryptR  = 8
	scryptP  = 1
)

// ErrWrongPassword 表示解密时密码错误(GCM Open 失败或 magic 不符)。
var ErrWrongPassword = errors.New("wrong password or corrupted backup")

// IsEncrypted 检测 data 是否为加密格式(以 magic 头 "YC1E" 开头)。
func IsEncrypted(data []byte) bool {
	return len(data) >= len(magic) && string(data[:len(magic)]) == magic
}

// Encrypt 用 password(AES-256-GCM,scrypt 派生 key)加密 plaintext。
func Encrypt(plaintext []byte, password string) ([]byte, error) {
	salt := make([]byte, saltLen)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return nil, err
	}
	key, err := scrypt.Key([]byte(password), salt, scryptN, scryptR, scryptP, keyLen)
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, nonceLen)
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	// header + ciphertext
	out := make([]byte, 0, len(magic)+saltLen+nonceLen+len(plaintext)+gcm.Overhead())
	out = append(out, magic...)
	out = append(out, salt...)
	out = append(out, nonce...)
	out = gcm.Seal(out, nonce, plaintext, nil)
	return out, nil
}

// Decrypt 用 password 解密 Encrypt 产物。密码错/损坏 → ErrWrongPassword。
func Decrypt(data []byte, password string) ([]byte, error) {
	if !IsEncrypted(data) {
		return nil, ErrWrongPassword
	}
	if len(data) < len(magic)+saltLen+nonceLen {
		return nil, ErrWrongPassword
	}
	off := len(magic)
	salt := data[off : off+saltLen]
	off += saltLen
	nonce := data[off : off+nonceLen]
	off += nonceLen
	ciphertext := data[off:]
	key, err := scrypt.Key([]byte(password), salt, scryptN, scryptR, scryptP, keyLen)
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	pt, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, ErrWrongPassword
	}
	return pt, nil
}
