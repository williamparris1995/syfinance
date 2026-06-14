package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	authpb "github.com/yucai/server/internal/proto/auth/v1"
)

// Demonstrates seamless renewal after access-token expiry — the exact sequence
// the Flutter AuthRetryCaller performs automatically on a 401.
//
// Run against a server with a short access-token TTL (e.g. 30s, set in
// jwt/token.go for this demo). go run ./cmd/demo-expiry
func main() {
	conn, err := grpc.NewClient("localhost:9090",
		grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("dial: %v", err)
	}
	defer conn.Close()
	client := authpb.NewAuthServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	auth := func(t string) context.Context {
		return metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+t)
	}
	ts := func() string { return time.Now().Format("15:04:05") }

	// 1. Login
	email := fmt.Sprintf("demo_%d@test.com", time.Now().UnixNano())
	login, err := client.Login(ctx, &authpb.LoginRequest{Email: email, Password: "password123"})
	// register first since the user is new
	if err != nil {
		reg, rerr := client.Register(ctx, &authpb.RegisterRequest{
			Email: email, Password: "password123", DisplayName: "Demo",
		})
		if rerr != nil {
			log.Fatalf("register: %v", rerr)
		}
		login = &authpb.LoginResponse{AccessToken: reg.AccessToken, RefreshToken: reg.RefreshToken}
	}
	fmt.Printf("[%s] 1️⃣  Login → access token issued\n", ts())

	// 2. GetProfile (token valid)
	if _, err := client.GetProfile(auth(login.AccessToken), &authpb.GetProfileRequest{}); err != nil {
		log.Fatalf("profile #1: %v", err)
	}
	fmt.Printf("[%s] 2️⃣  GetProfile with access token → OK (token valid)\n", ts())

	// 3. Wait for the access token to expire
	fmt.Printf("[%s]    ⏳ waiting 35s for access token to expire (TTL=30s)…\n", ts())
	time.Sleep(35 * time.Second)

	// 4. GetProfile with the EXPIRED access token → 401
	_, err = client.GetProfile(auth(login.AccessToken), &authpb.GetProfileRequest{})
	if err == nil {
		log.Fatal("❌ expected 401 from expired token, got success")
	}
	fmt.Printf("[%s] 3️⃣  GetProfile with EXPIRED token → %s\n", ts(), status.Code(err))

	// 5. Refresh — this is what AuthRetryCaller does automatically on the 401
	r, err := client.RefreshToken(ctx, &authpb.RefreshTokenRequest{RefreshToken: login.RefreshToken})
	if err != nil {
		log.Fatalf("refresh: %v", err)
	}
	fmt.Printf("[%s] 4️⃣  RefreshToken → new access token issued (rotation)\n", ts())

	// 6. Retry GetProfile with the fresh token → OK
	if _, err := client.GetProfile(auth(r.AccessToken), &authpb.GetProfileRequest{}); err != nil {
		log.Fatalf("profile #2: %v", err)
	}
	fmt.Printf("[%s] 5️⃣  GetProfile with NEW token → OK (seamless renewal ✅)\n", ts())

	fmt.Println("\n🎉 Expiry → 401 → refresh → retry: the exact flow AuthRetryCaller runs automatically.")
}
