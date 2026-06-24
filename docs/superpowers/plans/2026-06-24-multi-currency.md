# 御财多货币换算统计 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 让御财正确处理多货币账户——账户卡片按 `currencyCode` 显示原货币符号（USD 账户显示 `$`），总计/小计按 frankfurter 汇率换算到 tenant 偏好货币（默认 CNY）。frankfurter provider + 后台 scheduler + tenant 偏好设置 + client 换算 helper + CurrencyBloc + accounts/account_detail 符号修正 + 设置页。

**Architecture:**
- **server**（Go ent + wire + gRPC）：frankfurter HTTP provider（adapter/driven/exchangerate）+ 后台 scheduler（`time.NewTicker` 模式，御财首个后台任务）+ tenant schema 加 `preferred_currency`/`rate_sync_interval_hours`（ent auto-migrate，无 SQL migration）+ `CurrencyRepository.FindAllActive` + AuthService 新增 `GetPreferences`/`UpdatePreferences` RPC。
- **proto**：`auth.proto` 加 `TenantPreferencesDTO` + `GetPreferences`/`UpdatePreferences` RPC + `UserDTO` 加 `preferred_currency`；server + client buf generate（dart 用 local `protoc-gen-dart`）。
- **client**（Flutter bloc + injectable）：新建 `lib/currency/`（data remote ds + domain convert helper + presentation CurrencyBloc）+ `lib/settings/`（设置页）+ accounts_page/account_detail 符号与换算修正。

**Tech Stack:** Go 1.x, ent, wire, gRPC, frankfurter.app HTTP API; Flutter, flutter_bloc, injectable, get_it, mocktail。

## Global Constraints

- 御财 token（`client/lib/core/theme/app_design.dart`）：奶油白 bg `#F7F6F2` / 御财金 accent `#B08D57` / 收入绿 `#2D8A6E` / 支出红 `#C4544D` / 边框 `#E6E3DC` / 圆角 sm `10` lg `14` / 标题 serif `Georgia` / 数字 `AppTypography.tabularFigures`。
- lucide 风格 icon（`Icons.*_outlined`）。
- 硬编码中文（御财无 i18n）。
- 金额一律 **INTEGER cents**（int64），任何 float 仅用于汇率乘除后 `.round()`。
- 路径约定：server = `yucai/server/`，client = `yucai/client/`，proto = `yucai/proto/`。
- **TDD**：每任务先写失败测试（RED）→ 实现（GREEN）→ commit。
- 分支 `multi-currency`，BASE `4e718a8`。
- 不破坏现有测试：server `go test ./internal/...` + client `flutter test`（209 pass）必须保持绿。
- ent 字段改动后 `cd yucai/server && go generate ./internal/auth/ent/...`；proto 改动后 `cd yucai && make proto`。

## 关键探索修正（Plan agent 确认）

