package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/application/command"
	"github.com/yucai/server/internal/account/application/query"
	"github.com/yucai/server/internal/account/domain"
)

// Service orchestrates account operations.
type Service struct {
	accountRepo domain.AccountRepository
	chartRepo   domain.ChartRepository
}

// NewService creates a new account application service.
func NewService(accountRepo domain.AccountRepository, chartRepo domain.ChartRepository) *Service {
	return &Service{accountRepo: accountRepo, chartRepo: chartRepo}
}

// CreateAccount creates a new account and returns its DTO.
func (s *Service) CreateAccount(ctx context.Context, req CreateAccountRequest) (*AccountDTO, error) {
	account, err := domain.NewAccount(req.TenantID, req.Name, req.AccountType, req.CurrencyCode)
	if err != nil {
		return nil, fmt.Errorf("create account: %w", err)
	}
	ApplyCreateDefaults(account, req)

	if err := s.accountRepo.Save(ctx, account); err != nil {
		return nil, fmt.Errorf("save account: %w", err)
	}

	dto := AccountToDTO(account)
	return &dto, nil
}

// GetAccount retrieves an account by ID with tenant isolation.
func (s *Service) GetAccount(ctx context.Context, tenantID, accountID uuid.UUID) (*AccountDTO, error) {
	account, err := s.accountRepo.FindByID(ctx, tenantID, accountID)
	if err != nil {
		return nil, fmt.Errorf("account not found: %w", err)
	}
	dto := AccountToDTO(account)
	return &dto, nil
}

// ListAccounts returns a paginated, filtered list of accounts.
func (s *Service) ListAccounts(ctx context.Context, req ListAccountsRequest) (*ListAccountsResult, error) {
	result, err := s.accountRepo.FindAll(ctx, req.TenantID, req.Filter, req.PageRequest)
	if err != nil {
		return nil, fmt.Errorf("list accounts: %w", err)
	}
	dtos := make([]AccountDTO, len(result.Items))
	for i, a := range result.Items {
		dtos[i] = AccountToDTO(&a)
	}
	return &ListAccountsResult{
		Accounts:      dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// UpdateAccount updates mutable account fields with optimistic locking.
func (s *Service) UpdateAccount(ctx context.Context, req UpdateAccountRequest) (*AccountDTO, error) {
	account, err := s.accountRepo.FindByID(ctx, req.TenantID, req.AccountID)
	if err != nil {
		return nil, fmt.Errorf("account not found: %w", err)
	}

	if err := ValidateUpdateVersion(account.Version, req.Version); err != nil {
		return nil, err
	}

	account.UpdateDetails(req.Name, req.Icon, req.Color, req.ChartCode, req.Institution, req.CreditLimitCents)
	account.IncrementVersion()

	if err := s.accountRepo.Update(ctx, account); err != nil {
		return nil, fmt.Errorf("update account: %w", err)
	}

	dto := AccountToDTO(account)
	return &dto, nil
}

// DeleteAccount soft-deletes an account (only if balance is zero).
func (s *Service) DeleteAccount(ctx context.Context, tenantID, accountID uuid.UUID) error {
	account, err := s.accountRepo.FindByID(ctx, tenantID, accountID)
	if err != nil {
		return fmt.Errorf("account not found: %w", err)
	}
	if account.CurrentBalanceCents != 0 {
		return fmt.Errorf("cannot delete account with non-zero balance")
	}
	return s.accountRepo.SoftDelete(ctx, tenantID, accountID)
}

// Unimplemented command/query handler stubs (service handles orchestration directly).
// These satisfy the CQRS bus interface requirements.

var _ = command.CreateAccountCommand{}
var _ = command.UpdateAccountCommand{}
var _ = command.DeleteAccountCommand{}
var _ = query.GetAccountQuery{}
var _ = query.ListAccountsQuery{}
