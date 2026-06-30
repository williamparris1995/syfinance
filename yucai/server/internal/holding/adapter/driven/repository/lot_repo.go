package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holdinglot"
)

// LotRepository implements domain.LotRepository.
type LotRepository struct {
	client *holdingent.Client
}

// NewLotRepository creates a new LotRepository.
func NewLotRepository(client *holdingent.Client) *LotRepository {
	return &LotRepository{client: client}
}

// FindByHolding returns all lots for a holding ordered by AcquiredDate ASC
// (FIFO consume order). Closed lots (remaining=0) are included for audit /
// realized traceability. domain.ConsumeLotsFIFO re-sorts defensively, but
// returning sorted here keeps callers honest.
func (r *LotRepository) FindByHolding(ctx context.Context, holdingID uuid.UUID) ([]domain.HoldingLot, error) {
	rows, err := r.client.HoldingLot.Query().
		Where(holdinglot.HoldingIDEQ(holdingID)).
		Order(holdingent.Asc(holdinglot.FieldAcquiredDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query holding lots: %w", err)
	}
	out := make([]domain.HoldingLot, 0, len(rows))
	for _, row := range rows {
		out = append(out, toDomainLot(row))
	}
	return out, nil
}

// SaveAll upserts lots: lots with a zero ID are created (new buy), lots with
// an existing ID have quantity + remaining_quantity updated (sell consume /
// split ratio adjustment). Single transaction would be ideal; for now each
// lot is persisted independently — the service layer owns the FIFO consume
// math and passes a consistent batch.
func (r *LotRepository) SaveAll(ctx context.Context, lots []domain.HoldingLot) error {
	for _, l := range lots {
		if l.ID == uuid.Nil {
			// New lot (buy): create.
			if _, err := r.client.HoldingLot.Create().
				SetTenantID(l.TenantID).
				SetHoldingID(l.HoldingID).
				SetSecurityID(l.SecurityID).
				SetAcquiredDate(l.AcquiredDate).
				SetAcquiredTradeID(l.AcquiredTradeID).
				SetPriceCents(l.PriceCents).
				SetQuantity(l.Quantity).
				SetRemainingQuantity(l.RemainingQuantity).
				Save(ctx); err != nil {
				return fmt.Errorf("create holding lot: %w", err)
			}
			continue
		}
		// Existing lot (sell/split): update remaining + quantity.
		if err := r.client.HoldingLot.UpdateOneID(l.ID).
			SetRemainingQuantity(l.RemainingQuantity).
			SetQuantity(l.Quantity).
			Exec(ctx); err != nil {
			return fmt.Errorf("update holding lot %s: %w", l.ID, err)
		}
	}
	return nil
}

func toDomainLot(row *holdingent.HoldingLot) domain.HoldingLot {
	return domain.HoldingLot{
		ID:                row.ID,
		TenantID:          row.TenantID,
		HoldingID:         row.HoldingID,
		SecurityID:        row.SecurityID,
		AcquiredDate:      row.AcquiredDate,
		AcquiredTradeID:   row.AcquiredTradeID,
		PriceCents:        row.PriceCents,
		Quantity:          row.Quantity,
		RemainingQuantity: row.RemainingQuantity,
	}
}

var _ domain.LotRepository = (*LotRepository)(nil)
