package grpc

import (
	"testing"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/holding/domain"
)

// TestBuildTradeEntries_Buy: buy 复式 = credit from_account(现金−) + debit holding account(投资+)。
func TestBuildTradeEntries_Buy(t *testing.T) {
	from := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"} // cash
	hold := accountdomain.Account{ID: uuid.New(), ChartCode: "1511"} // investment
	const amount int64 = 50000

	entries := buildTradeEntries(domain.TradeTypeBuy, from, hold, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	// entries[0]: from — credit only (cash out).
	if entries[0].AccountID != from.ID || entries[0].CreditCents != amount || entries[0].DebitCents != 0 {
		t.Errorf("from entry: expected credit=%d debit=0, got credit=%d debit=%d",
			amount, entries[0].CreditCents, entries[0].DebitCents)
	}
	// entries[1]: holding — debit only (investment in).
	if entries[1].AccountID != hold.ID || entries[1].DebitCents != amount || entries[1].CreditCents != 0 {
		t.Errorf("holding entry: expected debit=%d credit=0, got debit=%d credit=%d",
			amount, entries[1].DebitCents, entries[1].CreditCents)
	}
	if entries[0].CreditCents != entries[1].DebitCents {
		t.Errorf("unbalanced: credit=%d debit=%d", entries[0].CreditCents, entries[1].DebitCents)
	}
}

// TestBuildTradeEntries_Sell: sell 复式反向 = debit from_account(现金+) + credit holding account(投资−)。
func TestBuildTradeEntries_Sell(t *testing.T) {
	from := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"}
	hold := accountdomain.Account{ID: uuid.New(), ChartCode: "1511"}
	const amount int64 = 30000

	entries := buildTradeEntries(domain.TradeTypeSell, from, hold, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	if entries[0].DebitCents != amount || entries[0].CreditCents != 0 {
		t.Errorf("sell from entry: expected debit only, got debit=%d credit=%d",
			entries[0].DebitCents, entries[0].CreditCents)
	}
	if entries[1].CreditCents != amount || entries[1].DebitCents != 0 {
		t.Errorf("sell holding entry: expected credit only, got debit=%d credit=%d",
			entries[1].DebitCents, entries[1].CreditCents)
	}
}
