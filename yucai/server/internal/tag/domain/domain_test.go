package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewTag_Valid(t *testing.T) {
	tag, err := NewTag(uuid.New(), "Food", "#FF5733")
	if err != nil {
		t.Fatalf("NewTag failed: %v", err)
	}
	if tag.Version != 1 {
		t.Errorf("expected version 1, got %d", tag.Version)
	}
	if tag.Color != "#FF5733" {
		t.Errorf("expected #FF5733, got %s", tag.Color)
	}
}

func TestNewTag_EmptyName(t *testing.T) {
	_, err := NewTag(uuid.New(), "  ", "#FF5733")
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestNewTag_DefaultColor(t *testing.T) {
	tag, err := NewTag(uuid.New(), "Test", "")
	if err != nil {
		t.Fatalf("NewTag failed: %v", err)
	}
	if tag.Color != "#000000" {
		t.Errorf("expected default #000000, got %s", tag.Color)
	}
}

func TestNewTag_InvalidColor(t *testing.T) {
	_, err := NewTag(uuid.New(), "Test", "red")
	if err == nil {
		t.Error("expected error for invalid color")
	}
}

func TestTag_UpdateName(t *testing.T) {
	tag, _ := NewTag(uuid.New(), "Food", "#FF5733")
	if err := tag.UpdateName("Dining"); err != nil {
		t.Fatalf("UpdateName failed: %v", err)
	}
	if tag.Name != "Dining" {
		t.Errorf("expected Dining, got %s", tag.Name)
	}
}

func TestTag_UpdateName_Empty(t *testing.T) {
	tag, _ := NewTag(uuid.New(), "Food", "#FF5733")
	if err := tag.UpdateName("  "); err == nil {
		t.Error("expected error for empty name")
	}
}

func TestTag_UpdateColor(t *testing.T) {
	tag, _ := NewTag(uuid.New(), "Food", "#FF5733")
	if err := tag.UpdateColor("#00FF00"); err != nil {
		t.Fatalf("UpdateColor failed: %v", err)
	}
	if tag.Color != "#00FF00" {
		t.Errorf("expected #00FF00, got %s", tag.Color)
	}
}

func TestTag_SoftDelete(t *testing.T) {
	tag, _ := NewTag(uuid.New(), "Food", "#FF5733")
	tag.SoftDelete()
	if tag.DeletedAt == nil {
		t.Error("expected deleted_at to be set")
	}
}

func TestTag_IncrementVersion(t *testing.T) {
	tag, _ := NewTag(uuid.New(), "Food", "#FF5733")
	before := tag.Version
	time.Sleep(time.Millisecond)
	tag.IncrementVersion()
	if tag.Version != before+1 {
		t.Errorf("expected version %d, got %d", before+1, tag.Version)
	}
}
