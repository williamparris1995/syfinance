# auto backup scheduler Implementation Plan(backup P1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Steps use checkbox (`- [ ]`).

**Goal:** tenant 配置 AutoBackup + interval → server scheduler 定时 `CreateBackup(auto=true)` → client「自动」badge。

**Architecture:** server ent(`backup_settings`)+ repo + `SaveCloudSettings`/`GetCloudSettings` 实现 + scheduler(照 holding + 跨 tenant fan-out)+ wire/main;client settings UI。本地聚焦(云字段 defer)。

**Tech Stack:** Go(ent + DDD + wire 手改)+ Flutter(bloc + injectable)。

## Global Constraints

- **server + client**(P1 完整);proto `CloudSettingsDTO` 已有 AutoBackup + interval(handler 已映射),**无 proto regen**。
- **ent generate**:`backup_settings` 新 schema,`go generate ./...` 或手维护生成代码(memory `yucai-wire-handmaintained`:ent/wire 工具链 tree-wide 坏,生成后可能手修 package 名;若 generate 失败手写 ent 代码)。
- **wire 手改**(`wire_gen.go`,memory):scheduler + repo + AutoBackupSource + TenantLister 注入,镜像现有 provider 顺序。
- English slog(scheduler 日志,无 CJK)。
- 照现有模式:**holding scheduler**(IntervalSource + Start/SyncNow/doSecret)、**goal scheduler**(TenantLister 跨 tenant fan-out)、**backup ent/repo**(backup.go/backup_repo.go)、**backup settings 子页**(client /settings/backup 既有)。
- TDD + per-task commit;测试 `cd /e/projects/syfinance/yucai/server && go test ./internal/backup/... -count=1` / `cd yucai/client && flutter test`。
- 参考 spec:[2026-07-16-backup-auto-scheduler-design.md](../specs/2026-07-16-backup-auto-scheduler-design.md)。

---

### Task 1: `backup_settings` ent schema + generate

**Files:**
- Create: `yucai/server/internal/backup/ent/schema/backup_settings.go`
- Generate: `backup/ent/` 生成代码(backup_settings entity/client/mutation...)

**模式**:照 [backup.go](../../yucai/server/internal/backup/ent/schema/backup.go)(`ent.Schema` + Annotations + TenantMixin + Fields + Edges nil + Indexes nil)。

- [ ] **Step 1: 写 schema**

```go
package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema/field"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

type BackupSettings struct{ ent.Schema }

func (BackupSettings) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}
func (BackupSettings) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}} // tenant_id
}
func (BackupSettings) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.Bool("auto_backup").Default(false),
		field.Int32("auto_backup_interval_hours").Default(24),
	}
}
func (BackupSettings) Edges() []ent.Edge    { return nil }
func (BackupSettings) Indexes() []ent.Index { return nil }
```

- [ ] **Step 2: ent generate + 手修**

`go generate ./...`(或 ent 工具);若 tree-wide 坏(memory),手写/手修生成代码(`backup/ent/backupsettings*.go` + client.go 加 `BackupSettings` client + migrate)。确认 `go build ./...` 0。

- [ ] **Step 3: Commit**

```bash
git add yucai/server/internal/backup/ent/schema/backup_settings.go yucai/server/internal/backup/ent/
git commit -m "feat(backup/ent): backup_settings schema(auto_backup + interval_hours,TenantMixin)"
```

---

### Task 2: `BackupSettingsRepository` + `SaveCloudSettings`/`GetCloudSettings` 实现

**Files:**
- Create: `yucai/server/internal/backup/domain/backup_settings.go`(entity + repository interface)
- Create: `yucai/server/internal/backup/adapter/driven/repository/backup_settings_repo.go`(ent impl)
- Modify: `yucai/server/internal/backup/application/service.go`(`SaveCloudSettings`/`GetCloudSettings` 替 TODO + Service 加 `settingsRepo` 字段 + NewService 加参数)
- Modify: `yucai/server/wire/wire_gen.go`(注入 BackupSettingsRepository,手改 memory)

**模式**:照 [backup_repo.go](../../yucai/server/internal/backup/adapter/driven/repository/backup_repo.go)(ent repo 模式)+ domain port 模式。

- [ ] **Step 1: domain entity + interface**

```go
// domain/backup_settings.go
type BackupSettings struct {
	ID                      uuid.UUID
	TenantID                uuid.UUID
	AutoBackup              bool
	AutoBackupIntervalHours int32
}
type BackupSettingsRepository interface {
	Save(ctx context.Context, s *BackupSettings) error                 // upsert by tenant
	GetByTenant(ctx context.Context, tenantID uuid.UUID) (*BackupSettings, error)
}
```

- [ ] **Step 2: ent impl**(照 backup_repo.go;Save 用 GetByTenant → exist? update : create)

- [ ] **Step 3: application SaveCloudSettings/GetCloudSettings 替 TODO**

```go
// service.go Service 加 settingsRepo BackupSettingsRepository;NewService 加参数
func (s *Service) SaveCloudSettings(ctx context.Context, settings CloudSettings) error {
	return s.settingsRepo.Save(ctx, &domain.BackupSettings{
		TenantID: settings.TenantID, AutoBackup: settings.AutoBackup,
		AutoBackupIntervalHours: settings.AutoBackupIntervalHours,
	})
}
func (s *Service) GetCloudSettings(ctx context.Context, tenantID uuid.UUID) (*CloudSettings, error) {
	s, err := s.settingsRepo.GetByTenant(ctx, tenantID)
	if err != nil { return &CloudSettings{TenantID: tenantID}, nil } // 未配置 → 默认
	return &CloudSettings{TenantID: tenantID, AutoBackup: s.AutoBackup, AutoBackupIntervalHours: s.AutoBackupIntervalHours}, nil
}
```

