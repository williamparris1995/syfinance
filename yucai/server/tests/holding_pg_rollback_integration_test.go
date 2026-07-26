package tests

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib" // register "pgx" database/sql driver for the e2e pool

	accountdomain "github.com/yucai/server/internal/account/domain"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdgrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	"github.com/yucai/server/internal/holding/application"
	holdingent "github.com/yucai/server/internal/holding/ent"
	pb "github.com/yucai/server/internal/proto/holding/v1"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// This file hosts the Postgres-backed e2e of the transactional-architecture
// refactor (Task 9). The SQLite integration tests in this package and in
// internal/holding/application/service_tx_test.go validate atomicity at the
// app layer on a single-connection in-memory DB; the tests below validate the
// stronger, production-faithful invariant: when the cross-module cash-side
// write fails INSIDE the holding service's sqltx.WithTx, the rollback reverts
// writes across MULTIPLE independent ent codegen packages (holding + trade +
// lot + transaction header + transaction entries + account balances) on real
// PostgreSQL, with the same shared *sql.DB pool (MaxOpenConns=25) production
// uses via provideDB. The shared-pool stats are asserted at the end of each
// test to confirm no connection overflow / deadlock under the e2e load.
//
// Skipped by default — set YUCAI_PG_E2E_URL to a PostgreSQL connection string
// (e.g. postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable) to
// enable. The harness creates a fresh, uniquely-named test database per test
// (so dev data in the yucai DB is untouched) and drops it on cleanup.

const pgE2EDialect = "postgres" // ent dialect string forwarded to sqltx driver

// pgE2EBaseURL reads YUCAI_PG_E2E_URL and skips the test if unset. The URL is
// expected to point at an existing database (the dev yucai DB by convention);
// the harness connects to it only to CREATE/DROP the per-test sandbox DB.
func pgE2EBaseURL(t *testing.T) string {
	t.Helper()
	url := os.Getenv("YUCAI_PG_E2E_URL")
	if url == "" {
		t.Skip("set YUCAI_PG_E2E_URL to run Postgres e2e (e.g. postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable)")
	}
	return url
}

// adminURLFor swaps the database path in a PostgreSQL DSN to "postgres" (the
// default maintenance DB), so the harness can connect to CREATE/DROP arbitrary
// databases. Handles both "?sslmode=..." and bare-path forms.
func adminURLFor(base string) string {
	return swapDBPath(base, "postgres")
}

// testURLFor swaps the database path in a PostgreSQL DSN to the given sandbox
// name, so the harness can connect to the freshly-created per-test DB.
func testURLFor(base, dbName string) string {
	return swapDBPath(base, dbName)
}

// swapDBPath replaces the database segment of a `postgresql://...?...` URL.
// Naive but sufficient for the DSN shapes the dev env + tests use; not a
// general-purpose URL parser.
func swapDBPath(base, dbName string) string {
	// Form: .../<dbname>?<params>
	if i := strings.LastIndex(base, "/"); i >= 0 {
		head := base[:i+1] // include the trailing slash
		tail := base[i+1:]
		if j := strings.Index(tail, "?"); j >= 0 {
			return head + dbName + tail[j:]
		}
		return head + dbName
	}
	return base
}

// sandboxDBName builds a short, unique, Postgres-safe database name from the
// test name. Postgres identifiers are limited to 63 bytes; we prefix + hash
// the sanitized test name to stay under the limit while remaining unique.
func sandboxDBName(t *testing.T) string {
	t.Helper()
	safe := strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' {
			return r
		}
		if r >= 'A' && r <= 'Z' {
			return r + ('a' - 'A')
		}
		return '_'
	}, t.Name())
	const prefix = "yucai_tx_e2e_"
	const maxTail = 63 - len(prefix)
	if len(safe) > maxTail {
		// Truncate and append a stable suffix from the full name so distinct
		// long test names cannot collide.
		fullHash := fmt.Sprintf("%x", stringHash(t.Name()))
		safe = safe[:maxTail-len(fullHash)] + fullHash
	}
	return prefix + safe
}

