package domain

import "fmt"

// DoubleEntryValidator enforces double-entry bookkeeping rules.
type DoubleEntryValidator struct{}

// Validate checks that all entries follow debit/credit XOR and that total debits equal total credits.
func (v *DoubleEntryValidator) Validate(entries []TransactionEntry) error {
	var totalDebits, totalCredits int64
	for i, e := range entries {
		if e.DebitCents > 0 && e.CreditCents > 0 {
			return fmt.Errorf("entry %d: cannot have both debit (%d) and credit (%d)", i, e.DebitCents, e.CreditCents)
		}
		if e.DebitCents == 0 && e.CreditCents == 0 {
			return fmt.Errorf("entry %d: must have either debit or credit", i)
		}
		totalDebits += e.DebitCents
		totalCredits += e.CreditCents
	}
	if totalDebits != totalCredits {
		return fmt.Errorf("double-entry violation: debits=%d != credits=%d", totalDebits, totalCredits)
	}
	return nil
}
