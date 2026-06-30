package domain

import (
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/google/uuid"
)

// HoldingLot is a FIFO cost lot — a tax lot acquired by a single buy, consumed
// in acquired-date order by sells. Split adjusts Quantity/RemainingQuantity by
// ratio (cost per share scales inversely, total cost unchanged). remaining=0
// lots are retained for audit/historical realized traceability.
type HoldingLot struct {
	ID                uuid.UUID
	TenantID          uuid.UUID
	HoldingID         uuid.UUID
	SecurityID        uuid.UUID
	AcquiredDate      time.Time
	AcquiredTradeID   uuid.UUID
	PriceCents        int64
	Quantity          float64
	RemainingQuantity float64
}

// LotConsumption records how much of one lot a sell consumed (for the caller
// to persist RemainingQuantity decrements).
type LotConsumption struct {
	LotID            uuid.UUID
	ConsumedQuantity float64
}

const fifoQtyEpsilon = 1e-9 // tolerance for float quantity comparisons

// ConsumeLotsFIFO consumes sellQty across lots in FIFO order (oldest
// AcquiredDate first), returning the realized P&L in cents and the per-lot
// consumption record. sellQty must be <= sum of RemainingQuantity; otherwise
// an error is returned (defensive oversell guard — service.SellHolding already
// validates against Holding.Quantity, this is the second layer).
//
// lots are NOT mutated; the caller applies consumed[].ConsumedQuantity to each
// lot's RemainingQuantity and persists via LotRepository. math.Round avoids
// float truncation (same convention as entity.go cents math).
func ConsumeLotsFIFO(sellQty float64, sellPriceCents int64, lots []HoldingLot) (realized int64, consumed []LotConsumption, err error) {
	// Defensive copy + sort by AcquiredDate ascending (FIFO). Caller usually
	// passes sorted, but do not trust it.
	sorted := append([]HoldingLot(nil), lots...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].AcquiredDate.Before(sorted[j].AcquiredDate) })

	total := 0.0
	for _, l := range sorted {
		total += l.RemainingQuantity
	}
	if sellQty > total+fifoQtyEpsilon {
		return 0, nil, fmt.Errorf("fifo: cannot sell %.4f, only %.4f in lots", sellQty, total)
	}

	remaining := sellQty
	for _, l := range sorted {
		if remaining <= fifoQtyEpsilon {
			break
		}
		if l.RemainingQuantity <= fifoQtyEpsilon {
			continue
		}
		take := math.Min(remaining, l.RemainingQuantity)
		realized += int64(math.Round(float64(sellPriceCents-l.PriceCents) * take))
		consumed = append(consumed, LotConsumption{LotID: l.ID, ConsumedQuantity: take})
		remaining -= take
	}
	return realized, consumed, nil
}

// LotAvgCost returns the weighted-average cost (cents) of open lots
// (RemainingQuantity > 0). Used to keep Holding.AvgCostCents consistent with
// the FIFO lot state after each buy/sell/split. Returns 0 if no open lots.
func LotAvgCost(lots []HoldingLot) int64 {
	var cost, qty float64
	for _, l := range lots {
		if l.RemainingQuantity > fifoQtyEpsilon {
			cost += float64(l.PriceCents) * l.RemainingQuantity
			qty += l.RemainingQuantity
		}
	}
	if qty <= fifoQtyEpsilon {
		return 0
	}
	return int64(math.Round(cost / qty))
}
