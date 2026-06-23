package repository

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/yucai/server/internal/transaction/domain"
)

// TestScopeRange_DayWindow verifies DAY scope returns [day 00:00, next day 00:00).
func TestScopeRange_DayWindow(t *testing.T) {
	start, end, err := scopeRange(domain.ScopeDay, 2026, 1, intPtr(15))
	require.NoError(t, err)

	wantStart := time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2026, 1, 16, 0, 0, 0, 0, time.UTC)
	assert.True(t, start.Equal(wantStart), "start: got %v want %v", start, wantStart)
	assert.True(t, end.Equal(wantEnd), "end: got %v want %v", end, wantEnd)
}

// TestScopeRange_DayWindow_MonthBoundary verifies DAY scope wraps correctly at
// month end (Jan 31 → Feb 1).
func TestScopeRange_DayWindow_MonthBoundary(t *testing.T) {
	start, end, err := scopeRange(domain.ScopeDay, 2026, 1, intPtr(31))
	require.NoError(t, err)

	wantStart := time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)
	assert.True(t, start.Equal(wantStart))
	assert.True(t, end.Equal(wantEnd))
}

// TestScopeRange_DayWindow_YearBoundary verifies DAY scope wraps at year end
// (Dec 31 2026 → Jan 1 2027).
func TestScopeRange_DayWindow_YearBoundary(t *testing.T) {
	start, end, err := scopeRange(domain.ScopeDay, 2026, 12, intPtr(31))
	require.NoError(t, err)

	wantStart := time.Date(2026, 12, 31, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)
	assert.True(t, start.Equal(wantStart))
	assert.True(t, end.Equal(wantEnd))
}

// TestScopeRange_DayNilGuard verifies DAY scope without a day pointer errors.
func TestScopeRange_DayNilGuard(t *testing.T) {
	_, _, err := scopeRange(domain.ScopeDay, 2026, 1, nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "day")
}

// TestScopeRange_MonthWindow verifies MONTH scope returns
// [month-first 00:00, next-month-first 00:00).
func TestScopeRange_MonthWindow(t *testing.T) {
	start, end, err := scopeRange(domain.ScopeMonth, 2026, 2, nil)
	require.NoError(t, err)

	wantStart := time.Date(2026, 2, 1, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)
	assert.True(t, start.Equal(wantStart))
	assert.True(t, end.Equal(wantEnd))
}

// TestScopeRange_MonthWindow_DecemberWraps verifies MONTH scope Dec → next year.
func TestScopeRange_MonthWindow_DecemberWraps(t *testing.T) {
	start, end, err := scopeRange(domain.ScopeMonth, 2026, 12, nil)
	require.NoError(t, err)

	wantStart := time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)
	assert.True(t, start.Equal(wantStart))
	assert.True(t, end.Equal(wantEnd))
}

// TestScopeRange_MonthInvalid verifies out-of-range month errors.
func TestScopeRange_MonthInvalid(t *testing.T) {
	_, _, err := scopeRange(domain.ScopeMonth, 2026, 0, nil)
	require.Error(t, err)
	_, _, err = scopeRange(domain.ScopeMonth, 2026, 13, nil)
	require.Error(t, err)
}

// TestScopeRange_YearWindow verifies YEAR scope returns
// [Jan 1 year, Jan 1 year+1).
func TestScopeRange_YearWindow(t *testing.T) {
	start, end, err := scopeRange(domain.ScopeYear, 2026, 0, nil)
	require.NoError(t, err)

	wantStart := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2027, 1, 1, 0, 0, 0, 0, time.UTC)
	assert.True(t, start.Equal(wantStart))
	assert.True(t, end.Equal(wantEnd))
}

// TestScopeRange_UnspecifiedDefaultsToMonth verifies Scope zero (UNSPECIFIED)
// behaves like MONTH for backward compatibility.
func TestScopeRange_UnspecifiedDefaultsToMonth(t *testing.T) {
	start, end, err := scopeRange(domain.Scope(0), 2026, 3, nil)
	require.NoError(t, err)

	wantStart := time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)
	wantEnd := time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC)
	assert.True(t, start.Equal(wantStart))
	assert.True(t, end.Equal(wantEnd))
}

// intPtr returns a pointer to v (test helper).
func intPtr(v int) *int { return &v }
