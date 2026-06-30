package domain

// SecurityType defines the type of security.
type SecurityType int

const (
	SecurityTypeStock SecurityType = iota + 1
	SecurityTypeFund
	SecurityTypeETF
	SecurityTypeBond
	SecurityTypeGold
	SecurityTypeOption
	SecurityTypeOther
	SecurityTypeIndex
)

func (t SecurityType) String() string {
	switch t {
	case SecurityTypeStock:
		return "stock"
	case SecurityTypeFund:
		return "fund"
	case SecurityTypeETF:
		return "etf"
	case SecurityTypeBond:
		return "bond"
	case SecurityTypeGold:
		return "gold"
	case SecurityTypeOption:
		return "option"
	case SecurityTypeOther:
		return "other"
	case SecurityTypeIndex:
		return "index"
	default:
		return "unknown"
	}
}

func ParseSecurityType(s string) SecurityType {
	switch s {
	case "stock":
		return SecurityTypeStock
	case "fund":
		return SecurityTypeFund
	case "etf":
		return SecurityTypeETF
	case "bond":
		return SecurityTypeBond
	case "gold":
		return SecurityTypeGold
	case "option":
		return SecurityTypeOption
	case "other":
		return SecurityTypeOther
	case "index":
		return SecurityTypeIndex
	default:
		return 0
	}
}

// TradeType defines the type of holding transaction.
type TradeType int

const (
	TradeTypeBuy TradeType = iota + 1
	TradeTypeSell
	TradeTypeDividend
	TradeTypeSplit
)

func (t TradeType) String() string {
	switch t {
	case TradeTypeBuy:
		return "buy"
	case TradeTypeSell:
		return "sell"
	case TradeTypeDividend:
		return "dividend"
	case TradeTypeSplit:
		return "split"
	default:
		return "unknown"
	}
}

func ParseTradeType(s string) TradeType {
	switch s {
	case "buy":
		return TradeTypeBuy
	case "sell":
		return TradeTypeSell
	case "dividend":
		return TradeTypeDividend
	case "split":
		return TradeTypeSplit
	default:
		return 0
	}
}
