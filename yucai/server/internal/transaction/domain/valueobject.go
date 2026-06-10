package domain

// EntryType classifies a transaction entry as debit or credit.
type EntryType int

const (
	EntryTypeDebit  EntryType = iota + 1
	EntryTypeCredit
)

func (e EntryType) String() string {
	switch e {
	case EntryTypeDebit:
		return "debit"
	case EntryTypeCredit:
		return "credit"
	default:
		return "debit"
	}
}
