package grpc

import (
	"testing"

	pb "github.com/yucai/server/internal/proto/debt/v1"
	"github.com/yucai/server/internal/debt/application"
	"github.com/yucai/server/internal/debt/domain"
)

// TestProtoDebtTypeMapping verifies the NAME-BASED mapping between the proto
// DebtType enum and the domain DebtType enum (not by numeric coincidence).
func TestProtoDebtTypeMapping(t *testing.T) {
	cases := []struct {
		proto pb.DebtType
		dom   domain.DebtType
	}{
		{pb.DebtType_DEBT_TYPE_BORROWED_IN, domain.BorrowedIn},
		{pb.DebtType_DEBT_TYPE_BORROWED_OUT, domain.BorrowedOut},
		// UNSPECIFIED / unknown resolve to BorrowedIn (matches ent default).
		{pb.DebtType_DEBT_TYPE_UNSPECIFIED, domain.BorrowedIn},
	}
	for _, c := range cases {
		if got := protoToDebtType(c.proto); got != c.dom {
			t.Errorf("protoToDebtType(%v) = %v, want %v", c.proto, got, c.dom)
		}
	}

	// Reverse direction: domain -> proto.
	for _, c := range cases {
		// UNSPECIFIED is not a distinct proto value; skip it for the reverse check.
		if c.proto == pb.DebtType_DEBT_TYPE_UNSPECIFIED {
			continue
		}
		if got := debtTypeToProto(c.dom); got != c.proto {
			t.Errorf("debtTypeToProto(%v) = %v, want %v", c.dom, got, c.proto)
		}
	}

	// Domain unspecified maps to BORROWED_IN on the way out.
	if got := debtTypeToProto(domain.DebtTypeUnspecified); got != pb.DebtType_DEBT_TYPE_BORROWED_IN {
		t.Errorf("debtTypeToProto(Unspecified) = %v, want BORROWED_IN", got)
	}
}

// TestDebtToProto_EmitsDebtType checks debtToProto carries the DebtType through.
func TestDebtToProto_EmitsDebtType(t *testing.T) {
	dto := application.DebtDTO{DebtType: domain.BorrowedOut}
	p := debtToProto(dto)
	if p.DebtType != pb.DebtType_DEBT_TYPE_BORROWED_OUT {
		t.Errorf("debtToProto DebtType = %v, want BORROWED_OUT", p.DebtType)
	}

	dto.DebtType = domain.BorrowedIn
	p = debtToProto(dto)
	if p.DebtType != pb.DebtType_DEBT_TYPE_BORROWED_IN {
		t.Errorf("debtToProto DebtType = %v, want BORROWED_IN", p.DebtType)
	}
}