// stringHash is a tiny FNV-1a used only to derive a short unique suffix when
// truncating long test names to fit Postgres' 63-byte identifier limit. Not
// cryptographically secure; uniqueness is the only property that matters.
func stringHash(s string) uint32 {
	h := uint32(2166136261)
	for i := 0; i < len(s); i++ {
		h ^= uint32(s[i])
		h *= 16777619
	}
	return h
}

// setupE2EDB opens the Postgres-backed sandbox for one test: it creates a
// fresh, uniquely-named database, opens a *sql.DB pool sized to mirror
// production provideDB (MaxOpenConns=25 / MaxIdleConns=5 / 30m lifetime), runs
// the account + transaction + holding ent auto-migrations against it, and
// returns the shared pool plus one ent client per module. Every client is
// backed by the same *sql.DB (the production deployment pattern after Task 1)
// so a single sqltx.WithTx can wrap writes from all three packages into one
// atomic cross-module transaction. The sandbox DB is dropped on cleanup.
//
// t.Cleanup ordering (LIFO): ent clients close first → pool closes → admin
// closes → sandbox drops. That guarantees no idle connection holds the sandbox
// when DROP DATABASE runs.
func setupE2EDB(t *testing.T) (db *sql.DB, acctClient *accountent.Client, txnClient *txnent.Client, holdClient *holdingent.Client) {
	t.Helper()
	base := pgE2EBaseURL(t)
	adminURL := adminURLFor(base)
	dbName := sandboxDBName(t)
	testURL := testURLFor(base, dbName)
	ctx := context.Background()

	// Admin connection to the maintenance DB. Used only for CREATE/DROP.
	adminDB, err := sql.Open("pgx", adminURL)
	if err != nil {
		t.Fatalf("open admin conn: %v", err)
	}
	if err := adminDB.PingContext(ctx); err != nil {
		_ = adminDB.Close()
		t.Fatalf("ping admin conn (is Postgres reachable at %s?): %v", base, err)
	}

	// Drop any leftover sandbox from a previous aborted run, then create fresh.
	// Terminate backends first so the DROP doesn't block on a lingering
	// connection held by a crashed test process.
	if _, err := adminDB.ExecContext(ctx, fmt.Sprintf(
		`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%s' AND pid<>pg_backend_pid()`,
		dbName,
	)); err != nil {
		_ = adminDB.Close()
		t.Fatalf("terminate stale sandbox conns: %v", err)
	}
	if _, err := adminDB.ExecContext(ctx, fmt.Sprintf(`DROP DATABASE IF EXISTS %s`, dbName)); err != nil {
		_ = adminDB.Close()
		t.Fatalf("drop stale sandbox: %v", err)
	}
	if _, err := adminDB.ExecContext(ctx, fmt.Sprintf(`CREATE DATABASE %s`, dbName)); err != nil {
		_ = adminDB.Close()
		t.Fatalf("create sandbox: %v", err)
	}

	// Register sandbox DROP FIRST so it runs LAST on cleanup (LIFO): the ent
	// clients, the sandbox pool, and the admin conn registered after this will
	// already be closed by the time DROP DATABASE runs.
	t.Cleanup(func() {
		// Open a FRESH admin conn here rather than reusing adminDB — adminDB
		// is closed in its own cleanup (registered after the clients, so it
		// runs before this DROP).
		dropDB, err := sql.Open("pgx", adminURL)
		if err != nil {
			t.Logf("cleanup: open admin to drop sandbox: %v", err)
			return
		}
		defer dropDB.Close()
		cctx := context.Background()
		if _, err := dropDB.ExecContext(cctx, fmt.Sprintf(
			`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%s' AND pid<>pg_backend_pid()`,
			dbName,
		)); err != nil {
			t.Logf("cleanup: terminate sandbox conns: %v", err)
		}
		if _, err := dropDB.ExecContext(cctx, fmt.Sprintf(`DROP DATABASE IF EXISTS %s`, dbName)); err != nil {
			t.Logf("cleanup: drop sandbox: %v", err)
		}
	})

	// Open the test pool. Sizes mirror wire.provideDB so the e2e exercises the
	// real production pool behavior (the property the task asks to validate).
	db, err = sql.Open("pgx", testURL)
	if err != nil {
		_ = adminDB.Close()
		t.Fatalf("open sandbox pool: %v", err)
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)
	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		_ = adminDB.Close()
		t.Fatalf("ping sandbox pool: %v", err)
	}

	// Close admin BEFORE the sandbox pool on cleanup. Registered after the
	// DROP cleanup so it runs before DROP (LIFO).
	t.Cleanup(func() { _ = adminDB.Close() })
	// Close the sandbox pool AFTER admin but BEFORE DROP. Order among the
	// three (admin/db/DROP) is: db closes → admin closes → DROP runs.
	t.Cleanup(func() { _ = db.Close() })

	// Each ent client wraps the SAME *sql.DB with its own driver (production
	// wire shape: provideAccountEntClient / provideTransactionEntClient /
	// provideHoldingEntClient each call entsql.OpenDB(dialect.Postgres, db)).
	drv := entsql.OpenDB(dialect.Postgres, db)
	acctClient = accountent.NewClient(accountent.Driver(drv))
	txnClient = txnent.NewClient(txnent.Driver(drv))
	holdClient = holdingent.NewClient(holdingent.Driver(drv))

	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	if err := txnClient.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate transaction schema: %v", err)
	}
	if err := holdClient.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate holding schema: %v", err)
	}

	// Close ent clients FIRST on cleanup (LIFO: registered last → runs first).
	t.Cleanup(func() {
		_ = acctClient.Close()
		_ = txnClient.Close()
		_ = holdClient.Close()
	})
	return db, acctClient, txnClient, holdClient
}