1. **无现有 scheduler**：grep 全 server 确认御财当前没有任何后台 ticker/scheduler。本 plan Task 5 新建御财首个后台任务模式（`time.NewTicker` + `context.WithCancel` + `go func`，main.go 启动 + graceful cancel）。
2. **`UpdatePreferences` 放 AuthService**（不是 currency service）：tenant 是 auth 实体，currency service 全局无 tenant 上下文。`UserDTO` 加 `preferred_currency`（字段 7）以便 client 首屏免额外 RPC。
3. **wire provider 类型改接口**：`provideExchangeRateProvider` 当前返回具体 `*MockProvider`，切 Frankfurter 需返回类型改成 `exchangerate.Provider` 接口（service 已接收接口，最小改动）。
4. **跨模块 auth→currency 校验**：用 auth/domain 定义 `CurrencyCodeChecker` 端口，wire 用 currency repo 适配，避免 auth import currency。
5. **client 全新 currency + settings 模块**：`CurrencyServiceClient` 未注册、无设置页路由（侧栏"设置"是 null 占位）。
6. **dart proto 用 local plugin**：remote `grpc-dart` 缺失，`buf.gen.dart.yaml` 改 local `protoc-gen-dart` + PATH 加 `%LOCALAPPDATA%\Pub\Cache\bin`。

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `server/internal/currency/adapter/driven/exchangerate/frankfurter.go` | Create | Frankfurter HTTP provider，实现 `Provider` + `FetchRates(ctx, codes)` |
| `server/internal/currency/adapter/driven/exchangerate/frankfurter_test.go` | Create | httptest mock 测 frankfurter 解析 |
| `server/internal/currency/adapter/driven/exchangerate/provider.go` | Modify | `Provider` 接口加 `FetchRates(ctx, []string) (map[string]float64, error)` |
| `server/internal/currency/adapter/driven/exchangerate/mock_provider.go` | Modify | MockProvider 实现 `FetchRates` |
| `server/internal/currency/domain/repository.go` | Modify | `CurrencyRepository` 加 `FindAllActive(ctx)` |
| `server/internal/currency/adapter/driven/repository/currency_repo.go` | Modify | 实现 `FindAllActive` |
| `server/internal/currency/application/service.go` | Modify | 加 `SyncRates(ctx) (int, error)` |
| `server/internal/currency/application/service_test.go` | Create | 测 SyncRates |
| `server/internal/currency/scheduler/scheduler.go` | Create | `Scheduler`：ticker + SyncRates |
| `server/internal/currency/scheduler/scheduler_test.go` | Create | 测 scheduler 触发 |
| `server/internal/auth/ent/schema/tenant.go` | Modify | 加 `preferred_currency` + `rate_sync_interval_hours` |
| `server/internal/auth/domain/entity.go` | Modify | `Tenant` 加字段 + `UpdatePreferences` |
| `server/internal/auth/domain/repository.go` | Modify | 加 `CurrencyCodeChecker` 端口 + `FindAllIntervalHours` |
| `server/internal/auth/adapter/driven/repository/tenant_repo.go` | Modify | 读写新字段 + `FindAllIntervalHours` |
| `server/internal/auth/application/dto.go` | Modify | 加 `TenantPreferencesDTO` + `UpdatePreferencesRequest` |
| `server/internal/auth/application/service.go` | Modify | 加 `GetPreferences` + `UpdatePreferences` |
| `server/internal/auth/application/service_test.go` | Create | 测 UpdatePreferences 校验 |
| `server/internal/auth/adapter/driving/grpc/auth_handler.go` | Modify | 加 handler |
| `proto/auth/v1/auth.proto` | Modify | 加 `TenantPreferencesDTO` + RPC + `UserDTO.preferred_currency` |
| `proto/buf.gen.dart.yaml` | Modify | dart 改 local plugin |
| `server/wire/providers.go` | Modify | provider 返回接口 + 注册 Scheduler + CurrencyCodeChecker 适配 |
| `server/wire/app.go` | Modify | App 加 `CurrencyScheduler` |
| `server/wire/wire.go` | Modify | provider 链 |
| `server/cmd/server/main.go` | Modify | 启动 scheduler + graceful stop |
| `client/lib/proto/auth/v1/*.dart` | Regenerate | buf generate |
| `client/lib/currency/domain/currency_convert.dart` | Create | `toPreferredCents` + `currencySymbol` |
| `client/lib/currency/domain/currency_convert_test.dart` | Create | unit test |
| `client/lib/currency/data/currency_remote_ds.dart` | Create | `CurrencyRemoteDataSource` |
| `client/lib/currency/domain/entities/currency_entity.dart` | Create | `Currency` entity |
| `client/lib/currency/domain/repositories/currency_repository.dart` | Create | abstract |
| `client/lib/currency/data/currency_repository_impl.dart` | Create | impl |
| `client/lib/currency/presentation/bloc/currency_bloc.dart` | Create | LoadCurrencies + LoadPreferences |
| `client/lib/settings/presentation/settings_page.dart` | Create | 偏好货币 + 同步频率 UI |
| `client/lib/account/presentation/pages/accounts_page.dart` | Modify | 符号 + 总计换算 |
| `client/lib/account/presentation/pages/account_detail_page.dart` | Modify | Hero 原货币符号 |
| `client/lib/app/router.dart` | Modify | 加 `/settings` route + CurrencyBloc provider |
| `client/lib/app/widgets/app_shell.dart` | Modify | "设置" nav → `/settings` |
| `client/test/account/presentation/pages/accounts_page_test.dart` | Modify | 多货币总计 widget test |

---

## Task 1: Frankfurter provider

**Files:**
- Modify: `yucai/server/internal/currency/adapter/driven/exchangerate/provider.go`
- Create: `yucai/server/internal/currency/adapter/driven/exchangerate/frankfurter.go`
- Create: `yucai/server/internal/currency/adapter/driven/exchangerate/frankfurter_test.go`
- Modify: `yucai/server/internal/currency/adapter/driven/exchangerate/mock_provider.go`

