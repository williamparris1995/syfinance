package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// TradeRepository is the trade-ledger-repo port subset the sync writer
// consumes (type alias, port pattern — same family as HoldingRepository above).
type TradeRepository = interface {
	UpsertForSync(ctx context.Context, tr *holdingdomain.HoldingTransaction) error
	HardDeleteForSync(ctx context.Context, tenantID, tradeID uuid.UUID) error
	FindForSync(ctx context.Context, tenantID, tradeID uuid.UUID) (*holdingdomain.HoldingTransaction, bool, error)
}

// HoldingLedgerWriter persists pushed trade-ledger changes (entity_type
// "holding_ledger") — the 9th writer, F17-T2.
//
// 台账查证裁决(task-brief-f17-2 第 5 节,2026-09-06):server 侧台账存储
// 现成(ent HoldingTransaction 表 + holding Service 直接 RPC 的
// BuyHolding/SellHolding/RecordDividend/RecordSplit 写入路径 +
// ListHoldingTransactions 读回)——「孤儿台账」缺的只是同步链路(writer
// 未注册,server 对未知 entityType fail-closed)。裁决=实施:本 writer +
// client collector 台账联动上行(照 ADR-4),第二设备 pull 侧经
// PullApplier 补齐分红/买卖台账,闭环 spec FR-4。
//
// Payload shape: ONE envelope ledger row (client envelope_codec
// holdingTxnRowToEnvelope — PascalCase keys, int TradeType with the same
// value domain as domain.TradeType, RFC3339 timestamps, no TenantID/Version
// keys). TradeType unmarshals straight into the domain int enum and persists
// as its string column form; TransactionID rides as a nullable uuid.
type HoldingLedgerWriter struct {
	repo TradeRepository
}

// NewHoldingLedgerWriter constructs a HoldingLedgerWriter.
func NewHoldingLedgerWriter(repo TradeRepository) *HoldingLedgerWriter {
	return &HoldingLedgerWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule.holdingLedger).
func (w *HoldingLedgerWriter) Name() string { return "holding_ledger" }

// Upsert decodes one ledger payload and upserts it under tenantID
// (authenticated tenant wins, anti injection).
func (w *HoldingLedgerWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var tr holdingdomain.HoldingTransaction
	if err := json.Unmarshal(payload, &tr); err != nil {
		return fmt.Errorf("unmarshal holding_ledger payload: %w", err)
	}
	tr.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &tr); err != nil {
		return fmt.Errorf("upsert holding_ledger %s: %w", tr.ID, err)
	}
	return nil
}

// Delete hard-deletes one ledger row under tenantID. Idempotent (a tombstone
// for an absent row is a no-op). See TradeRepository.HardDeleteForSync doc
// for why the client never emits these today.
func (w *HoldingLedgerWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse holding_ledger id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete holding_ledger %s: %w", id, err)
	}
	return nil
}

// Canonicalize round-trips one payload through the domain entity with the
// tenant stamped — the canonical JSON form the push detection compares
// against CurrentState's payload (see the port doc).
func (w *HoldingLedgerWriter) Canonicalize(tenantID uuid.UUID, payload []byte) ([]byte, error) {
	var tr holdingdomain.HoldingTransaction
	if err := json.Unmarshal(payload, &tr); err != nil {
		return nil, fmt.Errorf("unmarshal holding_ledger payload: %w", err)
	}
	tr.TenantID = tenantID
	return json.Marshal(tr)
}

// CurrentState returns the server's current ledger row for the push conflict
// check (F16 ADR-4). The append-only ledger carries no optimistic version —
// version is pinned to 1. Dead path in practice: the client stamps every
// ledger push CREATE (never UPDATE), and CREATE is never conflict-checked;
// 1 merely keeps the interface total (any future UPDATE probe compares
// against 1 and conflicts only on a same-version re-delivery).
func (w *HoldingLedgerWriter) CurrentState(ctx context.Context, tenantID uuid.UUID, entityID string) (int64, []byte, bool, error) {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return 0, nil, false, fmt.Errorf("parse holding_ledger id %q: %w", entityID, err)
	}
	tr, found, err := w.repo.FindForSync(ctx, tenantID, id)
	if err != nil || !found {
		return 0, nil, false, err
	}
	payload, err := json.Marshal(tr)
	if err != nil {
		return 0, nil, false, fmt.Errorf("marshal holding_ledger %s: %w", id, err)
	}
	return 1, payload, true, nil
}

var _ syncdomain.SyncEntityWriter = (*HoldingLedgerWriter)(nil)
