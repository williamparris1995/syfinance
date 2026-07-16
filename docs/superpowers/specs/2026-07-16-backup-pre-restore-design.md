# pre-restore safety backup · 设计 spec(backup P0)

- **日期**: 2026-07-16
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: 待定(从 main 开 `backup-pre-restore` feature 分支)
- **范围**: `RestoreBackup` 前 auto `CreateBackup`(pre-restore 安全网,未加密)→ 正常 restore → **成功删 pre-restore / 失败留**。解决 restore 中途失败/崩溃致数据丢失的 prod 风险。是原 defer「跨模块原子 restore」的**务实方案** —— 严格跨模块 ACID 成本过高(各模块独立 ent Client/driver),pre-restore backup 安全网覆盖所有 restore 失败场景。

## 1. 背景

当前 `RestoreBackup`([service.go:100](../../yucai/server/internal/backup/application/service.go#L100)):Download → Decrypt → Purge(8 模块逐个 `DeleteByTenant`)→ Import(8 模块逐个 `Save`),**无事务**。任一模块 Purge/Import 失败或进程崩溃 → 已 Purge 数据未 Import 回 → **数据丢失**(如 Import transaction 失败,transaction 已被 Purge)。

memory 标「跨模块原子 restore(raw sql.Tx,最大 prod 风险)」。但探索确认严格跨模块 ACID 成本过高:各模块(holding/transaction/goal/debt/...)独立 ent Client/独立 driver(`Client.BeginTx` 是 per-Client),跨 Client 共享一个 `*sql.Tx` 需架构大改(共享底层 driver + 8 个 Repository tx 接口 + wire 重构)。

## 2. 目标

restore 失败/崩溃时,tenant 数据可从**自动安全网备份**完整恢复。务实替代严格 ACID,成本可控,契合个人本地应用。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 原子性方案 | **B: pre-restore backup 安全网** | 严格 ACID(A)架构成本过高;saga(C)补偿也可能失败。B 覆盖所有 restore 失败(安全网恢复),成本低 |
| 2 | B 强度 | **B-min(纯 pre-restore backup)** | 单模块 ent.Tx(B-full)需 8 模块 repo tx 改造(ent `*Client`/`*Tx` 类型不统一),边际(preston-restore backup 已兜底该场景);YAGNI |
| 3 | 标识机制 | **filename prefix** | `pre_restore_<ts>` prefix + domain `BackupSource`,无 schema/proto 改;P1 scheduler 共用(`scheduled_` prefix 同体系) |
| 4 | 加密 | pre-restore 未加密(`false`) | 自动建无需 password;短期安全网,restore 成功即删 |
| 5 | 保留策略 | 成功删 / 失败留 | 成功后清理(避免 list 累积);失败留供用户恢复 |

## 4. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| `RestoreBackup` 开头 auto `CreateBackup`(pre-restore 安全网) | 严格跨模块 DB ACID(方案 A,架构大改) |
| domain `BackupSource`(manual/pre_restore/scheduled)+ `NewBackup` filename prefix | 单模块 ent.Tx(B-full,8 repo tx 改造) |
| `RestoreBackup` 成功删 pre-restore / 失败留 | P1 auto backup scheduler(独立 spec,P0 共用 BackupSource) |
| client UI badge(解析 filename prefix) | pre-restore 加密(短期未加密) |
| restore 失败时 pre-restore 留 + 可恢复测试 | gzip 压缩 / filename 秒级冲突(P2) |

## 5. 架构

| 层 | 组件 | 职责 |
|---|---|---|
| **domain**(新)| `BackupSource` enum(`manual`/`pre_restore`/`scheduled`)+ `prefix()` | 标识 backup 来源 → filename 前缀;`scheduled` P1 预留 |
| **domain**(改)| `NewBackup(tenantID, provider, encrypted, source)` | filename = `<source>_<ts>.<suffix>`(`source==""` 默认 manual) |
| **application**(改)| `CreateBackup(..., source BackupSource)` | 加 source 参数(server 内部,非 proto);handler→manual,RestoreBackup→pre_restore |
| **application**(改)| `RestoreBackup` | 开头 `CreateBackup(pre_restore)` → 抽 `restoreNoSafety`(原 logic)→ 成功删 pre-restore(失败留) |
| **adapter/driving**(改)| `CreateBackup` handler | 传 `source=manual`(client RPC 无 source 字段) |
| **client**(改)| backup list `BackupCard` | 解析 filename prefix 显示 badge(pre_restore→"恢复点(自动)") |

## 6. 核心改动

**domain `BackupSource`**([entity.go](../../yucai/server/internal/backup/domain/entity.go)):

```go
// BackupSource 标识 backup 的创建来源,映射 filename 前缀(供 client UI 解析 badge)。
type BackupSource string

const (
    BackupSourceManual     BackupSource = "manual"      // 用户手动(client CreateBackup RPC)
    BackupSourcePreRestore BackupSource = "pre_restore" // RestoreBackup 前自动安全网
    BackupSourceScheduled  BackupSource = "scheduled"   // P1 auto scheduler 预留
)

func NewBackup(tenantID uuid.UUID, provider BackupProvider, encrypted bool, source BackupSource) (*Backup, error) {
    if provider == 0 {
        return nil, fmt.Errorf("provider must be specified")
    }
    if source == "" {
        source = BackupSourceManual
    }
    now := time.Now()
    suffix := ".json"
    if encrypted {
        suffix = ".enc"
    }
    return &Backup{
        ID:        uuid.New(),
        TenantID:  tenantID,
        Provider:  provider,
        Filename:  fmt.Sprintf("%s_%s%s", source, now.Format("20060102_150405"), suffix),
        Encrypted: encrypted,
        Version:   1,
        CreatedAt: now,
        UpdatedAt: now,
    }, nil
}
```

**application `RestoreBackup`**([service.go:100](../../yucai/server/internal/backup/application/service.go#L100)):

```go
// RestoreBackup downloads → decrypts → per-module Purge + Import.
// Before purging, auto-creates a pre-restore safety backup (unencrypted); on
// success it is removed, on failure/crash it remains so the user can recover
// the pre-restore state. This is the pragmatic substitute for cross-module DB
// atomicity (each module has its own ent client/driver; a shared *sql.Tx would
// require an architecture-wide refactor — see spec §1).
func (s *Service) RestoreBackup(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
    // 1. Safety net: auto-create a pre-restore backup BEFORE touching any data.
    preRestore, err := s.CreateBackup(ctx, tenantID, false, "", domain.BackupSourcePreRestore)
    if err != nil {
        return fmt.Errorf("pre-restore safety backup: %w", err)
    }

    // 2. Restore (download/decrypt/purge/import — the original logic).
    restoreErr := s.restoreNoSafety(ctx, tenantID, backupID, password)

    // 3. On success, remove the safety net (best-effort). On failure, leave it.
    if restoreErr == nil {
        if delErr := s.DeleteBackup(ctx, tenantID, preRestore.ID); delErr != nil {
            slog.Error("pre-restore safety cleanup failed", "backup_id", preRestore.ID, "err", delErr)
        }
    }
    return restoreErr
}

// restoreNoSafety holds the pre-safety-net restore logic (download/decrypt/
// purge/import). Extracted so RestoreBackup can wrap it with the safety net.
func (s *Service) restoreNoSafety(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
    // ... 原 RestoreBackup body:FindByID → Download → Decrypt → Unmarshal →
    //     orderedPortsForPurge Purge → orderedPortsForImport Import ...
}
```

`CreateBackup` 加 `source BackupSource` 参数(末尾),handler 传 `BackupSourceManual`。

## 7. 数据流 / 正确性

- **restore 成功**:pre-restore 建后删 → list 不累积。
- **restore 失败**(Import 报错):pre-restore 留 → 用户 ListBackups 可见(badge "恢复点(自动)")→ `RestoreBackup(preRestore.ID)` 恢复到 restore 前。
- **崩溃**(pre-restore 建后、restore 中):pre-restore 已 upload+save(持久)→ 用户重启后用它恢复。
- **pre-restore 创建失败**:RestoreBackup 开头 CreateBackup 失败 → 返回错误,**不 purge**(原数据安全;失败发生在 purge 前)。

## 8. 测试

- `RestoreBackup` 成功:pre-restore 建后删(ListBackups 不含 pre-restore)
- `RestoreBackup` 失败(注入 Import 报错):pre-restore 留 + ListBackups 找到 + 其数据 = restore 前 tenant 数据
- `RestoreBackup` pre-restore 创建失败(注入 export 报错):返回错误,原数据未动(无 Purge 发生)
- `NewBackup` filename:各 `BackupSource` 生成正确 prefix(`manual_<ts>.json` / `pre_restore_<ts>.json` / `scheduled_<ts>.json`);空 source 默认 manual
- client UI badge:`BackupCard` 解析 filename prefix 正确显示(手动无 badge / pre_restore "恢复点(自动)")

## 9. 风险

1. **pre-restore 创建失败**:RestoreBackup 开头 `CreateBackup` 失败 → 返回错误,不 purge(原数据安全)。安全(失败在 purge 前)。
2. **pre-restore 删除失败(restore 成功后)**:best-effort + `slog.Error`,非 fatal。list 残留一个 pre-restore(用户可手动删)。非数据风险。
3. **崩溃时机**:pre-restore 建后(已 upload+save 持久)、restore 中崩溃 → pre-restore 在,用户用它恢复。✓ 安全网生效。
4. **未加密 pre-restore 安全性**:短期(成功即删)、未加密、存本地。本地优先应用可接受;若敏感后续加加密(defer)。
5. **filename 秒级冲突**:同秒 manual + pre_restore 可能冲突(prefix 不同故实际不冲突;但同 source 同秒冲突 → P2 解决)。
6. **`NewBackup`/`CreateBackup` 签名改**(加 source):grep 全 caller(handler / test / 其他 CreateBackup 调用)更新;`source` 末位参数降低误用。

## 10. 参考

- backup server spec:[2026-07-13-backup-server-design.md](2026-07-13-backup-server-design.md)(RestoreBackup 原实现 + defer 原子 restore)
- memory:`holding-asset-management-todo`(跨模块原子 restore defer,client confirm 警告兜底)
- `RestoreBackup` / `CreateBackup` / `NewBackup`:[service.go](../../yucai/server/internal/backup/application/service.go) L100/L38 + [entity.go](../../yucai/server/internal/backup/domain/entity.go) L68
- 8 exporter:`backup/adapter/driven/exporter/`(account/transaction/debt/budget/goal/holding/template/tag)