// failingUpdateAccountRepoE2E wraps a real accountdomain.AccountRepository,
// delegates every method to the inner repo EXCEPT Update, which returns the
// injected error. Mirrors the failingUpdateAccountRepo pattern in transaction/
// application/service_tx_test.go: it trips the balance-update phase (the LAST
// write inside txnsvc.RecordTransaction) AFTER the transaction header + entry
// rows have been saved, so the rollback assertion exercises cross-module
// atomicity — the holding-side writes already succeeded and must revert.
type failingUpdateAccountRepoE2E struct {
	accountdomain.AccountRepository
	failUpdate error
	calls      int
}

func (r *failingUpdateAccountRepoE2E) Update(ctx context.Context, a *accountdomain.Account) error {
	r.calls++
	return r.failUpdate
}

// e2eHarness is the bundle of wired artifacts one test needs. Keeping it in a
// struct (vs. a long return list) makes the test bodies readable and lets a
// future test extend the harness without churn at the call sites.
type e2eHarness struct {
	h           *holdgrpc.HoldingHandler
	acctSvc     accountapp.Service
	holdSvc     *application.Service
	tenantID    uuid.UUID
	fromAccID   uuid.UUID
	holdAccID   uuid.UUID
	db          *sql.DB
	acctClient  *accountent.Client
	txnClient   *txnent.Client
	holdClient  *holdingent.Client
	failRecorder *failingUpdateAccountRepoE2E // nil when injectCashFailure=false
}