**Interfaces:**
```go
type Provider interface {
    FetchRate(ctx context.Context, code string) (float64, error)
    FetchRates(ctx context.Context, codes []string) (map[string]float64, error) // EUR=1.0; missing omitted
}
```

- [ ] **Step 1 (RED):** 写 `frankfurter_test.go`，用 `httptest.NewServer` 返回 `{"base":"EUR","date":"2026-06-24","rates":{"USD":1.08,"CNY":7.81,"GBP":0.86}}`，断言 `FetchRates(ctx, []string{"USD","CNY","GBP","EUR"})` = `{USD:1.08, CNY:7.81, GBP:0.86, EUR:1.0}`；测 HTTP 500 → error；空 codes → `{EUR:1.0}`。运行 → 失败（`FetchRates` 未定义）。
- [ ] **Step 2 (GREEN-A):** `provider.go` 加 `FetchRates` 到接口。`mock_provider.go` 实现（从 `p.rates` 取子集，EUR 强制 1.0）。
- [ ] **Step 3 (GREEN-B):** 创建 `frankfurter.go`：
```go
package exchangerate

import (
    "context"
    "encoding/json"
    "fmt"
    "net/http"
    "strings"
    "time"
)

type FrankfurterProvider struct {
    baseURL string
    client  *http.Client
}

func NewFrankfurterProvider() *FrankfurterProvider {
    return &FrankfurterProvider{baseURL: "https://api.frankfurter.app", client: &http.Client{Timeout: 10 * time.Second}}
}

func (p *FrankfurterProvider) FetchRate(ctx context.Context, code string) (float64, error) {
    rates, err := p.FetchRates(ctx, []string{code})
    if err != nil { return 0, err }
    r, ok := rates[strings.ToUpper(code)]
    if !ok { return 0, fmt.Errorf("rate not available for currency %s", code) }
    return r, nil
}

func (p *FrankfurterProvider) FetchRates(ctx context.Context, codes []string) (map[string]float64, error) {
    upper := make([]string, 0, len(codes))
    for _, c := range codes {
        up := strings.ToUpper(strings.TrimSpace(c))
        if up != "" && up != "EUR" { upper = append(upper, up) }
    }
    url := p.baseURL + "/latest?base=EUR"
    if len(upper) > 0 { url += "&symbols=" + strings.Join(upper, ",") }
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil { return nil, fmt.Errorf("build request: %w", err) }
    resp, err := p.client.Do(req)
    if err != nil { return nil, fmt.Errorf("frankfurter request: %w", err) }
    defer resp.Body.Close()
    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("frankfurter status %d", resp.StatusCode)
    }
    var body struct {
        Base  string             `json:"base"`
        Rates map[string]float64 `json:"rates"`
    }
    if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
        return nil, fmt.Errorf("decode frankfurter response: %w", err)
    }
    out := make(map[string]float64, len(body.Rates)+1)
    out["EUR"] = 1.0
    for k, v := range body.Rates { out[strings.ToUpper(k)] = v }
    return out, nil
}
```
- [ ] **Step 4:** test 用 `FrankfurterProvider{baseURL: ts.URL, client: ts.Client()}` 指向 test server。`go test ./internal/currency/adapter/driven/exchangerate/...` → 通过。
- [ ] **Step 5:** commit `feat(currency): frankfurter exchange rate provider`。

---

## Task 2: CurrencyRepository.FindAllActive + Service.SyncRates

**Files:**
- Modify: `server/internal/currency/domain/repository.go`
- Modify: `server/internal/currency/adapter/driven/repository/currency_repo.go`
- Modify: `server/internal/currency/application/service.go`
- Create: `server/internal/currency/application/service_test.go`

**Interfaces:**
```go
type CurrencyRepository interface {
    // ... existing ...
    FindAllActive(ctx context.Context) ([]Currency, error)
}
func (s *Service) SyncRates(ctx context.Context) (int, error) // 批量 fetch + update active
```

