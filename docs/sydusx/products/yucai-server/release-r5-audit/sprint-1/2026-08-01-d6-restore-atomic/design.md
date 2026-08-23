---
feature: 2026-08-01-d6-restore-atomic
status: confirmed
---

# Design — D6 restore purge+import 跨模块 tx 原子

> 消费 [spec.md](spec.md)(analysis-done 2026-08-05;design resume 2026-08-23)。**关键事实(调研更新)**:03 sqltx 已铺 **11 个 repo 全部 `clientFor(ctx)` tx-aware**(account/transaction/debt/budget/goal/tag/template/holding×3)——repo 层零改动;D6 剩余实现 = Service 层包 tx + 各 repo Purge/Import 方法确认走 clientFor。

## Context

restore(与 R6 G 加的 uploadImport)当前 purge 循环 + import 循环裸跑:import 中途失败 → purge 已成既实 → 永久数据丢失(D6 P0 根因)。A(D5)已把 Export 包进 RR 只读 tx;同款机制用于 restore 的写侧。

## Goals / NonGoals

- **Goals**:purge+import 单跨模块 tx(restore + UploadExternal 同享);import 失败 → purge 回滚;safety backup 定位注释更新(tx 已覆盖事务失败,余下防人为错误)。
- **NonGoals**:D12 写冻结(feature C)/D13 加密(feature D)/D19b(见 map P2)。

## Decisions(ADRs)

### ADR-1 tx 包裹点 = Service 层 purge+import 循环整体(repo 零改动)
- **Decision**:`restoreNoSafety` 与 `uploadImport` 各自把「purge 循环 + import 循环」两段包进**一个** `sqltx.WithTx(ctx, s.db, s.dialect, nil, ...)`(默认隔离 Read Committed——spec NFR-1:全量替换的原子性由 rollback 保证,不需 RR 快照语义);envelope 解析/version/tenant 覆盖**留在 tx 外**(纯内存操作,无 DB 面)。
- **Rationale**:11 个 repo 的 Purge/Import 已全部经 `clientFor(ctx)`——context 携带 tx driver 即自动加入;A 的 Export 模式(RR+ReadOnly)是同款先例,写侧去掉只读约束即可。
- **Alternatives**:①每模块各自开 tx——部分原子,模块间仍可断裂,reject;②把 purge/import 下沉 repo——职责错位(跨模块编排属 Service),reject。

### ADR-2 两入口同享(restoreNoSafety + uploadImport)
- **Decision**:抽出私有 helper `purgeAndImport(ctx, tenantID, envelope)` 包 tx,两调用方共用。R6 G 的 uploadImport 目前同样裸跑——本设计顺带修复其原子性(同一根因,一并覆盖;G 的 spec NFR 复用 R5 加固的意图正是此处)。
- **Rationale**:同一循环逻辑两处复制已是现状(restoreNoSafety/uploadImport 各一份)——helper 化同时消重复(DRY)。

### ADR-3 safety backup 注释更新(维持现状行为)
- **Decision**:safety backup 生命周期维持(tx 成功→删/失败→留);`RestoreBackup` 头注释更新为「tx 原性防事务失败;**safety backup 防人为错误**(选错文件/导入垃圾数据)——tx 不防内容错误」(spec NFR-2 accepted 张力)。
- **Rationale**:三层防御各司其职(A 快照/B tx/C 人为错误兜底),不重复不缺口。

## HLD

```
改动面(全部在 backup 模块):
application/service.go:
  + purgeAndImport(ctx, tenantID, envelope) error   [新 helper:WithTx 包两循环]
  ~ restoreNoSafety:purge/import 两段 → 调 helper(下载/解密/解压/envelope 解析留外)
  ~ uploadImport:同上(version/tenant 覆盖留外)
  ~ RestoreBackup 头注释更新
(其余零改动:repo 已 tx-aware;wire 不动;scheduler 不动)
```

## LLD 要点

### purgeAndImport 伪码

```
func (s *Service) purgeAndImport(ctx, tenantID, envelope) error {
  return sqltx.WithTx(ctx, s.db, s.dialect, nil, func(ctxT) error {
    for p in s.orderedPortsForPurge() { p.Purge(ctxT, tenantID) }   // err → 返回 → rollback
    for p in s.orderedPortsForImport() {
      if raw ok := envelope.Modules[p.Name()] { p.Import(ctxT, tenantID, raw) }  // 同上
    }
    return nil
  })
}
```

### Purge/Import 循环内 8 exporter 的 repo 调用链(确认走 clientFor)

| exporter | Purge→ | Import→ | tx-aware |
|---|---|---|---|
| account | DeleteByTenant | Save(with caller ID) | ✓(account_repo clientFor) |
| transaction | DeleteByTenant | Save | ✓ |
| debt | DeleteByTenant | Save + schedule | ✓ |
| budget | DeleteByTenant | Save | ✓ |
| goal | DeleteByTenant | Save + UpdateLinks | ✓ |
| tag | DeleteByTenant | Save | ✓ |
| template | DeleteByTenant | Save | ✓ |
| holding | DeleteByTenant | SaveOrUpdate + trade Save | ✓(holding/trade repo) |

(执行时逐 exporter 复核方法体确实调 `clientFor` 而非裸 `r.client`——已抽 11 文件存在 clientFor 定义,但个别方法漏用的可能性由测试兜底。)

## 测试计划(oracle)

1. **import 中途失败 → 整 restore 回滚**:fake port 序(account purge→account import ok→transaction import err)→ 库断言 = restore 前状态(非半 purge);现有测试改造(service_test 的 fakePort 机制直接支持)。
2. **purge 失败 → 回滚**:purge 序中段 err → 同断言。
3. **完整成功**:全模块 purge+import → 新数据可见。
4. **uploadImport 同享原子性**:同款注入失败(fake port)——R6 G 的 4 测试扩充。
5. **真实 DB 层原子性**(升级:现有 fakePort 是内存 port,测不到真 tx)——用 sqlite/ent 真库或至少一个 repo 级注入(`ent` interceptor 层失败);fakePort 测**编排序**,真库测**rollback 语义**。record:fakePort 方案测不了 driver 层——执行时若真库注入成本高,以「clientFor 存在性 grep + fakePort 编排序」为准并记 ledger(follow R6 G 的教训:wire 层真实性)。

## Risks

- **R1 fakePort 测不到真 tx rollback**(fake 是内存替换)——缓解:至少一个真库(sqlite in-mem ent)端到端用例;若不可行记 ledger。
- **R2 Purge/Import 个别方法漏走 clientFor**(裸 client)——grep 全 8 exporter 方法体;漏者修复一行。

## Migration

无 schema 变更;行为增强(原子性),无数据迁移。

## Open Questions

1. sql.TxOptions{Isolation: ReadCommitted} 显式传 vs nil(默认)——nil 即默认,显式传以自文档化(执行定,倾向显式)。
