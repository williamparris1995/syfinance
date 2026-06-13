package domain

import (
	"testing"

	"github.com/google/uuid"
)

func TestNewCategory_Valid(t *testing.T) {
	c, err := NewCategory(uuid.New(), "Food", CategoryTypeExpense, "🍔", "#FF5733", nil, 1)
	if err != nil {
		t.Fatalf("NewCategory failed: %v", err)
	}
	if c.Name != "Food" {
		t.Error("expected name to be set")
	}
	if c.IsSystem {
		t.Error("user category should not be system")
	}
}

func TestNewCategory_EmptyName(t *testing.T) {
	_, err := NewCategory(uuid.New(), "  ", CategoryTypeExpense, "", "", nil, 0)
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestNewCategory_NoType(t *testing.T) {
	_, err := NewCategory(uuid.New(), "Test", CategoryType(0), "", "", nil, 0)
	if err == nil {
		t.Error("expected error for unspecified category type")
	}
}

func TestCategory_SoftDelete_SystemRejected(t *testing.T) {
	c := NewSystemCategory(uuid.New(), "Salary", CategoryTypeIncome, "💰", "#00FF00", 0)
	err := c.SoftDelete()
	if err == nil {
		t.Error("expected error deleting system category")
	}
}

func TestCategory_SoftDelete_UserAllowed(t *testing.T) {
	c, _ := NewCategory(uuid.New(), "Coffee", CategoryTypeExpense, "☕", "", nil, 0)
	if err := c.SoftDelete(); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !c.IsDeleted() {
		t.Error("expected category to be deleted")
	}
}

func TestCategory_UpdateName_DeletedRejected(t *testing.T) {
	c, _ := NewCategory(uuid.New(), "Test", CategoryTypeExpense, "", "", nil, 0)
	_ = c.SoftDelete()
	err := c.UpdateName("NewName")
	if err == nil {
		t.Error("expected error updating deleted category")
	}
}

func TestCategoryType_RoundTrip(t *testing.T) {
	types := []CategoryType{CategoryTypeIncome, CategoryTypeExpense}
	for _, ct := range types {
		if ParseCategoryType(ct.String()) != ct {
			t.Errorf("round-trip failed for %v", ct)
		}
	}
}