- [ ] **Step 1 (RED):** `service_test.go`：sqlite enttest 建表，seed CNY/USD/EUR active + JPY inactive；mock provider `FetchRates` 返回 `{CNY:7.81, USD:1.08, EUR:1.0}`；断言 `SyncRates` 返回 3 且 CNY rate=7.81、USD=1.08、EUR=1.0、JPY 不变。运行 → 失败。
- [ ] **Step 2 (GREEN-A):** `domain/repository.go` 加 `FindAllActive`；`currency_repo.go` 实现（`r.client.Currency.Query().Where(currency.IsActive(true)).All(ctx)`）。
- [ ] **Step 3 (GREEN-B):** `service.go` 加：
```go
func (s *Service) SyncRates(ctx context.Context) (int, error) {
    active, err := s.repo.FindAllActive(ctx)
    if err != nil { return 0, fmt.Errorf("list active currencies: %w", err) }
    codes := make([]string, 0, len(active))
    for _, c := range active { codes = append(codes, c.Code) }
    rates, err := s.provider.FetchRates(ctx, codes)
    if err != nil { return 0, fmt.Errorf("fetch rates: %w", err) }
    updated := 0
    for i := range active {
        c := &active[i]
        r, ok := rates[c.Code]
        if !ok || r <= 0 { continue }
        if err := c.UpdateRate(r); err != nil { continue }
        if err := s.repo.Update(ctx, c); err != nil {
            return updated, fmt.Errorf("update currency %s: %w", c.Code, err)
        }
        updated++
    }
    return updated, nil
}
```
- [ ] **Step 4:** `go test ./internal/currency/...` → 通过。
- [ ] **Step 5:** commit `feat(currency): SyncRates bulk update from provider`。

---

## Task 3: Tenant preferred_currency + rate_sync_interval (ent + domain + repo)

**Files:**
- Modify: `server/internal/auth/ent/schema/tenant.go`
- Modify: `server/internal/auth/domain/entity.go`
- Modify: `server/internal/auth/domain/repository.go`
- Modify: `server/internal/auth/adapter/driven/repository/tenant_repo.go`

**Interfaces:**
```go
// ent/schema/tenant.go Fields() 追加：
field.String("preferred_currency").Default("CNY"),
field.Int("rate_sync_interval_hours").Default(8),

// domain/entity.go
type Tenant struct { /* existing */ ; PreferredCurrency string; RateSyncIntervalHours int }
func (t *Tenant) UpdatePreferences(preferredCurrency string, intervalHours int) error

// domain/repository.go
FindAllIntervalHours(ctx context.Context) ([]int, error)
```

- [ ] **Step 1:** `tenant.go` schema 加两字段。
- [ ] **Step 2:** `cd yucai/server && go generate ./internal/auth/ent/...`。
- [ ] **Step 3:** `domain/entity.go`：struct 加字段 + `UpdatePreferences`（校验 interval 1-168，trim+upper preferredCurrency 非空）。
- [ ] **Step 4:** `domain/repository.go` 加 `FindAllIntervalHours`。
- [ ] **Step 5:** `tenant_repo.go`：Save 加 `SetPreferredCurrency`/`SetRateSyncIntervalHours`；`toDomainTenant` 读两字段；实现 `FindAllIntervalHours`（`Select(tenant.FieldRateSyncIntervalHours).Ints(ctx)`）。
- [ ] **Step 6:** `go build ./...` → 通过。
- [ ] **Step 7:** commit `feat(auth): tenant preferred_currency + rate_sync_interval_hours`。

---

## Task 4: Auth GetPreferences/UpdatePreferences (proto + service + handler)

**Files:**
- Modify: `proto/auth/v1/auth.proto`
- Modify: `server/internal/auth/application/dto.go` + `service.go`
- Create: `server/internal/auth/application/service_test.go`
- Modify: `server/internal/auth/adapter/driving/grpc/auth_handler.go`
- Regenerate: server proto + client dart stub

**Interfaces (proto):**
```proto
service AuthService {
  // ... existing ...
  rpc GetPreferences(GetPreferencesRequest) returns (GetPreferencesResponse);
  rpc UpdatePreferences(UpdatePreferencesRequest) returns (UpdatePreferencesResponse);
}
message TenantPreferencesDTO { string preferred_currency = 1; int32 rate_sync_interval_hours = 2; }
message GetPreferencesRequest {}
message GetPreferencesResponse { TenantPreferencesDTO preferences = 1; }
message UpdatePreferencesRequest { string preferred_currency = 1; int32 rate_sync_interval_hours = 2; }
message UpdatePreferencesResponse { TenantPreferencesDTO preferences = 1; }
message UserDTO { /* fields 1-6 */ ; string preferred_currency = 7; }
```

