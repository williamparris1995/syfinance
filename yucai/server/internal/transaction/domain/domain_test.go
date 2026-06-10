package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestDoubleEntryValidator_Valid(t *testing.T) {
	entries := []TransactionEntry{
		{ID: uuid.New(), AccountID: uuid.New(), DebitCents: 1000},
		{ID: uuid.New(), AccountID: uuid.New(), CreditCents: 1000},
	}
	validator := DoubleEntryValidator{}
	if err := validator.Validate(entries); err != nil {
		t.Fatalf("valid entries should pass: %v", err)
	}
}

func TestDoubleEntryValidator_Unbalanced(t *testing.T) {
	entries := []TransactionEntry{
		{ID: uuid.New(), AccountID: uuid.New(), DebitCents: 1000},
		{ID: uuid.New(), AccountID: uuid.New(), CreditCents: 500},
	}
	validator := DoubleEntryValidator{}
	if err := validator.Validate(entries); err == nil {
		t.Error("unbalanced entries should fail")
	}
}

func TestDoubleEntryValidator_BothDebitAndCredit(t *testing.T) {
	entries := []TransactionEntry{
		{ID: uuid.New(), AccountID: uuid.New(), DebitCents: 500, CreditCents: 500},
	}
	validator := DoubleEntryValidator{}
	if err := validator.Validate(entries); err == nil {
		t.Error("entry with both debit and credit should fail")
	}
}

func TestDoubleEntryValidator_ZeroEntry(t *testing.T) {
	entries := []TransactionEntry{
		{ID: uuid.New(), AccountID: uuid.New(), DebitCents: 0, CreditCents: 0},
	}
	validator := DoubleEntryValidator{}
	if err := validator.Validate(entries); err == nil {
		t.Error("zero entry should fail")
	}
}

func TestNewTransaction_Valid(t *testing.T) {
	entries := []TransactionEntry{
		{AccountID: uuid.New(), DebitCents: 1000},
		{AccountID: uuid.New(), CreditCents: 1000},
	}
	txn, err := NewTransaction(uuid.New(), time.Now(), "Test", entries)
	if err != nil {
		t.Fatalf("NewTransaction failed: %v", err)
	}
	if txn.Version != 1 {
		t.Errorf("expected version 1, got %d", txn.Version)
	}
	if len(txn.Entries) != 2 {
		t.Errorf("expected 2 entries, got %d", len(txn.Entries))
	}
}

func TestNewTransaction_SingleEntry(t *testing.T) {
	entries := []TransactionEntry{
		{AccountID: uuid.New(), DebitCents: 1000},
	}
	_, err := NewTransaction(uuid.New(), time.Now(), "Test", entries)
	if err == nil {
		t.Error("single entry should fail")
	}
}

func TestNewTransaction_Unbalanced(t *testing.T) {
	entries := []TransactionEntry{
		{AccountID: uuid.New(), DebitCents: 1000},
		{AccountID: uuid.New(), CreditCents: 500},
	}
	_, err := NewTransaction(uuid.New(), time.Now(), "Test", entries)
	if err == nil {
		t.Error("unbalanced should fail")
	}
}
