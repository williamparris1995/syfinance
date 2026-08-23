package domain

import (
	"encoding/binary"
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

	// v1 KDF parameters (legacy, kept for decrypting existing backups).
	scryptN = 32768 // 2^15
	scryptR = 8
	scryptP = 1

	// v2 self-describing format (D19a): [YC2E 4B][version 1B][N 4B LE]
	// [r 4B LE][p 4B LE][salt 32B][nonce 12B][AES-GCM ct+tag]. OWASP 2024
	// scrypt: N=2^17. Parameters travel in the header so future bumps stay
	// decrypt-compatible.
	magicV2    = "YC2E"
	versionV2  = byte(2)
	v2ScryptN  = 131072 // 2^17
	v2ScryptR  = 8
	v2ScryptP  = 1
	// Bounds guard against hostile/corrupt headers (DoS-class parameters).
	scryptNMin = 1 << 14
	scryptNMax = 1 << 22
	scryptRMin = 1
	scryptRMax = 32
	scryptPMin = 1
	scryptPMax = 8
)

// ErrWrongPassword 表示解密时密码错误(GCM Open 失败或 magic 不符)。
// ErrNotEncrypted 表示数据根本不是加密备份格式(明文数据误送 Decrypt 的调用方 bug)。
var ErrWrongPassword = errors.New("wrong password or corrupted backup")
var ErrNotEncrypted = errors.New("data is not an encrypted backup")

// IsEncrypted 检测 data 是否为加密格式(以 magic 头 "YC1E" 开头)。
func IsEncrypted(data []byte) bool {
	if len(data) < len(magic) {
		return false
	}
	switch string(data[:len(magic)]) {
	case magic, magicV2:
		return true
	}
	return false
}

// Encrypt 用 password(AES-256-GCM,scrypt 派生 key)加密 plaintext。
// Writes the v2 self-describing format (D19a): header carries N/r/p.
func Encrypt(plaintext []byte, password string) ([]byte, error) {
	salt := make([]byte, saltLen)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return nil, err
	}
	key, err := scrypt.Key([]byte(password), salt, v2ScryptN, v2ScryptR, v2ScryptP, keyLen)
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
	// v2 header + ciphertext
	out := make([]byte, 0, len(magicV2)+1+12+saltLen+nonceLen+len(plaintext)+gcm.Overhead())
	out = append(out, magicV2...)
	out = append(out, versionV2)
	out = binary.LittleEndian.AppendUint32(out, uint32(v2ScryptN))
	out = binary.LittleEndian.AppendUint32(out, uint32(v2ScryptR))
	out = binary.LittleEndian.AppendUint32(out, uint32(v2ScryptP))
	out = append(out, salt...)
	out = append(out, nonce...)
	out = gcm.Seal(out, nonce, plaintext, nil)
	return out, nil
}

// Decrypt 用 password 解密 Encrypt 产物。密码错/损坏 → ErrWrongPassword。
func Decrypt(data []byte, password string) ([]byte, error) {
	if len(data) >= len(magicV2) && string(data[:len(magicV2)]) == magicV2 {
		return decryptV2(data, password)
	}
	if len(data) >= len(magic) && string(data[:len(magic)]) == magic {
		return decryptV1(data, password)
	}
	return nil, ErrNotEncrypted // not an encrypted blob at all (caller bug)
}

// decryptV1 reads the legacy framing with hard-coded 2^15 parameters —
// every existing encrypted backup stays decryptable forever (D19a compat).
func decryptV1(data []byte, password string) ([]byte, error) {
	body := data[len(magic):]
	if len(body) < saltLen+nonceLen+16 {
		return nil, ErrWrongPassword // truncated legacy blob: same class as corrupt
	}
	return decryptWithParams(body, password, scryptN, scryptR, scryptP)
}

// decryptV2 reads the self-describing header, validates the KDF bounds,
// then decrypts with the carried parameters.
func decryptV2(data []byte, password string) ([]byte, error) {
	headerLen := len(magicV2) + 1 + 12 // magic + version + 3×uint32
	if len(data) < headerLen+saltLen+nonceLen+16 {
		return nil, ErrWrongPassword
	}
	if data[len(magicV2)] != versionV2 {
		return nil, ErrBackupFormatOutdated
	}
	n := binary.LittleEndian.Uint32(data[5:9])
	r := binary.LittleEndian.Uint32(data[9:13])
	p := binary.LittleEndian.Uint32(data[13:17])
	if n < scryptNMin || n > scryptNMax || r < scryptRMin || r > scryptRMax || p < scryptPMin || p > scryptPMax {
		return nil, ErrBackupFormatOutdated
	}
	// Product cap: worst-case scrypt memory is ~128·N·r bytes — N·r ≤ 2^23
	// keeps that under 1 GiB (review D: independent ranges alone allow 16 GiB).
	if int64(n)*int64(r) > 1<<23 {
		return nil, ErrBackupFormatOutdated
	}
	return decryptWithParams(data[headerLen:], password, int(n), int(r), int(p))
}

func decryptWithParams(data []byte, password string, n, r, p int) ([]byte, error) {
	salt := data[:saltLen]
	nonce := data[saltLen : saltLen+nonceLen]
	ct := data[saltLen+nonceLen:]

	key, err := scrypt.Key([]byte(password), salt, n, r, p, keyLen)
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
	plain, err := gcm.Open(nil, nonce, ct, nil)
	if err != nil {
		return nil, ErrWrongPassword
	}
	return plain, nil
}
