package grpc

import (
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/transaction/application"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
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

// TestParseTransactionTime covers the shared RFC3339 parse used by the
// RecordTransaction and SimpleIncome/Expense/Transfer handlers: empty → nil,
// valid RFC3339 → parsed time, malformed → codes.InvalidArgument.
func TestParseTransactionTime(t *testing.T) {
	// Empty → nil, no error.
	got, err := parseTransactionTime("")
	if err != nil {
		t.Fatalf("empty: unexpected err %v", err)
	}
	if got != nil {
		t.Errorf("empty: got %v, want nil", *got)
	}

	// Valid RFC3339 → parsed.
	want := time.Date(2026, 6, 5, 19, 20, 0, 0, time.UTC)
	got, err = parseTransactionTime("2026-06-05T19:20:00Z")
	if err != nil {
		t.Fatalf("valid: unexpected err %v", err)
	}
	if got == nil || !got.Equal(want) {
		t.Errorf("valid: got %v, want %v", got, want)
	}

	// Malformed → InvalidArgument.
	_, err = parseTransactionTime("not-a-time")
	if err == nil {
		t.Fatal("malformed: expected error, got nil")
	}
	if s, ok := status.FromError(err); !ok || s.Code() != codes.InvalidArgument {
		t.Errorf("malformed: got %v, want codes.InvalidArgument", err)
	}
}
