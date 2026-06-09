package port

import "context"

// TxManager manages database transactions for use case orchestration.
type TxManager interface {
	// WithinTx executes fn inside a database transaction.
	// If fn returns an error, the transaction is rolled back.
	WithinTx(ctx context.Context, fn func(ctx context.Context) error) error
}
