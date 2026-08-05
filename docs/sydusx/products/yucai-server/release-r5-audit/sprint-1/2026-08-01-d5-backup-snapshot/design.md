---
feature: 2026-08-01-d5-backup-snapshot
---

# Design — D5 backup 快照隔离 + D18 OnConflict

> feature A。consumes [spec.md](spec.md)。基于 03 sqltx(已 done)+ backup 现状。

## Context

`backup/application/service.go` `CreateBackup` 循环 `p.Export(ctx, tenantID)`,各 Export 调 `repo.FindAllForBackup(ctx, tenantID)` —— ctx 无 tx,各 Export 独立连接查询(默认隔离),并发写下产生**撕裂备份**(账户 T1 + 交易 T2)。

03 sqltx(`internal/sqltx/sqltx.go`)已落地跨模块 tx 传播:`WithTx(ctx, db, dialect, opts, fn)` 开 tx + 包成 `dialect.Driver` + 经 `context.Value` 注入 ctx;`DriverFrom(ctx)` 取出;**join-existing-tx 语义**(ctx 已有 tx 则复用外层)。backup 未接入。

`RestoreBackup` 注释仍写"shared *sql.Tx would need architecture-wide refactor" —— 这是 03 之前的认知,03 已解决此问题。

## Goals / Non-Goals

**Goals**: FR-1(单 REPEATABLE READ + ReadOnly tx 导出)/ FR-2(各 Export 共享 tx)/ FR-3(Export 失败=整失败)/ FR-4(D18 OnConflict)。

**Non-Goals**: D6 restore 原子(feature B)/ D12 写冻结(C)/ D13 加密(D);**不改 `TenantDataPort` / `Export` 接口签名**(ctx 传播 tx,签名不变)。

## Decisions (ADRs)

### ADR-1: tx 传播复用 03 sqltx context.Value,不改 Export 接口签名
- **Decision**: `CreateBackup` 用 `sqltx.WithTx` 包 Export 循环;tx 经 `context.Value` 传播,各 repo 用 `clientFor(ctx)`/`DriverFrom` 检测。`Export(ctx, tenantID)` 签名不变。
- **Rationale**: 03 sqltx 已建 context.Value 传播(WithTx/DriverFrom/join-existing-tx),复用最自然 + 零接口破坏。
- **Alternatives**:
  - 改 `TenantDataPort.Export` 加 tx 参数 `Export(ctx, tenantID, tx)` —— 破坏接口 + 9 个 Exporter + Import/Purge 同改。**rejected**。
  - Exporter 构造时注入 tx-aware repo —— backup service 每次 tx 重建 Exporter 集合,复杂且违反 port 单例。**rejected**。

### ADR-2: CreateBackup 用 sqltx.WithTx(REPEATABLE READ + ReadOnly)
- **Decision**: Export 循环包进 `sqltx.WithTx(ctx, db, dialect, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true}, fn)`。
- **Rationale**: 单 REPEATABLE READ + ReadOnly tx → 各 Export 共享快照;只读不需 Serializable 防写偏序开销(04 决策)。join-existing-tx 语义让 nested 调用安全。
- **opts**: `{Isolation: sql.LevelRepeatableRead, ReadOnly: true}`。

### ADR-3: 各 repo FindAllForBackup 需 tx-aware(clientFor)
- **Decision**: 各 Exporter repo 的 `FindAllForBackup` 必须用 `clientFor(ctx)`(DriverFrom 检测 tx)bind ent client,非直接 `c.client`。code 阶段验证每个;未 tx-aware 的改。
- **Rationale**: tx 经 context.Value 传播,repo 必须 `DriverFrom(ctx)` bind 到 tx driver,否则跑独立连接 = 撕裂。
- **验证范围**: account/transaction/debt/budget/goal/holding/tag/template/currency 的 `FindAllForBackup`。
- **风险**: 03 重点改写路径(transaction/holding/debt/template 的写),backup 读路径(FindAllForBackup)可能漏改 → code 阶段第一步全量验证。

### ADR-4: Export 失败 → WithTx rollback(FR-3 原子)
- **Decision**: Export 循环在 `WithTx` 的 fn 内;任一 Export err → fn 返 err → `WithTx` rollback。不产部分备份。
- **Rationale**: `sqltx.WithTx` 设计(fn err → rollback)。FR-3 原子免费获得。

