//go:build ignore

package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"

	authpb "github.com/yucai/server/internal/proto/auth/v1"
)

// Full auth-flow smoke test exercising the industry-standard model:
// rotation, rotation-chain validity, reuse detection with family revocation.
// Run: go run ./cmd/smoke
func main() {
	conn, err := grpc.NewClient("localhost:9090",
		grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("dial: %v", err)
	}
	defer conn.Close()
	client := authpb.NewAuthServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	auth := func(token string) context.Context {
		return metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token)
	}
	register := func() (access, refresh string) {
		email := fmt.Sprintf("smoke_%d@test.com", time.Now().UnixNano())
		r, err := client.Register(ctx, &authpb.RegisterRequest{
			Email: email, Password: "password123", DisplayName: "Smoke",
		})
		must(err, "register")
		return r.AccessToken, r.RefreshToken
	}
	refresh := func(rt string) (string, string) {
		r, err := client.RefreshToken(ctx, &authpb.RefreshTokenRequest{RefreshToken: rt})
		must(err, "refresh")
		return r.AccessToken, r.RefreshToken
	}
	expectUnauth := func(rt string, label string) {
		_, err := client.RefreshToken(ctx, &authpb.RefreshTokenRequest{RefreshToken: rt})
		if err == nil {
			log.Fatalf("❌ %s: expected rejection, got success", label)
		}
		fmt.Printf("✅ %s → rejected (%v)\n", label, err)
	}

	// --- Session 1: rotation chain stays valid (no reuse) ---
	_, r1 := register()
	fmt.Printf("1️⃣  Register → refresh(%.8s…)\n", r1)

	_, r2 := refresh(r1)
	if r2 == r1 {
		log.Fatal("❌ rotation did not issue a new token")
	}
	fmt.Printf("2️⃣  Refresh #1 (rotation) → new refresh(%.8s…)\n", r2)

	a3, r3 := refresh(r2)
	fmt.Printf("3️⃣  Refresh #2 (chain) → new refresh(%.8s…)\n", r3)

	prof, err := client.GetProfile(auth(a3), &authpb.GetProfileRequest{})
	must(err, "get profile with chained access token")
	fmt.Printf("4️⃣  GetProfile with rotated access token → %s\n", prof.User.Email)

	// r1 was rotated to r2, so r1 is now a tombstone → reuse detection + family revoke.
	expectUnauth(r1, "Reuse detection (replay rotated token r1)")

	// Family revoked → even the most recent live token r3 is now dead.
	expectUnauth(r3, "Family revocation (r3 dead after reuse)")

	fmt.Println("\n🎉 Full auth flow PASSED: rotation chain + reuse-detection family revocation")
}

func must(err error, label string) {
	if err != nil {
		log.Fatalf("❌ %s failed: %v", label, err)
	}
}