- [ ] **Step 1:** 改 `auth.proto` 加上述。
- [ ] **Step 2:** `cd yucai && buf generate`（server）。确认 `auth.pb.go` 含新 RPC。
- [ ] **Step 3 (RED):** `service_test.go`：mock TenantRepository + mock CurrencyCodeChecker（`FindByCode` 控制 code 存在）。测 UpdatePreferences(valid CNY, 8) 成功；invalid currency code → 失败；interval 0/200 → 失败。运行 → 失败。
- [ ] **Step 4 (GREEN-A):** `dto.go` 加 `TenantPreferencesDTO` + `UpdatePreferencesRequest`。
- [ ] **Step 5 (GREEN-B):** `domain/repository.go` 加端口 `CurrencyCodeChecker { FindByCode(ctx, code) (bool, error) }`；`service.go` 注入 + 实现 `GetPreferences`/`UpdatePreferences`（校验 FindByCode 存在 + interval 1-168 + tenant.UpdatePreferences + repo.Save）。
- [ ] **Step 6 (GREEN-C):** `auth_handler.go` 加 handler（ctx 取 tenantID → service → DTO→proto）。
- [ ] **Step 7:** wire：`providers.go` 加 `provideCurrencyCodeChecker(*currencyrepo.CurrencyRepository) auth.CurrencyCodeChecker` 适配器。
- [ ] **Step 8:** `go test ./internal/auth/...` + `go build ./...` → 通过。
- [ ] **Step 9 (gen dart):** `proto/buf.gen.dart.yaml`：`remote: buf.build/grpc/grpc-dart` → local `protoc-gen-dart`；PATH 加 `%LOCALAPPDATA%\Pub\Cache\bin`；`buf generate --template proto/buf.gen.dart.yaml`。确认 `client/lib/proto/auth/v1/` 含新字段/RPC。
- [ ] **Step 10:** commit `feat(auth): GetPreferences/UpdatePreferences RPC + TenantPreferencesDTO`。

---

## Task 5: Scheduler

**Files:**
- Create: `server/internal/currency/scheduler/scheduler.go`
- Create: `server/internal/currency/scheduler/scheduler_test.go`

**Interfaces:**
```go
package scheduler
type IntervalSource interface { MinIntervalHours(ctx context.Context) int }
type RateSyncer interface { SyncRates(ctx context.Context) (int, error) }
type Scheduler struct { syncer RateSyncer; src IntervalSource; tick time.Duration; log *slog.Logger }
func NewScheduler(syncer RateSyncer, src IntervalSource, tick time.Duration, log *slog.Logger) *Scheduler
func (s *Scheduler) Start(ctx context.Context)   // 启动先 SyncRates，再每 tick 检查 elapsed >= interval → SyncRates
func (s *Scheduler) SyncNow(ctx context.Context) // 手动
```

- [ ] **Step 1 (RED):** `scheduler_test.go`：fake IntervalSource（返 1）+ mock RateSyncer（计数 SyncRates 调用）；tick=10ms，启动 50ms 内断言 SyncRates 调 ≥1；ctx cancel 后 goroutine 退出（用 sync.WaitGroup 或 channel）。运行 → 失败。
- [ ] **Step 2 (GREEN):** `scheduler.go`：`Start` 先 `SyncRates`（log count/error），记 `lastSync`；`time.NewTicker(s.tick)` 每 tick：`time.Since(lastSync) >= src.MinIntervalHours(ctx)*time.Hour` → `SyncRates` + 更新 lastSync + log。错误 log 不退出。`ctx.Done()` return。`SyncNow` 立即触发 + 更新 lastSync。
- [ ] **Step 3:** `go test ./internal/currency/scheduler/...` → 通过。
- [ ] **Step 4:** commit `feat(currency): rate sync scheduler`。

---

## Task 6: Wire + main.go 启动 scheduler

**Files:**
- Modify: `server/wire/providers.go` + `app.go` + `wire.go`
- Modify: `server/cmd/server/main.go`

