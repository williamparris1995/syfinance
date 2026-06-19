package domain

import (
	"testing"

	"github.com/google/uuid"
)

func TestNewAccount(t *testing.T) {
	tid := uuid.New()
	tests := []struct {
		name    string
		inName  string
		inType  AccountType
		wantErr bool
	}{
		{"valid asset", "Cash", AccountTypeAsset, false},
		{"valid expense", "Food", AccountTypeExpense, false},
		{"empty name", "", AccountTypeAsset, true},
		{"whitespace name", "  ", AccountTypeAsset, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a, err := NewAccount(tid, tt.inName, tt.inType, "CNY")
			if (err != nil) != tt.wantErr {
				t.Errorf("NewAccount() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr {
				if a.TenantID != tid {
					t.Error("tenant ID mismatch")
				}
				if a.Status != AccountStatusActive {
					t.Error("new accounts should be active")
				}
				if a.Version != 1 {
					t.Error("new accounts should start at version 1")
				}
			}
		})
	}
}

func TestAccountUpdateName(t *testing.T) {
	a, _ := NewAccount(uuid.New(), "Old", AccountTypeAsset, "CNY")
	if err := a.UpdateName("New"); err != nil {
		t.Fatalf("UpdateName failed: %v", err)
	}
	if a.Name != "New" {
		t.Errorf("expected New, got %s", a.Name)
	}
	if err := a.UpdateName(""); err == nil {
		t.Error("empty name should fail")
	}
}

func TestAccountSoftDelete(t *testing.T) {
	a, _ := NewAccount(uuid.New(), "Cash", AccountTypeAsset, "CNY")
	a.SoftDelete()
	if !a.IsDeleted() {
		t.Error("account should be deleted")
	}
	if a.Status != AccountStatusArchived {
		t.Error("deleted accounts should be archived")
	}
}

func TestAccountIncrementVersion(t *testing.T) {
	a, _ := NewAccount(uuid.New(), "Cash", AccountTypeAsset, "CNY")
	if a.Version != 1 {
		t.Error("initial version should be 1")
	}
	a.IncrementVersion()
	if a.Version != 2 {
		t.Errorf("expected version 2, got %d", a.Version)
	}
}

func TestBalanceCalculator(t *testing.T) {
	calc := BalanceCalculator{}
	tests := []struct {
		name     string
		at       AccountType
		initial  int64
		debit    int64
		credit   int64
		expected int64
	}{
		{"asset increases with debit", AccountTypeAsset, 1000, 500, 0, 1500},
		{"asset decreases with credit", AccountTypeAsset, 1000, 0, 300, 700},
		{"liability increases with credit", AccountTypeLiability, 1000, 0, 500, 1500},
		{"liability decreases with debit", AccountTypeLiability, 1000, 300, 0, 700},
		{"expense increases with debit", AccountTypeExpense, 0, 200, 0, 200},
		{"income increases with credit", AccountTypeIncome, 0, 0, 300, 300},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := calc.Calculate(tt.at, tt.initial, tt.debit, tt.credit)
			if got != tt.expected {
				t.Errorf("Calculate() = %d, want %d", got, tt.expected)
			}
		})
	}
}

func TestParseAccountType(t *testing.T) {
	if ParseAccountType("asset") != AccountTypeAsset {
		t.Error("expected Asset")
	}
	if ParseAccountType("liability") != AccountTypeLiability {
		t.Error("expected Liability")
	}
	if AccountTypeAsset.String() != "asset" {
		t.Errorf("expected 'asset', got %s", AccountTypeAsset.String())
	}
}

func TestNewChartOfAccount(t *testing.T) {
	chart, err := NewChartOfAccount(uuid.New(), "1001", "Cash", AccountTypeAsset, BalanceDirectionDebit)
	if err != nil {
		t.Fatalf("NewChartOfAccount failed: %v", err)
	}
	if chart.Code != "1001" {
		t.Errorf("expected 1001, got %s", chart.Code)
	}
	_, err = NewChartOfAccount(uuid.New(), "", "Cash", AccountTypeAsset, BalanceDirectionDebit)
	if err == nil {
		t.Error("empty code should fail")
	}
}

func TestAccountCategoryToAccountType(t *testing.T) {
	cases := []struct {
		cat  AccountCategory
		want AccountType
	}{
		{AccountCategorySavings, AccountTypeAsset},
		{AccountCategoryInvestment, AccountTypeAsset},
		{AccountCategoryFixedDeposit, AccountTypeAsset},
		{AccountCategoryGoldFx, AccountTypeAsset},
		{AccountCategoryRealEstate, AccountTypeAsset},
		{AccountCategoryOtherAsset, AccountTypeAsset},
		{AccountCategoryCreditCard, AccountTypeLiability},
		{AccountCategoryLoan, AccountTypeLiability},
		{AccountCategoryOtherLiability, AccountTypeLiability},
	}
	for _, c := range cases {
		if got := c.cat.ToAccountType(); got != c.want {
			t.Errorf("%s.ToAccountType()=%s, want %s", c.cat, got, c.want)
		}
	}
}