### ADR-5: D18 snapshot Save OnConflictDoNothing
- **Decision**: snapshot 持久化 `Save` 改 `OnConflictDoNothing`(first-wins)。
- **Rationale**: 重复 tick 不硬错中断当日 snapshot(04 D18)。

## HLD

```
CreateBackup(ctx, tenantID, encrypted, password, auto):
  sqltx.WithTx(ctx, db, dialect, {RepeatableRead, ReadOnly}, func(ctxT) error {
      envelope := {Version:1, TenantID, CreatedAt, Modules:{}}
      for p in s.ports:
          raw, err := p.Export(ctxT, tenantID)   // ctxT 携带 tx driver → 各 repo clientFor(ctxT) 共享 tx
          if err != nil: return err              // → WithTx rollback (FR-3)
          envelope.Modules[p.Name()] = raw
      return nil                                 // → commit
  })
  // envelope(一致快照)→ marshal/compress/encrypt/upload/save(文件 IO,tx 外)
```

**注**: Export 循环在 tx 内(护 DB 读一致);marshal/compress/encrypt/upload/save 是文件 IO,在 tx 外(tx 只护 DB 快照一致,不护文件写——文件写失败由上层重试,safety backup 兜底)。

## LLD

- `backup/application/Service` 加 `db *sql.DB` + `dialect string` 字段(wire 注入,供 `WithTx`)。
- `CreateBackup` Export 循环包 `sqltx.WithTx`。
- 各 Exporter repo `FindAllForBackup` 用 `clientFor(ctx)`(验证/改,见 ADR-3)。
- snapshot repo `Save` → `OnConflictDoNothing`(D18)。
- wire_gen.go 手改(注入 db/dialect 到 backup Service,按惯例)。

## Risks

| # | risk | 级别 | 缓解 |
|---|---|---|---|
| R1 | 各 repo `FindAllForBackup` 可能未 tx-aware(03 重写路径,读路径 backup 可能漏) | **中** | code 阶段第一步全量验证 9 个 repo;未 tx-aware 的改 clientFor |
| R2 | REPEATABLE READ 在 Postgres 是否够 | 低 | 04 决策 + Postgres MVCC:只读 backup 无写偏序,RR 够 |
| R3 | backup Service 注入 db/dialect 改 wire_gen.go | 低 | 按惯例手改(memory yucai-wire-handmaintained) |

## Migration

无 schema 改(03 已落 `*sql.DB` 共享)。无数据迁移。

## Open Questions

1. ✅ **已答(code-1, 2026-08-01)**:8 个 backup exporter repo 的 `FindAllForBackup` **全用 `r.client`(不 tx-aware)**。
   - **有 clientFor**(改 FindAllForBackup 用 `clientFor(ctx)` 即可):account_repo:266 / transaction_repo:466 / holding_repo:143 / debt_repo:229 / template_repo:241
   - **无 clientFor**(需加 clientFor + 改):budget_repo:244 / goal_repo:294 / tag_repo:209
   - **R1 改动量确认:8 repo(5 改 + 3 加 clientFor)**。注:debt_repo clientFor 注释原说"FindAllForBackup stay on r.client because not invoked inside WithTx"——feature A 改变此前提。
2. backup Service 现有 db 访问:能否拿到共享 `*sql.DB`?(code-3 确认 wire 现状 —— 决定 ADR-2 注入方式)

## code 实施清单(新会话接续,current_stage=code)

1. code-2:改 8 repo FindAllForBackup → `clientFor(ctx)`(上表;3 个加 clientFor)
2. code-3:CreateBackup Export 循环包 `sqltx.WithTx(ctx, db, dialect, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true}, fn)`;Service 加 `db *sql.DB` + `dialect string`
3. code-4:wire_gen.go 手改(注入 db/dialect 到 backup Service)
4. code-5:D18 snapshot Save → `OnConflictDoNothing`
5. code-6:`go build ./...` 验证
6. code-7:FR-1 Postgres 并发 tx 测试(两连接:backup RR + 写者,断言 backup 不含写后状态)
7. code-8:review(spec 对齐 + DoD)