- [ ] **Step 1:** `providers.go`：`provideExchangeRateProvider` 返回 `exchangerate.Provider`（`NewFrankfurterProvider()`）；`provideCurrencyService` 参数改接口。
- [ ] **Step 2:** 加 `provideIntervalSource(*authrepo.TenantRepository) scheduler.IntervalSource`（`MinIntervalHours` 调 `FindAllIntervalHours` 取 min，空/err 返 8）。
- [ ] **Step 3:** 加 `provideCurrencyScheduler(currencyapp.Service, IntervalSource) *scheduler.Scheduler`（tick=1h prod）。注：Service 实现 `RateSyncer`（有 `SyncRates`），可直接传 `*application.Service`。
- [ ] **Step 4:** `app.go` App 加 `CurrencyScheduler *scheduler.Scheduler`；`NewApp` 入参加。
- [ ] **Step 5:** `wire.go` provider 链加 interval source + scheduler；`NewApp` 入参加。
- [ ] **Step 6:** `cd yucai/server && go generate ./...`（重生成 wire_gen.go）。
- [ ] **Step 7:** `main.go`：`seedPresetCategories` 后、`Serve` 前：
```go
ctx, cancel := context.WithCancel(context.Background())
go app.CurrencyScheduler.Start(ctx)
```
shutdown 段（GracefulStop 前）`cancel()`。
- [ ] **Step 8:** `go build ./...` 通过；启动 server 确认 log "rate sync started" + 首次 SyncRates count。
- [ ] **Step 9:** commit `feat(server): wire frankfurter + scheduler, start on boot`。

---

## Task 7: Client currency convert helper (TDD)

**Files:**
- Create: `client/lib/currency/domain/currency_convert.dart`
- Create: `client/lib/currency/domain/currency_convert_test.dart`

**Interfaces:**
```dart
/// rates 相对 EUR base。同货币→原值；缺汇率/除零→回退原值。
int toPreferredCents(int cents, String fromCode, Map<String, double> rates, String preferred);
/// CNY→¥ / USD→$ / EUR→€ / GBP→£ / JPY→¥ / HKD→HK$ / 其他→code
String currencySymbol(String code);
```

- [ ] **Step 1 (RED):** `currency_convert_test.dart`：测 `toPreferredCents` 同货币原值；USD 1000 → CNY（rates {USD:1.08, CNY:7.81}）= `(1000*7.81/1.08).round()=7231`；缺 fromCode → 原值；rates[from]=0 → 原值。测 `currencySymbol` 各 code（SGD→"SGD"）。
- [ ] **Step 2 (GREEN):** 实现 `currency_convert.dart`。
- [ ] **Step 3:** `flutter test test/currency/domain/currency_convert_test.dart` → 通过。
- [ ] **Step 4:** commit `feat(client): currency convert + symbol helpers`。

---

## Task 8: Client CurrencyBloc + remote data source + DI

**Files:**
- Create: `client/lib/currency/domain/entities/currency_entity.dart`
- Create: `client/lib/currency/domain/repositories/currency_repository.dart`
- Create: `client/lib/currency/data/currency_remote_ds.dart`
- Create: `client/lib/currency/data/currency_repository_impl.dart`
- Create: `client/lib/currency/presentation/bloc/currency_bloc.dart`（+ event/state）
- Modify: `client/lib/core/di/injection.dart`

**Interfaces:**
```dart
class Currency { final String code, name, symbol; final double exchangeRate; final bool isActive; const Currency({...}); }
abstract class CurrencyRepository { Future<List<Currency>> list(); }
@LazySingleton() class CurrencyRemoteDataSource { Future<List<Currency>> list(); } // CurrencyServiceClient.listCurrencies(activeOnly:true)
@LazySingleton(as: CurrencyRepository) class CurrencyRepositoryImpl implements CurrencyRepository {}
@injectable class CurrencyBloc extends Bloc<CurrencyEvent, CurrencyState> {
  // events: LoadCurrenciesRequested, LoadPreferencesRequested
  // state: {rates: Map<String,double>, preferred: String, interval: int, status}
}
```

- [ ] **Step 1:** entity + repository abstract + remote ds（仿 `account_remote_ds.dart`，`CurrencyServiceClient(getIt<GrpcClient>().channel, interceptors:[authInterceptor])`）。
- [ ] **Step 2:** `CurrencyRepositoryImpl`（try/catch → Either<Failure,List>）。
- [ ] **Step 3:** `CurrencyBloc`：`LoadCurrenciesRequested` → repo.list() → state.rates=`{code:exchangeRate}`；`LoadPreferencesRequested` → `AuthRemoteDataSource.getProfile()`（UserDTO 含 preferred_currency）→ state.preferred/interval。
- [ ] **Step 4:** `dart run build_runner build --delete-conflicting-outputs`（生成 injection.config.dart）。
- [ ] **Step 5:** commit `feat(client): CurrencyBloc + remote data source`。

---

## Task 9: accounts_page 总计/小计换算 + Card 原货币符号 (widget TDD)

