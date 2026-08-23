package application

import (
	"sync"

	"github.com/google/uuid"
)

// RestoreFreeze serializes per-tenant restores and exposes the frozen flag
// consumed by the write interceptor and the schedulers (D12 three-piece).
// Process-local by design: yucai runs a single server, so no DB-level or
// cross-process lock is needed (audit 04 decision 3).
//
// The flag and the per-tenant mutex live in one struct so their lifecycle
// cannot diverge: Acquire sets the flag under the tenant lock, the returned
// release clears it and unlocks — including on the panic path via defer.
type RestoreFreeze struct {
	mu     sync.Mutex
	frozen map[uuid.UUID]bool
	locks  map[uuid.UUID]*sync.Mutex
}

// NewRestoreFreeze builds an empty freeze table.
func NewRestoreFreeze() *RestoreFreeze {
	return &RestoreFreeze{
		frozen: make(map[uuid.UUID]bool),
		locks:  make(map[uuid.UUID]*sync.Mutex),
	}
}

// Acquire serializes same-tenant restores (BLOCKING: a second restore waits
// for the first to finish — the "reject" semantics belong to the write RPC
// interceptor, not here) and freezes the tenant for user writes and
// scheduler ticks. The returned release must be deferred by the caller.
func (f *RestoreFreeze) Acquire(tenantID uuid.UUID) func() {
	lk := f.lockFor(tenantID)
	lk.Lock() // blocks until a prior restore for this tenant finishes

	f.mu.Lock()
	f.frozen[tenantID] = true
	f.mu.Unlock()

	var once sync.Once
	return func() {
		once.Do(func() {
			f.mu.Lock()
			delete(f.frozen, tenantID)
			f.mu.Unlock()
			lk.Unlock()
		})
	}
}

// IsFrozen reports whether a restore is currently in progress for the
// tenant. Safe for concurrent use; the hot path is a single map read under
// a short lock.
func (f *RestoreFreeze) IsFrozen(tenantID uuid.UUID) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.frozen[tenantID]
}

func (f *RestoreFreeze) lockFor(tenantID uuid.UUID) *sync.Mutex {
	f.mu.Lock()
	defer f.mu.Unlock()
	lk, ok := f.locks[tenantID]
	if !ok {
		lk = &sync.Mutex{}
		f.locks[tenantID] = lk
	}
	return lk
}