// setupE2EHarness wires the production-shaped HoldingHandler graph against the
// sandbox DB: real account/transaction/holding ent repos + real BalanceUpdater
// + real transaction application service + real TradeCashRecorderAdapter (the
// D2 cross-module port). When injectCashFailure is true, a
// failingUpdateAccountRepoE2E wrapper sits between the BalanceUpdater and the
// account repo, so the cash-side balance update inside txnsvc.RecordTransaction
// returns errFake AFTER the txn header + entries have been written — the
// cross-module failure scenario the e2e asserts against.
//
// holdSvc.SetDB(db) is the production wire injection (provideHoldingService
// passes db) that makes BuyHolding's runInTx open a sqltx.WithTx over the
// shared pool; txnSvc.GetDB()==db likewise makes RecordTransaction's runInTx
// JOIN that outer tx via sqltx's join-existing-tx semantics. The combination
// is what makes the cash-side write atomic with the holding-side write.
func setupE2EHarness(t *testing.T, injectCashFailure bool) *e2eHarness {
	t.Helper()
	db, acctClient, txnClient, holdClient := setupE2EDB(t)

	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc := *accountapp.NewService(accountRepo, chartRepo)

	// For the failure-injection path, swap accountRepo for the failing wrapper
	// everywhere it feeds the cash-side balance update. The handler's
	// accountLookup is also swapped, but validateTradeFromAccount only reads
	// (FindByID), so failing-Update does not perturb handler validation.
	//
	// Wired as the domain interface (not the concrete *AccountRepository) so
	// the same variable can hold either the real repo or the failing wrapper;
	// both satisfy accountdomain.AccountRepository (the wrapper by embedding).
	var wiredAccountRepo accountdomain.AccountRepository = accountRepo
	var failRecorder *failingUpdateAccountRepoE2E
	if injectCashFailure {
		failRecorder = &failingUpdateAccountRepoE2E{
			AccountRepository: accountRepo,
			failUpdate:        errors.New("e2e: simulated cash-side balance-update failure"),
		}
		wiredAccountRepo = failRecorder
	}

	txnRepo := txnrepo.NewTransactionRepository(txnClient, db).SetDialect(txnrepo.DialectPostgres)
	balanceUpdater := txnbalance.NewBalanceUpdater(wiredAccountRepo)
	txnSvc := txnapp.NewService(txnRepo, wiredAccountRepo, balanceUpdater, db)

	secRepo := holdingsec.NewSecurityRepository(holdClient)
	holdRepo := holdingsec.NewHoldingRepository(holdClient)
	tradeRepo := holdingsec.NewTradeRepository(holdClient)
	lotRepo := holdingsec.NewLotRepository(holdClient)
	holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)
	holdSvc.SetLotRepository(lotRepo)
	holdSvc.SetDB(db)
	holdSvc.SetCashRecorder(txnapp.NewTradeCashRecorderAdapter(txnSvc))

	// Handler's accountLookup uses wiredAccountRepo too — for the
	// failure-injection case this is the same failing wrapper, which is safe
	// (handler only reads from accountLookup; it never calls Update).
	h := holdgrpc.NewHoldingHandler(holdSvc, wiredAccountRepo)

	tenantID := uuid.New()
	ctx := context.Background()

	holdAcc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "e2e-investment",
		AccountType:  accountdomain.AccountTypeAsset,
		Category:     accountdomain.AccountCategoryInvestment,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create holding account: %v", err)
	}

	fromAcc, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:            tenantID,
		Name:                "e2e-cash",
		AccountType:         accountdomain.AccountTypeAsset,
		Category:            accountdomain.AccountCategorySavings,
		CurrencyCode:        "CNY",
		InitialBalanceCents: 100000,
	})
	if err != nil {
		t.Fatalf("create from account: %v", err)
	}

	return &e2eHarness{
		h:            h,
		acctSvc:      acctSvc,
		holdSvc:      holdSvc,
		tenantID:     tenantID,
		fromAccID:    fromAcc.ID,
		holdAccID:    holdAcc.ID,
		db:           db,
		acctClient:   acctClient,
		txnClient:    txnClient,
		holdClient:   holdClient,
		failRecorder: failRecorder,
	}
}

// assertNoPoolOverflow fails the test if the shared pool ever made callers
// wait (an overflow would mean production MaxOpenConns(25) is insufficient
// under comparable real load). database/sql clamps OpenConnections to
// MaxOpenConnections, so a true overflow surfaces as WaitCount > 0 (callers
// blocked waiting for a free conn) rather than as OpenConnections >
// MaxOpenConnections. It also logs the final stats for diagnostic visibility.
func assertNoPoolOverflow(t *testing.T, db *sql.DB) {
	t.Helper()
	st := db.Stats()
	t.Logf("pg pool stats: open=%d inUse=%d idle=%d wait=%d maxOpen=%d maxIdleClosed=%d maxIdleTimeClosed=%d maxLifetimeClosed=%d",
		st.OpenConnections, st.InUse, st.Idle, st.WaitCount, st.MaxOpenConnections, st.MaxIdleClosed, st.MaxIdleTimeClosed, st.MaxLifetimeClosed)
	if st.MaxOpenConnections == 0 {
		// Driver reports unset; nothing to assert.
		return
	}
	if st.WaitCount > 0 {
		t.Errorf("shared pool exhausted during e2e: WaitCount=%d (cross-module tx waited on a free conn — raise MaxOpenConns or scope tx shorter)", st.WaitCount)
	}
	if st.OpenConnections > st.MaxOpenConnections {
		t.Errorf("pool overflowed MaxOpenConns: open=%d max=%d", st.OpenConnections, st.MaxOpenConnections)
	}
}