**Files:**
- Modify: `client/lib/account/presentation/pages/accounts_page.dart`
- Modify: `client/test/account/presentation/pages/accounts_page_test.dart`

**Behavior:**
- `_AccountsPageState._formatCents`（Card 余额）→ 按 `account.currencyCode` 用 `currencySymbol(code)` 前缀 + 原金额（**不换算**）。
- `_content` 的 `assetCents`/`liabCents`/`netCents` fold → 每账户 `toPreferredCents(a.currentBalanceCents, a.currencyCode, rates, preferred)` 累加。
- `_AccountsGroup.subtotal`（L851）→ 同样 per-account 换算 fold。
- `_AccountsHeader`/`_sumcard` 显示 → `currencySymbol(preferred)` + 换算金额。
- rates/preferred 来源：`BlocProvider<CurrencyBloc>`（router `/accounts` 包一层）+ `context.watch<CurrencyBloc>()`。

- [ ] **Step 1 (RED):** widget test：mock AccountBloc emit AccountsLoaded（USD 1000 cents + CNY 10000 cents）；mock CurrencyBloc emit state（rates {USD:1.08, CNY:7.81, EUR:1.0}, preferred=CNY）。断言：sumcard 总资产 `¥` + 换算金额（1000 USD × 7.81/1.08 = 7231 + 10000 = 17231 cents = ¥172.31）；USD Card 余额 `$` + 原金额 $10.00。运行 → 失败（当前 ¥ 混加）。
- [ ] **Step 2 (GREEN-A):** `_formatCents` 加 `String currencyCode` 参数，前缀 `currencySymbol(currencyCode)`；所有调用点（`_AccountCard` 余额）传 `a.currencyCode`。
- [ ] **Step 3 (GREEN-B):** `_content` 顶层 `final cstate = context.watch<CurrencyBloc>().state;`；fold 改 `toPreferredCents`：
```dart
final assetCents = active.where((a) => a.accountType == AccountType.asset).fold<int>(0,
    (s, a) => s + toPreferredCents(a.currentBalanceCents, a.currencyCode, cstate.rates, cstate.preferred));
```
- [ ] **Step 4 (GREEN-C):** `_AccountsHeader` 显示用 `currencySymbol(cstate.preferred)`；`_AccountsGroup` subtotal 换算 + preferred 符号（subtotal 通过构造传 rates/preferred 或 watch）。
- [ ] **Step 5 (GREEN-D):** `router.dart` `/accounts` builder 加 `MultiBlocProvider` 包 `CurrencyBloc`（create 时 `add(LoadCurrenciesRequested); add(LoadPreferencesRequested)`）。
- [ ] **Step 6:** `flutter test test/account/presentation/pages/accounts_page_test.dart` → 通过；全量 `flutter test` 未回归。
- [ ] **Step 7:** commit `feat(client): accounts page multi-currency conversion + symbol`。

---

## Task 10: account_detail Hero 原货币符号

**Files:**
- Modify: `client/lib/account/presentation/pages/account_detail_page.dart`
- Modify: `client/test/account/presentation/pages/account_detail_page_test.dart`

- [ ] **Step 1 (RED):** widget test：USD 账户 detail，Hero 余额 `$` 而非 `¥`。运行 → 失败。
- [ ] **Step 2 (GREEN):** `_fmt(a.currentBalanceCents)` → `_fmt(a.currentBalanceCents, a.currencyCode)`；`_fmt` 加 currencyCode 参数 + `currencySymbol` 前缀。Hero 不换算（按原账户货币，spec §3）。审阅其他 `_fmt`/`_fmtSigned` 调用点：账户自身字段（额度/本金/市值）同 `a.currencyCode`；交易 summary 同账户货币用 `a.currencyCode`。
- [ ] **Step 3:** `flutter test test/account/presentation/pages/account_detail_page_test.dart` → 通过。
- [ ] **Step 4:** commit `feat(client): account detail hero native currency symbol`。

---

## Task 11: 设置页 偏好货币 + 同步频率 (widget TDD)

**Files:**
- Create: `client/lib/settings/presentation/settings_page.dart`
- Create: `client/lib/settings/presentation/settings_page_test.dart`
- Modify: `client/lib/app/router.dart`
- Modify: `client/lib/app/widgets/app_shell.dart`

