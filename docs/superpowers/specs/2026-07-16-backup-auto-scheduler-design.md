# auto backup scheduler · 设计 spec(backup P1)

- **日期**: 2026-07-16
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: 待定(从 main `8d651a2` 开 `backup-auto-scheduler` feature 分支)
- **范围**: auto backup scheduler(定时自动备份)+ `CloudSettings` 持久化(`backup_settings` ent schema)+ client settings UI(配置 AutoBackup 开关 + interval)。**本地聚焦**(云字段 defer,云备份 cancelled)。P1 补齐自动备份(手动 + P0 pre-restore safety 已有)。

## 1. 背景

- **manual backup**(client `CreateBackup` RPC)+ **P0 pre-restore safety**(restore 前 auto CreateBackup,已合并 `8d651a2`)已有。
- **auto backup scheduler 缺**:定时自动备份未实现(memory P1)。
- **CloudSettings 是 TODO stub**([service.go:296-306](../../yucai/server/internal/backup/application/service.go#L296)):`SaveCloudSettings`/`GetCloudSettings` 空实现("Persist to a backup_settings table when schema is added"),无 ent schema/repo。`CloudSettings.AutoBackup` + `AutoBackupIntervalHours` 字段已有(handler/proto 映射),但**未持久化** → scheduler 无配置来源。

## 2. 目标

tenant 在 client 配置 AutoBackup + interval → server scheduler 定时自动 `CreateBackup(auto=true)` → client list 显示「自动」badge(复用 P0 的 `Backup.Auto`)。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 持久化范围 | 本地 `AutoBackup` + `AutoBackupIntervalHours` | 云字段(Provider/WebDAV/OAuth)defer —— 云备份 cancelled(本地优先);struct 云字段保留但不持久化 |
| 2 | scheduler 模式 | 照 holding scheduler | `IntervalSource` 门控 + narrow `BackupCreator` interface + `Start`/`SyncNow`/`doSync` + slog(成熟范式) |
| 3 | 跨 tenant | `TenantLister` fan-out | 照 goal scheduler(每 tenant 各自 AutoBackup + interval);per-tenant 错误 continue |
| 4 | ent schema | `backup_settings` 新表 | `tenant_id`(unique PK)+ `auto_backup` bool + `auto_backup_interval_hours` int32;**ent generate**(memory 手维护) |
| 5 | client UI | settings 子页 | AutoBackup switch + interval picker,对齐 backup/tag/template settings 子页模式 |
| 6 | Auto 标识 | 复用 `Backup.Auto`(P0) | auto backup `Auto=true` → client「自动」badge(链路 P0 已通) |

## 4. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| `backup_settings` ent schema + ent generate | 云字段持久化(Provider/WebDAV/OAuth,cancelled 云备份) |
| `BackupSettingsRepository`(Save/Get by tenant)+ impl | 云备份 / 多设备同步(cancelled) |
| `SaveCloudSettings`/`GetCloudSettings` 实现(替 TODO) | gzip 压缩(P2) |
| `backup/scheduler`(照 holding + 跨 tenant fan-out) | filename 冲突(已 P0 修) |
| wire/main 注入 + `Start` | |
| client `BackupSettingsPage`(switch + interval)+ bloc + router 入口 | |
| proto(`CloudSettingsDTO` 已有 AutoBackup + interval,handler 已映射) | |

## 5. 架构

| 层 | 组件 | 职责 |
|---|---|---|
| **ent schema**(新)| `backup/ent/schema/backup_settings.go` | `tenant_id` unique + `auto_backup`(default false)+ `auto_backup_interval_hours`(default 24);ent generate |
| **domain**(新)| `BackupSettings` entity + `BackupSettingsRepository` interface(`Save`/`GetByTenant`)+ `AutoBackupSource`(scheduler 配置源) | 配置持久化 port |
| **adapter/driven**(新)| `BackupSettingsRepositoryImpl`(ent) | repo 实现 |
| **application**(改)| `SaveCloudSettings`/`GetCloudSettings` 实现(替 TODO) | 持久化 AutoBackup + interval(云字段忽略) |
| **scheduler**(新包)| `backup/scheduler/scheduler.go` | 照 holding:`BackupCreator`(narrow `CreateBackup`)+ `TenantLister`(跨 tenant)+ `AutoBackupSource`(per-tenant 配置)+ tick + 跨 tenant fan-out + `if AutoBackup && elapsed >= interval → CreateBackup(auto=true)` |
| **wire/main** | 注入 scheduler + `Start`(照 currency/holding scheduler) | 后台启动 |
| **client** | `BackupSettingsPage`(switch + interval picker)+ `BackupSettingsBloc` + router `/settings/backup` + settings 入口 tile | 配置 UI |

## 6. 核心改动(关键)

**backup_settings ent schema**(新):
```go
// backup/ent/schema/backup_settings.go
type BackupSettings struct{ ent.Schema }

func (BackupSettings) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("tenant_id", uuid.UUID{}).Unique(),
		field.Bool("auto_backup").Default(false),
		field.Int32("auto_backup_interval_hours").Default(24),
	}
}
func (BackupSettings) Edges() []ent.Edge { return nil } // 跨模块无 ent edge(照 backup.go)
```
→ ent generate(`go generate ./...` 或手维护生成代码,memory `yucai-wire-handmaintained`)。

**scheduler**(照 holding scheduler):
```go
// backup/scheduler/scheduler.go
type BackupCreator interface {
	CreateBackup(ctx context.Context, tenantID uuid.UUID, encrypted bool, password string, auto bool) (*application.BackupDTO, error)
}
type TenantLister interface { FindAllIDs(ctx context.Context) ([]uuid.UUID, error) } // 照 goal scheduler
type AutoBackupSource interface {
	AutoBackupSettings(ctx context.Context, tenantID uuid.UUID) (autoBackup bool, intervalHours int32, err error)
}

type Scheduler struct {
	creator BackupCreator; tenants TenantLister; src AutoBackupSource
	tick    time.Duration; log *slog.Logger
	mu      sync.Mutex
	last    map[uuid.UUID]time.Time // per-tenant last auto-backup time
}

// Start: tick → fan-out tenants → per tenant: (autoBackup, interval, err) = src.AutoBackupSettings
//   if autoBackup && time.Since(last[tenant]) >= interval → CreateBackup(auto=true); update last[tenant]
//   per-tenant err → slog + continue
```

**application SaveCloudSettings/GetCloudSettings**(替 TODO):repo.Save / repo.GetByTenant(只 AutoBackup + interval)。

**client BackupSettingsPage**:AutoBackup switch + interval picker(如 12h/24h/48h/7d)→ `SaveCloudSettings` RPC。

## 7. 数据流

client 配置(`SaveCloudSettings` AutoBackup=true, interval=24h)→ server 持久化 `backup_settings` → scheduler tick(如 1h)→ 跨 tenant fan-out → 该 tenant `AutoBackup=true && time.Since(last)>=24h` → `CreateBackup(auto=true)` → client list「自动」badge。

## 8. 测试

- **server ent/repo**:`BackupSettingsRepository` Save/Get roundtrip;unique tenant_id(重复 Save = upsert)
- **scheduler**(domain 纯逻辑 + application 集成):
  - AutoBackup=true && interval elapsed → `CreateBackup(auto=true)` 调用 1 次
  - AutoBackup=false → 不调用
  - interval 未到 → 不调用
  - 跨 tenant fan-out:多 tenant 各自独立;per-tenant `AutoBackupSource` err → slog + continue(不 abort 批次)
- **application**:`SaveCloudSettings`/`GetCloudSettings` 持久化 roundtrip(只 AutoBackup + interval)
- **client**:`BackupSettingsPage` switch + interval → `SaveCloudSettings` RPC;加载时 `GetCloudSettings` 预填

## 9. 风险

1. **ent generate**:`backup_settings` 新 schema 需 ent generate;memory `yucai-wire-handmaintained` 记 wire/ent 工具链 tree-wide 坏,生成后可能需手修(如 package 名、或手写 ent 代码)。plan 预留 ent generate task + 手修 fallback。
2. **wire 手改**:scheduler + `BackupSettingsRepository` + `AutoBackupSource` + `TenantLister` 注入(`wire_gen.go` 手改,镜像现有 provider 顺序)。
3. **跨 tenant fan-out**:`TenantLister.FindAllIDs`(`auth.TenantRepository`,照 goal scheduler);per-tenant 错误 continue(best-effort)。
4. **interval 门控**:per-tenant `last`(map + mu 并发安全);scheduler 进程重启 last 丢(重启后首 tick 可能立即建 —— 可接受,或持久化 last defer)。
5. **AutoBackupSource per-tenant**:每 tenant 各自 AutoBackup + interval(非全局),照 goal scheduler 模式。
6. **scheduler 启动**:`main.go` `Start`(照 currency/holding scheduler,goroutine + ctx cancel)。
7. **client settings UI**:新建 `BackupSettingsPage`(对齐 backup/tag/template settings 子页模式);router `/settings/backup`(若已有 backup 子页则加配置区,或新子页 `/settings/backup/auto`)。
8. **proto**:`CloudSettingsDTO` 已有 AutoBackup + interval(handler 已映射),无需 proto regen。

## 10. 参考

- holding scheduler:[scheduler.go](../../yucai/server/internal/holding/scheduler/scheduler.go)(`IntervalSource` + `Start`/`SyncNow`/`doSync` 范式)
- goal scheduler:跨 tenant `TenantLister` fan-out(memory `holding-asset-management-todo` D-goal)
- P0 pre-restore:`Backup.Auto` + `CreateBackup` auto 参数(已合并 `8d651a2`)
- backup server spec:[2026-07-13-backup-server-design.md](2026-07-13-backup-server-design.md)(CloudSettings TODO stub)
- memory:`yucai-wire-handmaintained`(ent/wire 手维护)、`holding-asset-management-todo`(P1 auto scheduler defer)
