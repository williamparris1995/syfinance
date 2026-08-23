package repository_test

import (
	"context"
	"database/sql"
	"os"
	"strings"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"
	"github.com/google/uuid"

	authent "github.com/yucai/server/internal/auth/ent"
)

// TestCleanScript_UserEmailDedup smoke-tests section 1 of
// scripts/clean-before-r5-e.sql against a real database seeded with the
// scenario the section exists for: duplicate-email users whose
// user_identities rows must be reassigned (or dropped on provider
// collision) before the loser rows can be deleted.
func TestCleanScript_UserEmailDedup(t *testing.T) {
	db, err := sql.Open("sqlite", "file:clean_script_"+sanitizeAuth(t.Name())+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	client := authent.NewClient(authent.Driver(entsql.OpenDB("sqlite3", db)))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })

	// Simulate the PRE-upgrade database: drop the partial unique index so
	// legacy duplicate-email rows can be seeded (they are exactly what
	// the script exists to clean), then re-create it before running the
	// script so the dedup is verified against the real constraint.
	if _, err := db.Exec("DROP INDEX user_email"); err != nil {
		t.Fatalf("drop user_email index for seeding: %v", err)
	}

	tenant := uuid.New()
	// Older user (the loser) and newer user (the keeper) share an email.
	loser, err := client.User.Create().
		SetTenantID(tenant).SetDisplayName("older").SetEmail("dup@example.com").
		SetCreatedAt(time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)).
		Save(ctx)
	if err != nil {
		t.Fatalf("seed loser: %v", err)
	}
	keeper, err := client.User.Create().
		SetTenantID(tenant).SetDisplayName("newer").SetEmail("dup@example.com").
		SetCreatedAt(time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)).
		Save(ctx)
	if err != nil {
		t.Fatalf("seed keeper: %v", err)
	}
	// Loser has google + github identities; keeper already has google —
	// the google row collides with unique(user_id, provider) on reassign
	// and must be dropped, github must move to the keeper.
	loserGoogle, err := client.UserIdentity.Create().
		SetTenantID(tenant).SetUserID(loser.ID).
		SetProvider("google").SetSubject("g-1").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed loser google identity: %v", err)
	}
	loserGithub, err := client.UserIdentity.Create().
		SetTenantID(tenant).SetUserID(loser.ID).
		SetProvider("github").SetSubject("h-1").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed loser github identity: %v", err)
	}
	if _, err := client.UserIdentity.Create().
		SetTenantID(tenant).SetUserID(keeper.ID).
		SetProvider("google").SetSubject("g-2").
		Save(ctx); err != nil {
		t.Fatalf("seed keeper google identity: %v", err)
	}

	// Production order: clean FIRST, migrate (create the index) SECOND.
	// Run section 1 of the script, then the index creation must succeed —
	// that is the pass condition the whole script exists to guarantee.
	section1 := extractCleanScriptSection1(t)

	for _, stmt := range splitSQLStatements(section1) {
		if _, err := db.Exec(stmt); err != nil {
			t.Fatalf("exec statement [%.60s...]: %v", stmt, err)
		}
	}
	if _, err := db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS user_email ON users (email) WHERE email <> ''"); err != nil {
		t.Fatalf("post-cleanup index creation must succeed (the script's whole purpose), got: %v", err)
	}

	// Loser user is gone; keeper survives.
	exists, err := client.User.Query().Where().IDs(ctx)
	if err != nil {
		t.Fatalf("query users: %v", err)
	}
	if len(exists) != 1 || exists[0] != keeper.ID {
		t.Errorf("expected only keeper %s to survive, got %v", keeper.ID, exists)
	}

	// Collision identity deleted; non-collision identity reassigned.
	lgExists, err := client.UserIdentity.Query().Where().IDs(ctx)
	if err != nil {
		t.Fatalf("query identities: %v", err)
	}
	got := map[string]string{}
	for _, id := range lgExists {
		row, err := client.UserIdentity.Get(ctx, id)
		if err != nil {
			t.Fatalf("get identity %s: %v", id, err)
		}
		if row.UserID != keeper.ID {
			t.Errorf("identity %s (%s) not owned by keeper after script: %s",
				row.ID, row.Provider, row.UserID)
		}
		got[row.Provider] = row.Subject
	}
	if len(lgExists) != 2 {
		t.Errorf("expected 2 identities after script (keeper google + moved github), got %d", len(lgExists))
	}
	if got["github"] != loserGithub.Subject {
		t.Errorf("github identity not preserved (loser google %s should be deleted, github kept)",
			loserGoogle.ID)
	}
}

// extractCleanScriptSection1 reads the cleanup script and returns the
// statements between the "1. Duplicate users.email" header and the
// "2. Duplicate backups.filename" header.
func extractCleanScriptSection1(t *testing.T) string {
	t.Helper()
	raw, err := os.ReadFile("../../../../../scripts/clean-before-r5-e.sql")
	if err != nil {
		t.Skipf("cleanup script not found (run from repo layout): %v", err)
	}
	lines := strings.Split(string(raw), "\n")
	var out []string
	inSection := false
	for _, ln := range lines {
		if strings.Contains(ln, "1. Duplicate users.email") {
			inSection = true
		}
		if strings.Contains(ln, "2. Duplicate backups.filename") {
			break
		}
		if inSection {
			out = append(out, ln)
		}
	}
	if len(out) == 0 {
		t.Fatal("section 1 not found in cleanup script")
	}
	return strings.Join(out, "\n")
}

// splitSQLStatements strips "--" comment lines and splits on ";".
func splitSQLStatements(script string) []string {
	var stmts []string
	for _, chunk := range strings.Split(script, ";") {
		var kept []string
		for _, ln := range strings.Split(chunk, "\n") {
			trimmed := strings.TrimSpace(ln)
			if trimmed == "" || strings.HasPrefix(trimmed, "--") {
				continue
			}
			kept = append(kept, ln)
		}
		if len(kept) > 0 {
			stmts = append(stmts, strings.Join(kept, "\n"))
		}
	}
	return stmts
}
