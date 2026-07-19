package application

import (
	"testing"
	"time"
)

func TestSetNowInjectsFixedClock(t *testing.T) {
	fixed := time.Date(2021, 1, 1, 0, 0, 0, 0, time.UTC)
	svc := NewService(nil, nil, nil)
	svc.SetNow(func() time.Time { return fixed })
	if got := svc.now(); !got.Equal(fixed) {
		t.Errorf("SetNow: got %v, want %v", got, fixed)
	}
}

func TestNewServiceDefaultsToTimeNow(t *testing.T) {
	svc := NewService(nil, nil, nil)
	before := time.Now()
	got := svc.now()
	after := time.Now()
	if got.Before(before) || got.After(after) {
		t.Errorf("default now: got %v, want within [%v, %v]", got, before, after)
	}
}