// TestPGHoldingBuy_CrossModuleRollbackOnCashFailure is the headline Task 9
// invariant: a BuyHolding whose cash-side balance update FAILS mid-flow (after
// the holding + trade + lot + transaction header + entries have all been
// written across the holding AND transaction ent packages) must roll back the
// ENTIRE cross-module write — leaving zero new rows in every table and zero
// balance change on every account. This is the cross-module property the
// SQLite tests in internal/holding/application/service_tx_test.go (same-module
// lot-save failure) and internal/sqltx/integration_test.go (account+tag
// rollback) cannot themselves prove on real PostgreSQL under the production
// shared *sql.DB pool.
//
// Failure injection: failingUpdateAccountRepoE2E wraps the account repo and
// returns errFake from Update. The wrapper sits inside the txn service's
// BalanceUpdater, so the failure trips the LAST write of
// txnsvc.RecordTransaction — after txnRepo.Save (header + entries), and after
// the holding service has already persisted holding + trade + lot. The outer
// sqltx.WithTx (opened by the holding service) must roll back every write
// across all three ent packages.
func TestPGHoldingBuy_CrossModuleRollbackOnCashFailure(t *testing.T) {
	hs := setupE2EHarness(t, true)
	ctx := context.Background()

	sec, err := hs.h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol:       "E2ERB",
		Name:         "e2e rollback",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	// Sanity: the cash-side failure injector MUST fire for the assertion to be
	// meaningful. If BuyHolding returned nil without invoking the recorder,
	// the test would pass vacuously.
	if hs.failRecorder == nil {
		t.Fatal("injectCashFailure=true but failRecorder is nil (harness wiring bug)")
	}

	tradeCtx := authgrpc.WithTenantID(ctx, hs.tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())

	const buyQty = 10
	const buyPrice = 5000 // cents/share → amount 50000 cents
	_, err = hs.h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     hs.holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: hs.fromAccID.String(),
		Quantity:      buyQty,
		PriceCents:    buyPrice,
		TradeDate:     "2026-07-26",
	})
	if err == nil {
		t.Fatal("expected BuyHolding to surface the cash-side failure, got nil")
	}
	if hs.failRecorder.calls == 0 {
		t.Fatalf("cash-side failure injector never fired (failRecorder.calls=0) — test is vacuous; the cash leg did not reach balance update")
	}
	t.Logf("BuyHolding correctly failed: %v (cash-side balance Update rejected after %d call(s))", err, hs.failRecorder.calls)

	// Headline cross-module assertions. EVERY count must be zero — the outer
	// sqltx.WithTx rolled back writes across holding ent + transaction ent +
	// account ent at the PostgreSQL level.
	holdCount, err := hs.holdClient.Holding.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count holdings: %v", err)
	}
	if holdCount != 0 {
		t.Errorf("holding rows should have rolled back across modules, got %d", holdCount)
	}
	tradeCount, err := hs.holdClient.HoldingTransaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count trades: %v", err)
	}
	if tradeCount != 0 {
		t.Errorf("trade rows should have rolled back across modules, got %d", tradeCount)
	}
	lotCount, err := hs.holdClient.HoldingLot.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count lots: %v", err)
	}
	if lotCount != 0 {
		t.Errorf("lot rows should have rolled back across modules, got %d", lotCount)
	}

	// Cross-module: transaction header + entries (transaction ent package)
	// must also have rolled back. This is the property Task 5's report flagged
	// as not-yet-e2e-asserted.
	txnHeaderCount, err := hs.txnClient.Transaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count transactions: %v", err)
	}
	if txnHeaderCount != 0 {
		t.Errorf("transaction headers should have rolled back across modules, got %d", txnHeaderCount)
	}
	txnEntryCount, err := hs.txnClient.TransactionEntry.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count transaction entries: %v", err)
	}
	if txnEntryCount != 0 {
		t.Errorf("transaction entries should have rolled back across modules, got %d", txnEntryCount)
	}

	// Balance check: the cash + investment accounts must be unchanged (the
	// balance-update increment was inside the rolled-back tx).
	gotFrom, err := hs.acctSvc.GetAccount(ctx, hs.tenantID, hs.fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if gotFrom.CurrentBalanceCents != 100000 {
		t.Errorf("from balance should be unchanged after rollback: got %d, want 100000", gotFrom.CurrentBalanceCents)
	}
	gotHold, err := hs.acctSvc.GetAccount(ctx, hs.tenantID, hs.holdAccID)
	if err != nil {
		t.Fatalf("GetAccount holding: %v", err)
	}
	if gotHold.CurrentBalanceCents != 0 {
		t.Errorf("holding balance should be unchanged after rollback: got %d, want 0", gotHold.CurrentBalanceCents)
	}

	assertNoPoolOverflow(t, hs.db)
}

