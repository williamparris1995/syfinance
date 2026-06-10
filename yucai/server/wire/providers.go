package wire

import (
	"context"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"github.com/yucai/server/internal/auth/adapter/driven/repository"
	"github.com/yucai/server/internal/auth/adapter/driven/session"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/auth/application"
	"github.com/yucai/server/internal/auth/application/command"
	"github.com/yucai/server/internal/auth/application/query"
	authent "github.com/yucai/server/internal/auth/ent"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
	"github.com/yucai/server/pkg/middleware"

	"entgo.io/ent/dialect/sql"
	entsql "entgo.io/ent/dialect/sql"
	"google.golang.org/grpc"
)

// GRPCServer wraps *grpc.Server for Wire typing.
type GRPCServer struct {
	*grpc.Server
}

// ---- Provider Functions ----

func provideLogger(cfg *config.Config) *logger.Logger {
	logger.Setup(cfg.LogLevel)
	return &logger.Logger{}
}

func provideRedisClient(cfg *config.Config) *redis.Client {
	return redis.NewClient(&redis.Options{
		Addr: cfg.RedisURL,
	})
}

func provideEntClient(cfg *config.Config) (*authent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return authent.NewClient(authent.Driver(drv)), nil
}

func provideTokenService(cfg *config.Config) *authjwt.TokenService {
	return authjwt.NewTokenService(cfg.JWTSecret)
}

func provideTenantRepo(client *authent.Client) *repository.TenantRepository {
	return repository.NewTenantRepository(client)
}

func provideUserRepo(client *authent.Client) *repository.UserRepository {
	return repository.NewUserRepository(client)
}

func provideSessionStore(rdb *redis.Client) *session.RedisSessionStore {
	return session.NewRedisSessionStore(rdb)
}

func provideRegisterHandler(
	tenantRepo *repository.TenantRepository,
	userRepo *repository.UserRepository,
	ts *authjwt.TokenService,
) *command.RegisterHandler {
	return command.NewRegisterHandler(tenantRepo, userRepo, ts)
}

func provideLoginHandler(
	userRepo *repository.UserRepository,
	ts *authjwt.TokenService,
) *command.LoginHandler {
	return command.NewLoginHandler(userRepo, ts)
}

func provideRefreshHandler(
	userRepo *repository.UserRepository,
	ts *authjwt.TokenService,
	ss *session.RedisSessionStore,
) *command.RefreshHandler {
	return command.NewRefreshHandler(userRepo, ts, ss)
}

func provideProfileHandler(userRepo *repository.UserRepository) *query.GetProfileHandler {
	return query.NewGetProfileHandler(userRepo)
}

func provideAuthService(
	tenantRepo *repository.TenantRepository,
	userRepo *repository.UserRepository,
	ts *authjwt.TokenService,
	rh *command.RegisterHandler,
	lh *command.LoginHandler,
	fh *command.RefreshHandler,
	ph *query.GetProfileHandler,
) *application.Service {
	return application.NewService(tenantRepo, userRepo, ts, rh, lh, fh, ph)
}

func provideAuthHandler(svc *application.Service) *authgrpc.AuthHandler {
	return authgrpc.NewAuthHandler(svc)
}

func provideGRPCServer(ts *authjwt.TokenService) *GRPCServer {
	middleware.TokenService = ts
	srv := grpc.NewServer(
		grpc.UnaryInterceptor(middleware.AuthInterceptor),
	)
	return &GRPCServer{Server: srv}
}

// Unused imports guard (these are used by wire.go providers).
var (
	_ = uuid.New
	_ = (*sql.Driver)(nil)
	_ = context.Background
)