**Behavior:**
- `BlocBuilder<CurrencyBloc>` 读 currencies 列表 + 当前 preferred/interval。
- 「偏好货币」`DropdownButton<String>`（code + name）。
- 「汇率同步频率」选项 1h/8h/12h/24h。
- onChange → `AuthRemoteDataSource.updatePreferences(preferred, interval)`（新 client method 包装 `UpdatePreferences` RPC）→ 成功 toast + `CurrencyBloc.add(LoadPreferencesRequested)`。
- 御财 token：surface card `AppColors.surface` + `AppRadius.lgBorder` + `AppSpacing.md`；dropdown 选中 `AppColors.accent`。

- [ ] **Step 1 (RED):** `settings_page_test.dart`：pump SettingsPage（mock CurrencyBloc emit currencies [CNY,USD,EUR] + preferred=CNY + interval=8），断言 dropdown 显示 "CNY"，选 USD 触发 updatePreferences mock 被调。运行 → 失败。
- [ ] **Step 2 (GREEN-A):** 创建 `settings_page.dart`（StatelessWidget + BlocBuilder）。
- [ ] **Step 3 (GREEN-B):** `auth_remote_ds.dart` 加 `updatePreferences(preferred, interval)` + `getPreferences()` 包装 RPC；`AuthRepository` 加方法。
- [ ] **Step 4 (GREEN-C):** `router.dart` 加 `GoRoute(path: '/settings', builder: (_,__) => BlocProvider<CurrencyBloc>(create: getIt<CurrencyBloc>()..add(LoadCurrenciesRequested())..add(LoadPreferencesRequested()), child: SettingsPage()))`。
- [ ] **Step 5 (GREEN-D):** `app_shell.dart` `_NavItem('设置', Icons.settings_outlined, null)` → 加 `route: '/settings'`，侧栏 onTap + 移动 NavigationDestination 跳转。
- [ ] **Step 6:** `flutter test test/settings/...` → 通过；全量 `flutter test` 通过。
- [ ] **Step 7:** commit `feat(client): settings page for preferred currency + sync interval`。

---

## Task 12: 全量验证 + scheduler smoke

**Files:** 无新文件

- [ ] **Step 1:** `cd yucai/server && go test ./... -count=1` → 全绿（account/transaction + 新 currency/auth/scheduler）。
- [ ] **Step 2:** `cd yucai/client && flutter test` → 全绿（原 209 + 新 currency/settings）。
- [ ] **Step 3:** smoke：docker-up + server run，观察 log "rate sync started" + 首次 SyncRates count。client 启动 → USD 卡片 `$`，总计 ¥ 换算；设置页改偏好货币 → 总计随之变。
- [ ] **Step 4:** commit `chore: multi-currency full validation`（如有 fixup）。

---

## Self-Review

**Spec coverage（对照 spec §9 本期做）：**
- ✅ frankfurter provider + scheduler（可配置 8h）+ tenant preferred_currency/rate_sync_interval — Task 1-6
- ✅ client 换算 helper + accounts_page 总计/小计换算 + currencySymbol + Card 原货币符号 — Task 7, 9
- ✅ 设置页偏好货币 + 同步频率 UI — Task 11
- ✅ account_detail Hero 余额原货币符号 — Task 10
- ✅ scheduler 每 1h 唤醒检查 min(tenant interval) — Task 5
- ✅ 汇率缺失回退 — `toPreferredCents` Task 7 + `SyncRates` Task 2 skip

**Type consistency：**
- 金额全 int cents（client `toPreferredCents` 返 int `.round()`，server 无金额计算）。
- 汇率 float64（server domain，client `Map<String,double>`）。
- proto `rate_sync_interval_hours = int32`，Go `int`，client `int`。

**Placeholder：** 无 TODO；每步含完整代码或明确接口签名。

**风险：**
- 跨模块 auth→currency 校验：`CurrencyCodeChecker` 端口 + wire 适配（Task 4 Step 5/7）。
- wire provider 类型变（MockProvider→Provider 接口）：Task 6 Step 1 一次性改。
- dart buf generate：remote grpc-dart 缺失，必须 local plugin（Task 4 Step 9）。
- accounts_page 1700 行 + formatCents 多处：Task 9 审所有调用点。
- scheduler 御财首个后台任务：main.go graceful shutdown（ctx cancel）必须正确（Task 6 Step 7）。

## Execution Handoff

Plan complete。12 任务，顺序执行（Task 1-6 server → 7-11 client → 12 验证），每任务子代理 + 两阶段审查。