- [ ] **Step 4: wire_gen.go 手改**(注入 BackupSettingsRepository 到 NewService,memory 顺序)

- [ ] **Step 5: 测试**(repo roundtrip Save/Get upsert + SaveCloudSettings/GetCloudSettings)+ `go build ./...` 0 + commit

---

### Task 3: `backup/scheduler`(照 holding + 跨 tenant fan-out)

**Files:**
- Create: `yucai/server/internal/backup/scheduler/scheduler.go`
- Test: `yucai/server/internal/backup/scheduler/scheduler_test.go`

**模式**:照 [holding/scheduler/scheduler.go](../../yucai/server/internal/holding/scheduler/scheduler.go)(`IntervalSource` + narrow interface + Start/SyncNow/doSync + slog)+ goal scheduler(`TenantLister` 跨 tenant fan-out,per-tenant err continue)。

- [ ] **Step 1: 写 scheduler**(TDD:先测 AutoBackup=true&&elapsed→CreateBackup / AutoBackup=false→不调 / 未到 interval→不调 / 跨 tenant fan-out)

```go
package scheduler
// BackupCreator narrow interface(application.Service.CreateBackup 子集)
type BackupCreator interface {
	CreateBackup(ctx context.Context, tenantID uuid.UUID, encrypted bool, password string, auto bool) (*application.BackupDTO, error)
}
type TenantLister interface { FindAllIDs(ctx context.Context) ([]uuid.UUID, error) } // auth.TenantRepository
type AutoBackupSource interface {
	AutoBackupSettings(ctx context.Context, tenantID uuid.UUID) (autoBackup bool, intervalHours int32, err error)
}
type Scheduler struct {
	creator BackupCreator; tenants TenantLister; src AutoBackupSource
	tick    time.Duration; log *slog.Logger
	mu   sync.Mutex
	last map[uuid.UUID]time.Time
}
// Start(ctx): ticker 循环 → fan-out tenants → per tenant:
//   (auto, interval, err) = src.AutoBackupSettings; if err → slog + continue
//   if auto && time.Since(last[t]) >= interval*hour → CreateBackup(auto=true); last[t]=now
```

- [ ] **Step 2: 测**(domain 纯逻辑用 fake BackupCreator/TenantLister/AutoBackupSource)+ commit

---

### Task 4: wire 注入 + main.go `Start`

**Files:**
- Modify: `yucai/server/wire/wire_gen.go`(BackupScheduler provider + 注入,memory 手改)
- Modify: `yucai/server/cmd/server/main.go`(scheduler.Start goroutine + ctx cancel)

**模式**:照 currency/holding scheduler wire + main Start(memory backup scheduler 第 N 个 scheduler)。

- [ ] **Step 1: wire 注入** BackupScheduler(NewScheduler(svc, tenantRepo, settingsRepo-source, tick, log))+ main `go scheduler.Start(ctx)`(照 currency/holding)

- [ ] **Step 2: `go build ./...` 0 + server 启动日志确认 scheduler 起 + commit**

---

### Task 5: client `BackupSettingsPage` + bloc + router

**Files:**
- Create: `yucai/client/lib/backup/presentation/pages/backup_settings_page.dart`(AutoBackup switch + interval picker)
- Create: `yucai/client/lib/backup/presentation/bloc/backup_settings_bloc.dart`(event/state: LoadSettings / SaveSettings)
- Modify: client backup remote_ds/repo_impl(SaveCloudSettings/GetCloudSettings RPC,handler 已有)
- Modify: router `/settings/backup` + settings 入口

**模式**:对齐 backup/tag/template settings 子页(DataCard + FormSection + switch/picker)+ bloc(`@injectable`,照 BackupBloc/TagBloc 模式)。

- [ ] **Step 1: remote_ds/repo_impl 加 SaveCloudSettings/GetCloudSettings**(proto CloudSettingsDTO 已有;AuthRetryCaller)

- [ ] **Step 2: BackupSettingsBloc**(LoadSettingsRequested → GetCloudSettings 预填;SaveSettingsRequested → SaveCloudSettings)

- [ ] **Step 3: BackupSettingsPage**(AutoBackup switch + interval picker[12h/24h/48h/7d] → SaveSettings)+ router /settings/backup 入口

- [ ] **Step 4: 测试**(widget test switch/picker → SaveCloudSettings)+ `flutter test` 基线 + commit

---

## 自审记录(plan 作者)

- **Spec coverage**:spec §5 架构 → Task 1-5(ent/repo/scheduler/wire/client)。✓
- **模式指引**:Plan 给关键 verbatim(ent schema / SaveCloudSettings / scheduler skeleton)+ 模式指引(repo/wire/main/client 照 backup/holding/currency 既有,implementer 探索细节 — 御财"plan 起点非圣经"风格)。
- **风险**:Task 1 ent generate(tree-wide 坏手修 memory)、Task 4 wire 手改 —— 各 task implementer 遇到时 controller 协助(grep caller + 手改指引)。
- **proto**:无 regen(CloudSettingsDTO + handler 已有)。
