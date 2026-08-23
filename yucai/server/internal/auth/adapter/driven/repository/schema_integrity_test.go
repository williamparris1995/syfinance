package repository_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
)

// R5 feature E schema-integrity check for the auth module: the partial
// unique index on users.email WHERE email <> ''.

// TestSchemaPartialUnique_UserEmail allows any number of empty-string
// emails (the NULL/'' interplay is the point of the predicate) while
// rejecting a second non-empty duplicate.
func TestSchemaPartialUnique_UserEmail(t *testing.T) {
	client := setupAuthTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()

	// Two users with the default empty email must coexist.
	for i := 0; i < 2; i++ {
		if _, err := client.User.Create().
			SetTenantID(tenant).
			SetDisplayName("no email").
			Save(ctx); err != nil {
			t.Fatalf("empty-email user %d: %v", i, err)
		}
	}

	// One non-empty email is fine.
	if _, err := client.User.Create().
		SetTenantID(tenant).
		SetDisplayName("real").
		SetEmail("a@example.com").
		Save(ctx); err != nil {
		t.Fatalf("first non-empty email: %v", err)
	}

	// A second user with the same non-empty email must be rejected.
	if _, err := client.User.Create().
		SetTenantID(uuid.New()). // different tenant, still global index
		SetDisplayName("dup").
		SetEmail("a@example.com").
		Save(ctx); err == nil {
		t.Fatal("expected duplicate non-empty email rejection, got nil")
	}

	// A different non-empty email is fine.
	if _, err := client.User.Create().
		SetTenantID(tenant).
		SetDisplayName("other").
		SetEmail("b@example.com").
		Save(ctx); err != nil {
		t.Fatalf("distinct non-empty email: %v", err)
	}
}
