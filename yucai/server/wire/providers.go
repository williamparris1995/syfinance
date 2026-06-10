package wire

import (
	"context"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountgrpc "github.com/yucai/server/internal/account/adapter/driving/grpc"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txngrpc "github.com/yucai/server/internal/transaction/adapter/driving/grpc"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txnent "github.com/yucai/server/internal/transaction/ent"
	authrepo "github.com/yucai/server/internal/auth/adapter/driven/repository"
	"github.com/yucai/server/internal/auth/adapter/driven/session"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	authapp "github.com/yucai/server/internal/auth/application"
	authcmd "github.com/yucai/server/internal/auth/application/command"
	authquery "github.com/yucai/server/internal/auth/application/query"
	authent "github.com/yucai/server/internal/auth/ent"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
	"github.com/yucai/server/pkg/middleware"

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
	return redis.NewClient(&redis.Options{Addr: cfg.RedisURL})
}

func provideAuthEntClient(cfg *config.Config) (*authent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return authent.NewClient(authent.Driver(drv)), nil
}

func provideAccountEntClient(cfg *config.Config) (*accountent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return accountent.NewClient(accountent.Driver(drv)), nil
}

func provideTransactionEntClient(cfg *config.Config) (*txnent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return txnent.NewClient(txnent.Driver(drv)), nil
}

func provideTokenService(cfg *config.Config) *authjwt.TokenService {
	return authjwt.NewTokenService(cfg.JWTSecret)
}

// Auth providers
func provideTenantRepo(client *authent.Client) *authrepo.TenantRepository {
	return authrepo.NewTenantRepository(client)
}
func provideUserRepo(client *authent.Client) *authrepo.UserRepository {
	return authrepo.NewUserRepository(client)
}
func provideSessionStore(rdb *redis.Client) *session.RedisSessionStore {
	return session.NewRedisSessionStore(rdb)
}
func provideRegisterHandler(tr *authrepo.TenantRepository, ur *authrepo.UserRepository, ts *authjwt.TokenService) *authcmd.RegisterHandler {
	return authcmd.NewRegisterHandler(tr, ur, ts)
}
func provideLoginHandler(ur *authrepo.UserRepository, ts *authjwt.TokenService) *authcmd.LoginHandler {
	return authcmd.NewLoginHandler(ur, ts)
}
func provideRefreshHandler(ur *authrepo.UserRepository, ts *authjwt.TokenService, ss *session.RedisSessionStore) *authcmd.RefreshHandler {
	return authcmd.NewRefreshHandler(ur, ts, ss)
}
func provideProfileHandler(ur *authrepo.UserRepository) *authquery.GetProfileHandler {
	return authquery.NewGetProfileHandler(ur)
}
func provideAuthService(tr *authrepo.TenantRepository, ur *authrepo.UserRepository, ts *authjwt.TokenService, rh *authcmd.RegisterHandler, lh *authcmd.LoginHandler, fh *authcmd.RefreshHandler, ph *authquery.GetProfileHandler) *authapp.Service {
	return authapp.NewService(tr, ur, ts, rh, lh, fh, ph)
}
func provideAuthHandler(svc *authapp.Service) *authgrpc.AuthHandler {
	return authgrpc.NewAuthHandler(svc)
}

// Account providers
func provideAccountRepo(client *accountent.Client) *accountrepo.AccountRepository {
	return accountrepo.NewAccountRepository(client)
}
func provideChartRepo(client *accountent.Client) *accountrepo.ChartRepository {
	return accountrepo.NewChartRepository(client)
}
func provideAccountService(ar *accountrepo.AccountRepository, cr *accountrepo.ChartRepository) *accountapp.Service {
	return accountapp.NewService(ar, cr)
}
func provideAccountHandler(svc *accountapp.Service) *accountgrpc.AccountHandler {
	return accountgrpc.NewAccountHandler(svc)
}

// Transaction providers
func provideTransactionRepo(client *txnent.Client) *txnrepo.TransactionRepository {
	return txnrepo.NewTransactionRepository(client)
}
func provideBalanceUpdater(ar *accountrepo.AccountRepository) *txnbalance.BalanceUpdaterImpl {
	return txnbalance.NewBalanceUpdater(ar)
}
func provideTransactionService(tr *txnrepo.TransactionRepository, bu *txnbalance.BalanceUpdaterImpl) *txnapp.Service {
	return txnapp.NewService(tr, bu)
}
func provideTransactionHandler(svc *txnapp.Service) *txngrpc.TransactionHandler {
	return txngrpc.NewTransactionHandler(svc)
}

func provideGRPCServer(ts *authjwt.TokenService) *GRPCServer {
	middleware.TokenService = ts
	srv := grpc.NewServer(grpc.UnaryInterceptor(middleware.AuthInterceptor))
	return &GRPCServer{Server: srv}
}

var (
	_ = uuid.New
	_ = context.Background
)
