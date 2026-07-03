package domain

import (
	"time"

	"github.com/google/uuid"
)

// DebtProgressSnapshot captures a debt's progress at a point in time. Snapshots
// are written periodically (and on payment events) so progress charts and
// "paid this month" queries read a precomputed row instead of replaying the
// schedule. TenantID is denormalized for tenant-scoped range queries without a
// join back to DebtDetails.
type DebtProgressSnapshot struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	DebtID              uuid.UUID
	SnapshotDate        time.Time
	TotalPrincipalCents int64
	RemainingCents      int64
	PaidTotalCents      int64
	CreatedAt           time.Time
}
