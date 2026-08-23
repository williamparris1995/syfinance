package domain

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/binary"
	"testing"

	"golang.org/x/crypto/scrypt"
)

func TestEncryptDecryptRoundtrip(t *testing.T) {
	plaintext := []byte(`{"hello":"御财 backup","n":42}`)
	ct, err := Encrypt(plaintext, "p@ssw0rd")
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	if !IsEncrypted(ct) {
		t.Fatal("IsEncrypted should be true for ciphertext")
	}
	pt, err := Decrypt(ct, "p@ssw0rd")
	if err != nil {
		t.Fatalf("Decrypt: %v", err)
	}
	if !bytes.Equal(pt, plaintext) {
		t.Fatalf("roundtrip mismatch: got %q want %q", pt, plaintext)
	}
}

func TestDecryptWrongPassword(t *testing.T) {
	ct, _ := Encrypt([]byte("secret"), "right")
	_, err := Decrypt(ct, "wrong")
	if err != ErrWrongPassword {
		t.Fatalf("expected ErrWrongPassword, got %v", err)
	}
}

func TestEncryptRandomSaltNonce(t *testing.T) {
	ct1, _ := Encrypt([]byte("same"), "pw")
	ct2, _ := Encrypt([]byte("same"), "pw")
	if bytes.Equal(ct1, ct2) {
		t.Fatal("same plaintext+password should produce different ciphertext (random salt/nonce)")
	}
}

func TestIsEncryptedPlaintext(t *testing.T) {
	if IsEncrypted([]byte(`{"not":"encrypted"}`)) {
		t.Fatal("plain JSON should not be detected as encrypted")
	}
}

// --- D19a v2 KDF header (R5 feature D) ---

// TestEncryptV2Format: new Encrypt output carries the YC2E magic and a
// self-describing header whose parameters match the v2 defaults.
func TestEncryptV2Format(t *testing.T) {
	sealed, err := Encrypt([]byte("payload"), "pw")
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	if string(sealed[:4]) != "YC2E" {
		t.Fatalf("magic = %q, want YC2E", sealed[:4])
	}
	if sealed[4] != 2 {
		t.Fatalf("version = %d, want 2", sealed[4])
	}
	n := binary.LittleEndian.Uint32(sealed[5:9])
	r := binary.LittleEndian.Uint32(sealed[9:13])
	p := binary.LittleEndian.Uint32(sealed[13:17])
	if n != 131072 || r != 8 || p != 1 {
		t.Fatalf("header params N=%d r=%d p=%d, want 131072/8/1", n, r, p)
	}
}

// TestV2RoundTrip: Decrypt inverts Encrypt (v2).
func TestV2RoundTrip(t *testing.T) {
	sealed, err := Encrypt([]byte("hello v2"), "pw")
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}
	plain, err := Decrypt(sealed, "pw")
	if err != nil {
		t.Fatalf("Decrypt: %v", err)
	}
	if string(plain) != "hello v2" {
		t.Fatalf("plain = %q", plain)
	}
	if _, err := Decrypt(sealed, "wrong"); err == nil {
		t.Fatal("wrong password must fail")
	}
}

// TestV1LegacyStillDecrypts: a hand-built v1 blob (2^15 params) — the
// format every existing encrypted backup uses — must decrypt forever.
func TestV1LegacyStillDecrypts(t *testing.T) {
	plain, err := decryptV1(v1Blob(t), "legacy-pw")
	if err != nil {
		t.Fatalf("decryptV1: %v", err)
	}
	if string(plain) != "legacy payload" {
		t.Fatalf("plain = %q", plain)
	}
}

// v1Blob builds a legacy-format blob with the old N=2^15 parameters
// (Encrypt now writes v2, so v1 must be constructed directly).
func v1Blob(t *testing.T) []byte {
	t.Helper()
	salt := make([]byte, 32)
	nonce := make([]byte, 12)
	key, err := scrypt.Key([]byte("legacy-pw"), salt, 32768, 8, 1, 32)
	if err != nil {
		t.Fatalf("scrypt: %v", err)
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatalf("aes: %v", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		t.Fatalf("gcm: %v", err)
	}
	out := append([]byte("YC1E"), salt...)
	out = append(out, nonce...)
	return gcm.Seal(out, nonce, []byte("legacy payload"), nil)
}

// TestV2BoundsRejectHostileParams: out-of-range header parameters are
// rejected as format errors, not fed to scrypt (DoS guard).
func TestV2BoundsRejectHostileParams(t *testing.T) {
	sealed, _ := Encrypt([]byte("x"), "pw")
	// Corrupt N to 2^30 (out of bounds).
	binary.LittleEndian.PutUint32(sealed[5:9], 1<<30)
	if _, err := Decrypt(sealed, "pw"); err == nil {
		t.Fatal("hostile N must be rejected")
	}
	// Corrupt r to 0.
	binary.LittleEndian.PutUint32(sealed[9:13], 0)
	if _, err := Decrypt(sealed, "pw"); err == nil {
		t.Fatal("hostile r must be rejected")
	}
}
