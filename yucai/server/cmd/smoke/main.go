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

// Smoke test: connect to localhost:9090, register, login, get profile.
// Run: go run ./cmd/smoke
func main() {
	conn, err := grpc.NewClient("localhost:9090",
		grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("dial: %v", err)
	}
	defer conn.Close()
	client := authpb.NewAuthServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	email := fmt.Sprintf("smoke_%d@test.com", time.Now().UnixNano())

	// 1. Register
	reg, err := client.Register(ctx, &authpb.RegisterRequest{
		Email: email, Password: "password123", DisplayName: "Smoke Tester",
	})
	if err != nil {
		log.Fatalf("register failed: %v", err)
	}
	fmt.Printf("✅ Register OK — user %s, tenant %s\n", reg.User.Id, reg.User.TenantId)
	fmt.Printf("   access token (first 20): %.20s...\n", reg.AccessToken)

	// 2. GetProfile with the token
	authCtx := metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+reg.AccessToken)
	prof, err := client.GetProfile(authCtx, &authpb.GetProfileRequest{})
	if err != nil {
		log.Fatalf("get profile failed: %v", err)
	}
	fmt.Printf("✅ GetProfile OK — %s (%s)\n", prof.User.DisplayName, prof.User.Email)

	// 3. Login (same creds)
	login, err := client.Login(ctx, &authpb.LoginRequest{Email: email, Password: "password123"})
	if err != nil {
		log.Fatalf("login failed: %v", err)
	}
	fmt.Printf("✅ Login OK — user %s\n", login.User.Id)

	fmt.Println("\n🎉 Auth end-to-end PASSED")
}