// TestPGHoldingBuy_CommitsOnSuccess is the paired control for the rollback
// test: with NO failure injection, BuyHolding must commit the full cross-module
// write — holding + trade + lot + transaction header + entries rows all
// appear, and both balances move by the trade amount. Without this control a
// bug where WithTx ALWAYS rolled back (or where the failure injector was
// always-on) would pass the rollback test silently.
func TestPGHoldingBuy_CommitsOnSuccess(t *testing.T) {
	hs := setupE2EHarness(t, false)
	ctx := context.Background()

	sec, err := hs.h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol:       "E2EOK",
		Name:         "e2e commit",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	tradeCtx := authgrpc.WithTenantID(ctx, hs.tenantID)
	tradeCtx = authgrpc.WithUserID(tradeCtx, uuid.New())

	const buyQty = 10
	const buyPrice = 5000
	const amount = int64(buyQty * buyPrice) // 50000 cents
	resp, err := hs.h.BuyHolding(tradeCtx, &pb.HoldingTradeRequest{
		AccountId:     hs.holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: hs.fromAccID.String(),
		Quantity:      buyQty,
		PriceCents:    buyPrice,
		TradeDate:     "2026-07-26",
	})
	if err != nil {
		t.Fatalf("BuyHolding (commit path): %v", err)
	}
	if resp == nil || resp.Transaction == nil || resp.Transaction.Id == "" {
		t.Fatal("BuyHolding returned empty trade on commit path")
	}

	// Holding + trade + lot committed.
	if got, err := hs.holdClient.Holding.Query().Count(ctx); err != nil {
		t.Fatalf("count holdings: %v", err)
	} else if got != 1 {
		t.Errorf("holding row should have committed, got %d", got)
	}
	if got, err := hs.holdClient.HoldingTransaction.Query().Count(ctx); err != nil {
		t.Fatalf("count trades: %v", err)
	} else if got != 1 {
		t.Errorf("trade row should have committed, got %d", got)
	}
	if got, err := hs.holdClient.HoldingLot.Query().Count(ctx); err != nil {
		t.Fatalf("count lots: %v", err)
	} else if got != 1 {
		t.Errorf("lot row should have committed, got %d", got)
	}

	// Cross-module: transaction header + entries committed.
	if got, err := hs.txnClient.Transaction.Query().Count(ctx); err != nil {
		t.Fatalf("count transactions: %v", err)
	} else if got != 1 {
		t.Errorf("transaction header should have committed, got %d", got)
	}
	if got, err := hs.txnClient.TransactionEntry.Query().Count(ctx); err != nil {
		t.Fatalf("count transaction entries: %v", err)
	} else if got != 2 {
		t.Errorf("expected 2 transaction entries (debit+credit), got %d", got)
	}

	// Balances moved by `amount`: cash −amount, investment +amount.
	gotFrom, err := hs.acctSvc.GetAccount(ctx, hs.tenantID, hs.fromAccID)
	if err != nil {
		t.Fatalf("GetAccount from: %v", err)
	}
	if want := int64(100000 - amount); gotFrom.CurrentBalanceCents != want {
		t.Errorf("from balance after commit: got %d, want %d", gotFrom.CurrentBalanceCents, want)
	}
	gotHold, err := hs.acctSvc.GetAccount(ctx, hs.tenantID, hs.holdAccID)
	if err != nil {
		t.Fatalf("GetAccount holding: %v", err)
	}
	if gotHold.CurrentBalanceCents != amount {
		t.Errorf("holding balance after commit: got %d, want %d", gotHold.CurrentBalanceCents, amount)
	}

	assertNoPoolOverflow(t, hs.db)
}
