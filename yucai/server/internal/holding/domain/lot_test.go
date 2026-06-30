package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func mustLot(acquired time.Time, price int64, remaining float64) HoldingLot {
	return HoldingLot{
		ID:                uuid.New(),
		AcquiredDate:      acquired,
		PriceCents:        price,
		Quantity:          remaining,
		RemainingQuantity: remaining,
	}
}

func TestConsumeLotsFIFOSingleLot(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 100)}
	// sell 40 @ 12000 cents (cost 10000 cents) → realized = (12000-10000)*40 = 80000 cents
	realized, consumed, err := ConsumeLotsFIFO(40, 12000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if realized != 80000 {
		t.Fatalf("realized = %d, want 80000", realized)
	}
	if len(consumed) != 1 || consumed[0].ConsumedQuantity != 40 {
		t.Fatalf("consumed = %+v, want 1 lot × 40", consumed)
	}
}

func TestConsumeLotsFIFOMultiLot(t *testing.T) {
	// Two lots: oldest @10000 cents (60), newer @11000 cents (40). Sell 80 @13000 cents.
	// FIFO: take 60 from lot1 (realized (13000-10000)*60=180000) + 20 from lot2 ((13000-11000)*20=40000) = 220000 cents
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60),
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40),
	}
	realized, consumed, err := ConsumeLotsFIFO(80, 13000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if realized != 220000 {
		t.Fatalf("realized = %d, want 220000", realized)
	}
	if len(consumed) != 2 || consumed[0].ConsumedQuantity != 60 || consumed[1].ConsumedQuantity != 20 {
		t.Fatalf("consumed = %+v, want [60, 20]", consumed)
	}
}

func TestConsumeLotsFIFOPartialLeavesRemaining(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 100)}
	_, consumed, err := ConsumeLotsFIFO(30, 12000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Caller applies consumption: lot.RemainingQuantity -= consumed.
	remaining := lots[0].RemainingQuantity - consumed[0].ConsumedQuantity
	if remaining != 70 {
		t.Fatalf("remaining after sell = %.4f, want 70", remaining)
	}
}

func TestConsumeLotsFIFOOverSellErrors(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 50)}
	_, _, err := ConsumeLotsFIFO(60, 12000, lots)
	if err == nil {
		t.Fatal("oversell must error")
	}
}

func TestConsumeLotsFIFOUnsortedInputSortedByDate(t *testing.T) {
	// Input out of date order: newer lot first. FIFO must still consume oldest first.
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40), // newer
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60), // older
	}
	_, consumed, err := ConsumeLotsFIFO(60, 13000, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// All 60 from the older (@100) lot, none from newer.
	if len(consumed) != 1 || consumed[0].LotID != lots[1].ID {
		t.Fatalf("FIFO must consume oldest lot first; consumed=%+v", consumed)
	}
}

func TestConsumeLotsFIFODoesNotMutateInput(t *testing.T) {
	lots := []HoldingLot{mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 100)}
	before := lots[0].RemainingQuantity
	_, _, _ = ConsumeLotsFIFO(40, 12000, lots)
	if lots[0].RemainingQuantity != before {
		t.Fatalf("ConsumeLotsFIFO must not mutate input lots; got %.4f want %.4f",
			lots[0].RemainingQuantity, before)
	}
}

func TestLotAvgCost(t *testing.T) {
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60), // 60 @ 100
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40), // 40 @ 110
	}
	// weighted = (60*100 + 40*110) / 100 = 10400 → 104.00
	if got := LotAvgCost(lots); got != 10400 {
		t.Fatalf("LotAvgCost = %d, want 10400", got)
	}
}

func TestLotAvgCostSkipsClosedLots(t *testing.T) {
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 0), // closed (remaining=0)
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40),
	}
	if got := LotAvgCost(lots); got != 11000 {
		t.Fatalf("LotAvgCost = %d, want 11000 (skip closed lot)", got)
	}
}

// 守恒性质(确定性验证,非 proptest 库):卖完后 Σ realized + remaining_lot_cost = total_cost_basis。
// 即 FIFO 不创造/毁灭成本:实现的 + 剩余的 = 原始总成本(相对卖出回收调整)。
func TestConsumeLotsFIFOConservation(t *testing.T) {
	lots := []HoldingLot{
		mustLot(time.Date(2025, 1, 2, 0, 0, 0, 0, time.UTC), 10000, 60),
		mustLot(time.Date(2025, 1, 5, 0, 0, 0, 0, time.UTC), 11000, 40),
	}
	sellQty := 50.0
	sellPrice := int64(13000)
	realized, consumed, err := ConsumeLotsFIFO(sellQty, sellPrice, lots)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// remaining cost = Σ (lot.Price × (lot.Remaining - consumed[i]))
	remainingCost := int64(0)
	consumedByID := map[uuid.UUID]float64{}
	for _, c := range consumed {
		consumedByID[c.LotID] = c.ConsumedQuantity
	}
	for _, l := range lots {
		rem := l.RemainingQuantity - consumedByID[l.ID]
		remainingCost += int64(float64(l.PriceCents) * rem)
	}
	// realized was computed against sellPrice; cost-of-goods-sold = Σ(lot.Price × consumed)
	cogs := int64(0)
	for _, l := range lots {
		cogs += int64(float64(l.PriceCents) * consumedByID[l.ID])
	}
	// realized + cogs should equal sellQty * sellPrice (proceeds fully accounted).
	proceeds := int64(float64(sellPrice) * sellQty)
	if realized+cogs != proceeds {
		t.Fatalf("conservation broken: realized(%d)+cogs(%d)=%d != proceeds(%d)",
			realized, cogs, realized+cogs, proceeds)
	}
	// remainingCost + cogs == original total cost (cost preserved across sell).
	originalCost := int64(60*10000 + 40*11000)
	if remainingCost+cogs != originalCost {
		t.Fatalf("cost not preserved: remaining(%d)+cogs(%d)=%d != original(%d)",
			remainingCost, cogs, remainingCost+cogs, originalCost)
	}
}
