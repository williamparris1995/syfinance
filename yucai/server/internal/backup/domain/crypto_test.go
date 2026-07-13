package domain

import (
	"bytes"
	"testing"
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
