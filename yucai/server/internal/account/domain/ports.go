package domain

import (
	"context"

	"github.com/google/uuid"
)

// AccountReferenceSource counts how many of the implementing module's
// live records reference a given account. Implemented structurally by the
// consumer-module repositories (transaction / budget / debt / holding /
// goal / template) and wired at the composition root — account does not
// import those modules, and they do not import account (the port pattern,
// mirrored from goal's AccountBalanceSource with the direction reversed:
// here account consumes reference counts the others produce).
//
// Count semantics: number of non-soft-deleted PARENT records referencing
// the account (e.g. transactions having an entry on it), so DeleteAccount
// errors read "referenced by 3 transaction record(s)".
type AccountReferenceSource interface {
	CountAccountReferences(ctx context.Context, tenantID, accountID uuid.UUID) (int64, error)
	// AccountReferenceSourceName labels the module in DeleteAccount errors,
	// e.g. "transaction". Pure function of the implementation.
	AccountReferenceSourceName() string
}
