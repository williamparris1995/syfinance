package password

import (
	"testing"
)

func TestHashAndCheck(t *testing.T) {
	password := "mySecurePassword123!"
	hash, err := HashPassword(password)
	if err != nil {
		t.Fatalf("HashPassword failed: %v", err)
	}
	if hash == "" {
		t.Error("hash should not be empty")
	}
	if hash == password {
		t.Error("hash should differ from plaintext")
	}
	if !CheckPassword(password, hash) {
		t.Error("CheckPassword should return true for correct password")
	}
	if CheckPassword("wrongPassword", hash) {
		t.Error("CheckPassword should return false for incorrect password")
	}
}
