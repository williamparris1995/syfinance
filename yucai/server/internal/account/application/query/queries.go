package query

import (
	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
)

// GetAccountQuery retrieves a single account.
type GetAccountQuery struct {
	AccountID uuid.UUID
	TenantID  uuid.UUID
}

// ListAccountsQuery retrieves a paginated list of accounts.
type ListAccountsQuery struct {
	TenantID    uuid.UUID
	Filter      domain.AccountFilter
	PageRequest domain.PageRequest
}
