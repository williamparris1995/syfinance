package grpc

import (
	"testing"

	pb "github.com/yucai/server/internal/proto/transaction/v1"
	"github.com/yucai/server/internal/transaction/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// TestResolveSummaryScope covers the proto→domain mapping + validation done by
// the TransactionSummary handler before it calls the service:
//   - SCOPE_UNSPECIFIED defaults to MONTH (no error)
//   - SCOPE_DAY requires day ∈ [1,31] (0/missing or out-of-range → InvalidArgument)
//   - SCOPE_MONTH / SCOPE_YEAR ignore day
//   - numbering is 1:1 with domain.Scope (no translation table)
func TestResolveSummaryScope(t *testing.T) {
	t.Run("UNSPECIFIED defaults to MONTH", func(t *testing.T) {
		scope, day, err := resolveSummaryScope(pb.Scope_SCOPE_UNSPECIFIED, 0)
		if err != nil {
			t.Fatalf("unexpected err %v", err)
		}
		if scope != domain.ScopeMonth {
			t.Errorf("scope: got %d, want ScopeMonth(%d)", scope, domain.ScopeMonth)
		}
		if day != nil {
			t.Errorf("day: got %v, want nil (UNSPECIFIED ignores day)", day)
		}
	})

	t.Run("MONTH ignores day", func(t *testing.T) {
		scope, day, err := resolveSummaryScope(pb.Scope_SCOPE_MONTH, 15)
		if err != nil {
			t.Fatalf("unexpected err %v", err)
		}
		if scope != domain.ScopeMonth {
			t.Errorf("scope: got %d, want ScopeMonth(%d)", scope, domain.ScopeMonth)
		}
		if day != nil {
			t.Errorf("day: got %v, want nil (MONTH ignores day)", day)
		}
	})

	t.Run("YEAR ignores day", func(t *testing.T) {
		scope, day, err := resolveSummaryScope(pb.Scope_SCOPE_YEAR, 0)
		if err != nil {
			t.Fatalf("unexpected err %v", err)
		}
		if scope != domain.ScopeYear {
			t.Errorf("scope: got %d, want ScopeYear(%d)", scope, domain.ScopeYear)
		}
		if day != nil {
			t.Errorf("day: got %v, want nil (YEAR ignores day)", day)
		}
	})

	t.Run("DAY with valid day", func(t *testing.T) {
		scope, day, err := resolveSummaryScope(pb.Scope_SCOPE_DAY, 12)
		if err != nil {
			t.Fatalf("unexpected err %v", err)
		}
		if scope != domain.ScopeDay {
			t.Errorf("scope: got %d, want ScopeDay(%d)", scope, domain.ScopeDay)
		}
		if day == nil || *day != 12 {
			t.Errorf("day: got %v, want 12", day)
		}
	})

	t.Run("DAY with day at lower bound 1", func(t *testing.T) {
		_, day, err := resolveSummaryScope(pb.Scope_SCOPE_DAY, 1)
		if err != nil {
			t.Fatalf("unexpected err %v", err)
		}
		if day == nil || *day != 1 {
			t.Errorf("day: got %v, want 1", day)
		}
	})

	t.Run("DAY with day at upper bound 31", func(t *testing.T) {
		_, day, err := resolveSummaryScope(pb.Scope_SCOPE_DAY, 31)
		if err != nil {
			t.Fatalf("unexpected err %v", err)
		}
		if day == nil || *day != 31 {
			t.Errorf("day: got %v, want 31", day)
		}
	})

	t.Run("DAY with missing day (0) is InvalidArgument", func(t *testing.T) {
		_, _, err := resolveSummaryScope(pb.Scope_SCOPE_DAY, 0)
		if err == nil {
			t.Fatal("missing day: expected error, got nil")
		}
		if s, ok := status.FromError(err); !ok || s.Code() != codes.InvalidArgument {
			t.Errorf("missing day: got %v, want codes.InvalidArgument", err)
		}
	})

	t.Run("DAY with day below 1 is InvalidArgument", func(t *testing.T) {
		_, _, err := resolveSummaryScope(pb.Scope_SCOPE_DAY, -1)
		if err == nil {
			t.Fatal("day=-1: expected error, got nil")
		}
		if s, ok := status.FromError(err); !ok || s.Code() != codes.InvalidArgument {
			t.Errorf("day=-1: got %v, want codes.InvalidArgument", err)
		}
	})

	t.Run("DAY with day above 31 is InvalidArgument", func(t *testing.T) {
		_, _, err := resolveSummaryScope(pb.Scope_SCOPE_DAY, 32)
		if err == nil {
			t.Fatal("day=32: expected error, got nil")
		}
		if s, ok := status.FromError(err); !ok || s.Code() != codes.InvalidArgument {
			t.Errorf("day=32: got %v, want codes.InvalidArgument", err)
		}
	})
}