func TestAccountCategoryStringRoundTrip(t *testing.T) {
	for _, c := range []AccountCategory{
		AccountCategorySavings, AccountCategoryCreditCard, AccountCategoryInvestment,
		AccountCategoryFixedDeposit, AccountCategoryGoldFx, AccountCategoryRealEstate,
		AccountCategoryLoan, AccountCategoryOtherAsset, AccountCategoryOtherLiability,
	} {
		if ParseAccountCategory(c.String()) != c {
			t.Errorf("round-trip failed for %s", c.String())
		}
	}
	if ParseAccountCategory("nonsense") != AccountCategorySavings {
		t.Error("unknown category should default to Savings")
	}
}

func TestNewAccountDerivesTypeFromCategory(t *testing.T) {
	a, err := NewAccountWithCategory(uuid.New(), "测试信用卡", AccountCategoryCreditCard, "CNY")
	if err != nil {
		t.Fatalf("NewAccountWithCategory failed: %v", err)
	}
	if a.AccountType != AccountTypeLiability {
		t.Errorf("credit_card category should derive liability, got %s", a.AccountType)
	}
	if a.Category != AccountCategoryCreditCard {
		t.Error("category not stored")
	}

	b, err := NewAccountWithCategory(uuid.New(), "储蓄卡", AccountCategorySavings, "CNY")
	if err != nil {
		t.Fatalf("savings failed: %v", err)
	}
	if b.AccountType != AccountTypeAsset {
		t.Errorf("savings should derive asset, got %s", b.AccountType)
	}

	if _, err := NewAccountWithCategory(uuid.New(), "", AccountCategorySavings, "CNY"); err == nil {
		t.Error("empty name should fail")
	}
}

func TestApplyProfileSetsNullableFields(t *testing.T) {
	a, _ := NewAccountWithCategory(uuid.New(), "信用卡测试", AccountCategoryCreditCard, "CNY")
	rate := 18.25
	day := 9
	limit := int64(800000)
	tail := "2840"
	p := &AccountProfile{
		CardNumberTail:   &tail,
		InterestRate:     &rate,
		CreditBillingDay: &day,
		CreditLimitCents: &limit,
	}
	a.ApplyProfile(p)
	if a.CardNumberTail != "2840" {
		t.Errorf("CardNumberTail not set, got %q", a.CardNumberTail)
	}
	if a.InterestRate == nil || *a.InterestRate != 18.25 {
		t.Error("InterestRate not set")
	}
	if a.CreditBillingDay == nil || *a.CreditBillingDay != 9 {
		t.Error("CreditBillingDay not set")
	}
	if a.CreditLimitCents != 800000 {
		t.Errorf("CreditLimitCents not set, got %d", a.CreditLimitCents)
	}
}

func TestApplyProfileNilFieldsSkipped(t *testing.T) {
	a, _ := NewAccountWithCategory(uuid.New(), "贷款", AccountCategoryLoan, "CNY")
	a.ApplyProfile(&AccountProfile{}) // 全 nil，无 panic
	if a.InterestRate != nil || a.LoanRemainingCents != nil || a.CreditBillingDay != nil {
		t.Error("nil profile fields should leave account fields untouched")
	}
}

func TestArchiveSetsStatusWithoutDelete(t *testing.T) {
	a, _ := NewAccountWithCategory(uuid.New(), "x", AccountCategorySavings, "CNY")
	a.Archive()
	if a.Status != AccountStatusArchived {
		t.Error("Archive should set status to archived")
	}
	if a.DeletedAt != nil {
		t.Error("Archive must NOT set DeletedAt (that's SoftDelete)")
	}
}

// TestAccount_CategoryFields verifies the category-as-account extension fields
// (parent_id / is_system / sort_order) are present and assignable on the
// Account aggregate. These back the account-as-category redesign:
//   - ParentID:   two-level category hierarchy (e.g. "coffee" under "dining")
//   - IsSystem:   marks system-preset categories that cannot be deleted
//   - SortOrder:  user/admin ordering of categories
func TestAccount_CategoryFields(t *testing.T) {
	a, err := NewAccount(uuid.New(), "Dining", AccountTypeExpense, "CNY")
	if err != nil {
		t.Fatalf("NewAccount failed: %v", err)
	}

	// Defaults: a freshly-created user account is not a system category and
	// has no implicit sort order.
	if a.IsSystem {
		t.Error("new account should default IsSystem=false")
	}
	if a.SortOrder != 0 {
		t.Errorf("new account should default SortOrder=0, got %d", a.SortOrder)
	}
	if a.ParentID != nil {
		t.Error("new account should default ParentID=nil")
	}

	// All three fields are settable.
	pid := uuid.New()
	a.ParentID = &pid
	a.IsSystem = true
	a.SortOrder = 5

	if a.ParentID == nil || *a.ParentID != pid {
		t.Errorf("ParentID not set, got %v", a.ParentID)
	}
	if !a.IsSystem {
		t.Error("IsSystem not set")
	}
	if a.SortOrder != 5 {
		t.Errorf("SortOrder not set, got %d", a.SortOrder)
	}
}
