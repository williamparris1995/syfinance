package application

import (
	"testing"

	"github.com/google/uuid"
	"time"

)

// TestRestoreFreezeLifecycle: Acquire freezes, release unfreezes (idempotent).
func TestRestoreFreezeLifecycle(t *testing.T) {
	f := NewRestoreFreeze()
	tid := uuid.New()

	if f.IsFrozen(tid) {
		t.Fatal("fresh freeze table must not report frozen")
	}
	release := f.Acquire(tid)
	if !f.IsFrozen(tid) {
		t.Fatal("Acquire must freeze")
	}
	release()
	release() // idempotent
	if f.IsFrozen(tid) {
		t.Fatal("release must unfreeze")
	}
}

// TestRestoreFreezeSerializesSameTenant: a second Acquire blocks until the
// first releases (D12 FR-1). The first release happens in the goroutine's
// shadow: main holds acquire1, watches acquire2 stall, then releases and
// observes acquire2 complete — no channel cycles that can deadlock the test.
func TestRestoreFreezeSerializesSameTenant(t *testing.T) {
	f := NewRestoreFreeze()
	tid := uuid.New()

	release1 := f.Acquire(tid)
	acquired2 := make(chan struct{})
	go func() {
		release2 := f.Acquire(tid) // must block until release1
		close(acquired2)
		release2()
	}()

	select {
	case <-acquired2:
		t.Fatal("second Acquire must block while first holds")
	case <-time.After(50 * time.Millisecond):
	}

	release1()
	select {
	case <-acquired2:
	case <-time.After(5 * time.Second):
		t.Fatal("second Acquire must complete after the first releases")
	}
	if f.IsFrozen(tid) {
		t.Fatal("all releases done → tenant must be unfrozen")
	}
}

// TestRestoreFreezeParallelTenants: different tenants don't block each other.
func TestRestoreFreezeParallelTenants(t *testing.T) {
	f := NewRestoreFreeze()
	a, b := uuid.New(), uuid.New()

	releaseA := f.Acquire(a)
	done := make(chan struct{})
	go func() {
		releaseB := f.Acquire(b)
		close(done)
		releaseB()
	}()
	<-done // must not block
	releaseA()
}

func waitOrTimeout(ms int) <-chan time.Time {
	return time.After(time.Duration(ms) * time.Millisecond)
}
