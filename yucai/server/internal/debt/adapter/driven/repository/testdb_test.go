package repository_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	debtent "github.com/yucai/server/internal/debt/ent"
)

// setupDebtTestDB opens an in-memory SQLite database and runs ent
// auto-migration for the debt schema. Mirrors the holding test-db helper
// (file:<name>?mode=memory, MaxOpenConn(1) keeps the in-memory DB shared).
func setupDebtTestDB(t *testing.T) *debtent.Client {
	t.Helper()
	dbName := "debt_ent_" + sanitizeDebt(t.Name())
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
	client := debtent.NewClient(debtent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// dayDebt parses a YYYY-MM-DD string to a UTC time.Time (date-only, midnight UTC).
func dayDebt(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic("bad day fixture: " + err.Error())
	}
	return t.UTC()
}

// sanitizeDebt strips characters illegal in sqlite file names from a test name.
func sanitizeDebt(s string) string {
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
