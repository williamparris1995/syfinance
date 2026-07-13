package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	backupdomain "github.com/yucai/server/internal/backup/domain"
	holdingDomain "github.com/yucai/server/internal/holding/domain"
)

// HoldingRepository is the holding-repo port subset that HoldingExporter
// consumes for holdings (positions). Declared as a type alias so backup does
// not import the concrete holding repo type; any implementer of
// holding/domain.HoldingRepository satisfies it (port pattern, mirrors the
// account/transaction/debt/budget/goal exporters).
type HoldingRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]holdingDomain.Holding, []holdingDomain.HoldingTransaction, error)
	SaveOrUpdate(ctx context.Context, h *holdingDomain.Holding) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// TradeRepository is the trade-repo port subset that HoldingExporter consumes
// for holding transactions (the append-only trade ledger). Type alias so backup
// does not import the concrete trade repo type; any implementer of
// holding/domain.TradeRepository satisfies it. Save honors caller-supplied IDs
// (create-with-given-id), which is required for Import after Purge.
type TradeRepository = interface {
	Save(ctx context.Context, t *holdingDomain.HoldingTransaction) error
}

// holdingBackupPayload is the on-the-wire backup shape for the holding module.
// Holdings and their trade-ledger rows are persisted in two separate tables
// (linked by tenant+account+security, not by a parent-child FK), so unlike
// debt/budget/goal the child rows cannot ride on the parent struct — the
// exporter marshals them as two sibling arrays under one module key.
type holdingBackupPayload struct {
	Holdings     []holdingDomain.Holding            `json:"holdings"`
	Transactions []holdingDomain.HoldingTransaction `json:"transactions"`
}

// HoldingExporter 导出/导入/清空 tenant 的 holdings + holding transactions,
// 实现 backup TenantDataPort。Securities are global reference data (cross-
// tenant, seeded at deploy) and are NOT backed up here — holdings reference
// security_id, and on restore the security rows already exist so the FK-by-ID
// remains valid.
type HoldingExporter struct {
	repo   HoldingRepository
	trades TradeRepository
}

// NewHoldingExporter constructs a HoldingExporter from a HoldingRepository and
// a TradeRepository.
func NewHoldingExporter(repo HoldingRepository, trades TradeRepository) *HoldingExporter {
	return &HoldingExporter{repo: repo, trades: trades}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *HoldingExporter) Name() string { return "holding" }

// Export serializes all tenant holdings + holding transactions to JSON. The two
// arrays are siblings under one module key (not nested), because they live in
// independent tables without a parent-child FK.
func (e *HoldingExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	holdings, transactions, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export holdings: %w", err)
	}
	payload := holdingBackupPayload{Holdings: holdings, Transactions: transactions}
	data, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal holdings: %w", err)
	}
	return data, nil
}

// Import deserializes holdings + holding transactions from JSON and re-creates
// them under tenantID. Caller is expected to have Purged existing data first to
// avoid ID conflicts. Holdings are saved via SaveOrUpdate (after Purge there is
// no existing row for the tenant, so the create branch fires and honors the
// caller-supplied ID); transactions are saved via TradeRepository.Save which
// also honors caller-supplied IDs.
func (e *HoldingExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var payload holdingBackupPayload
	if err := json.Unmarshal(data, &payload); err != nil {
		return fmt.Errorf("unmarshal holdings: %w", err)
	}
	for i := range payload.Holdings {
		payload.Holdings[i].TenantID = tenantID
		if err := e.repo.SaveOrUpdate(ctx, &payload.Holdings[i]); err != nil {
			return fmt.Errorf("save holding %s: %w", payload.Holdings[i].ID, err)
		}
	}
	for i := range payload.Transactions {
		payload.Transactions[i].TenantID = tenantID
		if err := e.trades.Save(ctx, &payload.Transactions[i]); err != nil {
			return fmt.Errorf("save holding transaction %s: %w", payload.Transactions[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant holdings and their transactions (transactions
// first, then holdings, to preserve logical child-first ordering even though
// there is no ent FK between them).
func (e *HoldingExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge holdings: %w", err)
	}
	return nil
}

// Compile-time assertion: HoldingExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*HoldingExporter)(nil)
