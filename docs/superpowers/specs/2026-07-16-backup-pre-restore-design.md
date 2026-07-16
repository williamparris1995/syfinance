# pre-restore safety backup · 设计 spec(backup P0)

- **日期**: 2026-07-16
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)— **勘误版**(初版 `89af4d4` 设想 `BackupSource` enum + filename prefix + client UI 改,基于「无 Auto 字段」的错误假设;plan 探索发现 `Backup.Auto` 字段已存在 + client `BackupCard` 已 badge「自动」,改用现有字段,设计大幅简化)
- **分支**: 待定(从 main 开 `backup-pre-restore` feature 分支)
- **范围**: `RestoreBackup` 前 auto `CreateBackup`(pre-restore 安全网,未加密,`Auto=true`)→ 正常 restore → **成功删 pre-restore / 失败留**。解决 restore 中途失败/崩溃致数据丢失的 prod 风险。务实替代严格跨模块 ACID(成本过高)。

## 1. 背景

当前 `RestoreBackup`([service.go:100](../../yucai/server/internal/backup/application/service.go#L100)):Download → Decrypt → Purge(8 模块逐个 `DeleteByTenant`)→ Import(8 模块逐个 `Save`),**无事务**。任一模块失败或进程崩溃 → 已 Purge 数据未 Import 回 → **数据丢失**。

memory 标「跨模块原子 restore(raw sql.Tx,最大 prod 风险)」。探索确认严格跨模块 ACID 成本过高:各模块独立 ent Client/driver(`Client.BeginTx` per-Client),跨 Client 共享 `*sql.Tx` 需架构大改(共享 driver + 8 repo tx 接口 + wire)。

**关键发现(勘误)**:`Backup.Auto` 字段**已存在**(server [entity.go:62](../../yucai/server/internal/backup/domain/entity.go#L62) + client [backup_entity.dart:12](../../yucai/client/lib/backup/domain/entities/backup_entity.dart#L12)),handler `dtoToProto` 已映射 `Auto`,client `BackupCard` 已 `if (backup.auto) _chip('自动')` 显示 badge。pre-restore backup 设 `Auto=true` 即自动获 UI「自动」标识 —— 无需新 enum / filename prefix / client 改。

## 2. 目标

restore 失败/崩溃时,tenant 数据可从**自动安全网备份**(Auto=true,UI「自动」badge)完整恢复。务实替代严格 ACID,成本可控。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 原子性方案 | **B: pre-restore backup 安全网** | 严格 ACID(A)架构成本过高;saga(C)补偿也可能失败。B 覆盖所有 restore 失败(安全网恢复),成本低 |
| 2 | B 强度 | **B-min(纯 pre-restore backup)** | 单模块 ent.Tx(B-full)需 8 repo tx 改造(ent `*Client`/`*Tx` 类型不统一),边际(preston-restore backup 已兜底);YAGNI |
| 3 | 标识机制 | **用现有 `Backup.Auto` 字段**(勘误) | 探索发现 Auto 链路完整(server domain + DTO + proto + client entity + BackupCard badge);pre-restore 设 `Auto=true` 即获 UI「自动」标识,无需 `BackupSource` enum / filename prefix / client UI 改 |
| 4 | 加密 | pre-restore 未加密(`false`) | 自动建无需 password;短期安全网,restore 成功即删 |
| 5 | 保留策略 | 成功删 / 失败留 | 成功后清理(避免 list 累积);失败留供用户恢复(UI「自动」badge 识别) |

## 4. 范围边界

| 在范围(server-only) | 不在范围(defer) |
|---|---|
| `NewBackup` 加 `auto` 参数(设 `Backup.Auto`,字段已存在) | `BackupSource` enum(用 Auto bool 足够) |
| `CreateBackup` 加 `auto` 参数(RestoreBackup→true,handler→false) | filename prefix(用 Auto 字段非 prefix) |
| `RestoreBackup` safety(开头 `CreateBackup(auto=true)` → `restoreNoSafety` → 成功删/失败留) | client UI 改(BackupCard 已 badge backup.auto) |
| `CreateBackup` handler 传 `auto=false` | 严格跨模块 DB ACID(方案 A) |
| restore safety 测(成功删/失败留/pre-restore 创建失败) | 单模块 ent.Tx(B-full)/ P1 scheduler / gzip(P2) |

**client 零改动**(BackupCard 已 `if (backup.auto) _chip('自动')`)。

## 5. 架构

| 层 | 组件 | 职责 |
|---|---|---|
| **domain**(改)| `NewBackup(tenantID, provider, encrypted, auto)` | 加 `auto` 参数,设 `Backup.Auto`(字段已存在 entity.go:62) |
| **application**(改)| `CreateBackup(..., auto bool)` | 加 `auto` 参数(末位);传给 `NewBackup` |
| **application**(改)| `RestoreBackup` | 开头 `CreateBackup(false, "", auto=true)` → `restoreNoSafety`(原 logic)→ 成功删 pre-restore(失败留) |
| **adapter/driving**(改)| `CreateBackup` handler | 传 `auto=false`(client 手动 RPC) |
| **client** | **无改** | `BackupCard` 已 `if (backup.auto) _chip('自动')` |

## 6. 核心改动

**domain `NewBackup`**([entity.go:68](../../yucai/server/internal/backup/domain/entity.go#L68))—— 加 `auto` 参数:

```go
func NewBackup(tenantID uuid.UUID, provider BackupProvider, encrypted bool, auto bool) (*Backup, error) {
    if provider == 0 {
        return nil, fmt.Errorf("provider must be specified")
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
        Filename:  fmt.Sprintf("backup_%s%s", now.Format("20060102_150405"), suffix),
        Encrypted: encrypted,
        Auto:      auto,
        Version:   1,
        CreatedAt: now,
        UpdatedAt: now,
    }, nil
}
```

**application `CreateBackup`**([service.go:38](../../yucai/server/internal/backup/application/service.go#L38))—— 加 `auto` 参数(末位):

```go
func (s *Service) CreateBackup(ctx context.Context, tenantID uuid.UUID, encrypted bool, password string, auto bool) (*BackupDTO, error) {
    // ... validation + export + marshal + encrypt(原 logic 不变)...
    backup, err := domain.NewBackup(tenantID, domain.BackupProviderLocal, encrypted, auto)
    // ... upload + finalize + save(原 logic 不变)...
}
```

**application `RestoreBackup`**([service.go:100](../../yucai/server/internal/backup/application/service.go#L100))—— safety net 包裹:

```go
// RestoreBackup downloads → decrypts → per-module Purge + Import.
// Before purging, auto-creates a pre-restore safety backup (unencrypted,
// Auto=true → client shows「自动」badge); on success it is removed, on
// failure/crash it remains so the user can recover the pre-restore state.
// Pragmatic substitute for cross-module DB atomicity (each module has its own
// ent client/driver; shared *sql.Tx would need architecture-wide refactor).
func (s *Service) RestoreBackup(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
    // 1. Safety net: auto-create a pre-restore backup BEFORE touching any data.
    preRestore, err := s.CreateBackup(ctx, tenantID, false, "", true)
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
// purge/import). Extracted from RestoreBackup so the safety net can wrap it.
func (s *Service) restoreNoSafety(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
    // ... 原 RestoreBackup body(L101-149):FindByID → Download → Decrypt →
    //     Unmarshal → orderedPortsForPurge Purge → orderedPortsForImport Import ...
}
```

**handler `CreateBackup`**([backup_handler.go:41](../../yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go#L41))—— 传 `auto=false`:

```go
result, err := h.service.CreateBackup(ctx, tenantID, req.Encrypted, password, false)
```

## 7. 数据流 / 正确性

- **restore 成功**:pre-restore 建后删 → list 不累积。
- **restore 失败**(Import 报错):pre-restore(`Auto=true`)留 → client list 显示「自动」badge → 用户识别并 `RestoreBackup(preRestore.ID)` 恢复。
- **崩溃**(pre-restore 建后、restore 中):pre-restore 已 upload+save(持久)→ 用户重启后用它恢复。
- **pre-restore 创建失败**:RestoreBackup 开头 CreateBackup 失败 → 返回错误,**不 purge**(原数据安全;失败在 purge 前)。

## 8. 测试(server application + domain)

- `RestoreBackup` 成功:pre-restore 建后删(ListBackups 不含 pre-restore)
- `RestoreBackup` 失败(注入 Import 报错):pre-restore 留(`Auto=true`)+ ListBackups 找到 + 其数据 = restore 前 tenant 数据
- `RestoreBackup` pre-restore 创建失败(注入 export 报错):返回错误,原数据未动(无 Purge 发生)
- `NewBackup` auto 参数:`auto=true` → `Backup.Auto==true`;`auto=false` → `Backup.Auto==false`
- `CreateBackup` auto 参数:透传到 `NewBackup`(BackupDTO.Auto 正确)
- (client 无改,无 client 测)

## 9. 风险

1. **pre-restore 创建失败**:RestoreBackup 开头 CreateBackup 失败 → 返回错误,不 purge(原数据安全)。
2. **pre-restore 删除失败(restore 成功后)**:best-effort + `slog.Error`,非 fatal。list 残留一个 pre-restore(用户可手动删)。
3. **崩溃时机**:pre-restore 建后(已持久)、restore 中崩溃 → pre-restore 在,用户用它恢复。✓ 安全网生效。
4. **未加密 pre-restore 安全性**:短期(成功即删)、未加密、存本地。本地优先应用可接受;若敏感后续加加密(defer)。
5. **`NewBackup`/`CreateBackup` 签名改**(加 `auto` 末位参数):grep 全 caller(handler `backup_handler.go:41` / service_test.go 多处 / domain_test.go:10,23)更新;末位参数降低误用。

## 10. 参考

- backup server spec:[2026-07-13-backup-server-design.md](2026-07-13-backup-server-design.md)(RestoreBackup 原实现 + defer 原子 restore)
- memory:`holding-asset-management-todo`(跨模块原子 restore defer,client confirm 警告兜底)
- `RestoreBackup` / `CreateBackup` / `NewBackup`:[service.go](../../yucai/server/internal/backup/application/service.go) L100/L38 + [entity.go](../../yucai/server/internal/backup/domain/entity.go) L68
- `Backup.Auto` 链路:[entity.go:62](../../yucai/server/internal/backup/domain/entity.go#L62) → DTO → proto → [backup_entity.dart:12](../../yucai/client/lib/backup/domain/entities/backup_entity.dart#L12) → [backup_card.dart:39,45](../../yucai/client/lib/backup/presentation/widgets/backup_card.dart#L39)
