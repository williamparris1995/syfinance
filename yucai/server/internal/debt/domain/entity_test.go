package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewDebtDetailsWithContactContractCollection(t *testing.T) {
	tid, aid := uuid.New(), uuid.New()
	coll := uuid.New()
	dl := time.Now().Add(30 * 24 * time.Hour)

	// receivable (borrowedOut) with contact/contract/collection
	d, err := NewDebtDetails(tid, aid, "李四", 8.0, AmortizationEqualPrincipalInterest,
		time.Now(), dl, 1000000, BorrowedOut, "business",
		"138****6677", "BO-2026-0215.pdf", &coll)
	if err != nil || d.Contact != "138****6677" || d.ContractRef != "BO-2026-0215.pdf" || *d.CollectionAccountID != coll {
		t.Fatalf("receivable: err=%v d=%+v", err, d)
	}

	// borrowIn with empty (nil collection) OK
	d2, err := NewDebtDetails(tid, aid, "房贷", 4.5, AmortizationEqualPrincipalInterest,
		time.Now(), dl, 5000000, BorrowedIn, "",
		"", "", nil)
	if err != nil || d2.Contact != "" || d2.CollectionAccountID != nil {
		t.Fatalf("borrowIn: err=%v d2=%+v", err, d2)
	}
}
