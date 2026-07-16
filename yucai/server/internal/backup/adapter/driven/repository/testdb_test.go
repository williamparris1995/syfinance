package repository_test

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	backupent "github.com/yucai/server/internal/backup/ent"
)

// setupBackupTestDB opens an in-memory SQLite database and runs ent
// auto-migration for the backup schema. Mirrors the debt/holding test-db helper
// (file:<name>?mode=memory, MaxOpenConn(1) keeps the in-memory DB shared
// across the prepared-statement boundary so Create/Query see the same rows).
func setupBackupTestDB(t *testing.T) *backupent.Client {
	t.Helper()
	dbName := "backup_ent_" + sanitizeBackup(t.Name())
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
	client := backupent.NewClient(backupent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// sanitizeBackup strips characters illegal in sqlite file names from a test name.
func sanitizeBackup(s string) string {
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
