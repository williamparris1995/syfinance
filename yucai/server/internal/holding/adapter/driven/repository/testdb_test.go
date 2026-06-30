package repository_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	holdingent "github.com/yucai/server/internal/holding/ent"
)

// setupHoldingTestDB opens an in-memory SQLite database and runs ent
// auto-migration for the holding schema. Mirrors the pattern in
// account_repo_test.go (file:<name>?mode=memory, MaxOpenConns(1) to keep the
// same in-memory DB alive across connections on the same driver).
func setupHoldingTestDB(t *testing.T) *holdingent.Client {
	t.Helper()
	dbName := "holding_ent_" + sanitize(t.Name())
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	client := holdingent.NewClient(holdingent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// day parses a YYYY-MM-DD string to a UTC time.Time (date-only, midnight UTC).
// Centralized so tests read like fixtures.
func day(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic("bad day fixture: " + err.Error())
	}
	return t.UTC()
}

// sanitize strips characters illegal in sqlite file names from a test name.
func sanitize(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '/' || c == '\\' || c == ' ' || c == ':' {
			out = append(out, '_')
			continue
		}
		out = append(out, c)
	}
	return string(out)
}
