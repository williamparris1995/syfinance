package grpc

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/transaction/application"
)

// TestTxnToProto_TransactionTime covers the handler serialization contract for
// transaction_time: set → RFC3339 string; nil → empty (proto3 default / omitted).
func TestTxnToProto_TransactionTime(t *testing.T) {
	dto := application.TransactionDTO{
		ID:              uuid.New(),
		TransactionDate: time.Date(2026, 6, 5, 0, 0, 0, 0, time.UTC),
		Description:     "txn",
	}

	// Case 1: nil → empty string.
	pb := txnToProto(dto)
	if pb.TransactionTime != "" {
		t.Errorf("nil TransactionTime: proto got %q, want empty", pb.TransactionTime)
	}

	// Case 2: set → RFC3339 round-trip.
	want := time.Date(2026, 6, 5, 19, 20, 0, 0, time.UTC)
	dto.TransactionTime = &want
	pb = txnToProto(dto)
	got, err := time.Parse(time.RFC3339, pb.TransactionTime)
	if err != nil {
		t.Fatalf("parse proto TransactionTime %q: %v", pb.TransactionTime, err)
	}
	if !got.Equal(want) {
		t.Errorf("set TransactionTime: proto got %v, want %v", got, want)
	}
}
