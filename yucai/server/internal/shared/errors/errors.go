package errors

import "fmt"

// DomainError represents a business rule violation.
type DomainError struct {
	Code    string
	Message string
	Cause   error
}

func (e *DomainError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("[%s] %s: %v", e.Code, e.Message, e.Cause)
	}
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

func (e *DomainError) Unwrap() error { return e.Cause }

// New creates a new DomainError.
func New(code, message string) *DomainError {
	return &DomainError{Code: code, Message: message}
}

// Wrap creates a DomainError wrapping a cause.
func Wrap(code, message string, cause error) *DomainError {
	return &DomainError{Code: code, Message: message, Cause: cause}
}

// Pre-defined error codes
var (
	ErrNotFound         = New("NOT_FOUND", "entity not found")
	ErrAlreadyExists    = New("ALREADY_EXISTS", "entity already exists")
	ErrValidation       = New("VALIDATION_ERROR", "validation failed")
	ErrBalanceViolation = New("BALANCE_VIOLATION", "balance rule violated")
	ErrOptimisticLock   = New("OPTIMISTIC_LOCK_CONFLICT", "concurrent modification detected")
	ErrUnauthorized     = New("UNAUTHORIZED", "not authorized")
	ErrForbidden        = New("FORBIDDEN", "access denied")
	ErrTenantRequired   = New("TENANT_REQUIRED", "tenant_id is required")
)

// WithMessage returns a copy of the error with a custom message.
func WithMessage(err *DomainError, message string) *DomainError {
	return &DomainError{Code: err.Code, Message: message, Cause: err.Cause}
}
