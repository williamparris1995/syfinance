---
feature: 2026-08-20-offline-write-integrity
status: drafted
---

# Design — 离线写完整性(余额联动 + 引用完整 + 断网 UX)

> 消费 [spec.md](spec.md)(confirmed)。server 锚点:ApplyEntryDirection(asset/expense=debit−credit;liability/equity/income=credit−debit)×sign(Update=+1/Reverse=−1);每 entry 查账户+version+1;update=Reverse旧+Update新;delete=Reverse旧。

## Context

收口件:联动引擎 + 三处校验收口 + 徽标/自检。联动**内嵌 transaction 写入**即自动覆盖全部复式路径(holding buy/sell、debt 还款/借出、Simple*——它们都走 `_txns.recordTransaction`)。

## Goals / NonGoals

- **Goals**:FR-1..FR-5 全量;E networth 口径迁移。
- **NonGoals**:绑定态镜像(H)/自检修复能力/i18n。

## Decisions(ADRs)

### ADR-1 联动引擎 = `BalanceLocalUpdater` 独立类,内嵌 transaction 写入事务
- **Decision**:新建 `transaction/data/balance_updater.dart`(`@LazySingleton`,注入 AppDatabase):`applyEntries(entries, sign)`——每 entry 读账户(**不存在→ServerFailure→外层事务回滚**=FR-1 场景 3 机制),delta=方向表×sign,写 currentBalanceCents+version+1。`TransactionLocalDataSource` 注入并在 `_insertWithEntries`(sign=+1)/`update`(先 `applyEntries(旧,−1)` 再写新再 `(+1)`)/`delete`(读旧 entries→`applyEntries(旧,−1)`→删头)内调用——全部在既有 drift 事务内。
- **Rationale**:结构照 server BalanceUpdaterImpl;嵌入 transaction 写入让所有复式调用方(holding/debt)零改动自动联动。
- **Alternatives**:各 local ds 自管余额——散落且易漏,reject。

### ADR-2 方向表 = 契约 int 直接判
- **Decision**:asset(1)/expense(5)→debit−credit;liability(2)/equity(3)/income(4)→credit−debit;未知→0(照抄 account/domain/repository.go:27-36,drift 行的 accountType 即契约 int)。

### ADR-3 FIFO 余量不足报错 + tag 幂等
- **Decision**:`_consumeFifo` 循环后 `remaining>0` → `ValidationFailure('持仓数量不足')`(对齐 sell 前置校验文案);`TagLocalDataSource.addTagToTransaction` 前查 tag/transaction 存在(缺→ServerFailure),已存在联结行→直接返回(幂等,spec accepted)。

### ADR-4 断网徽标 = AppShell 顶栏 StreamBuilder
- **Decision**:`AppShell` 顶栏(`_TopBar` 面包屑旁)加 `StreamBuilder<bool>`(getIt<ConnectivityGateway>().online,初值 current==true 不显),离线时小徽标(「离线」chip,lucide wifiOff 图标)。最小侵入:topbar 行内 wrap。

### ADR-5 启动自检 = `AppDatabase.integrityCheck()` + 非侵入横幅
- **Decision**:AppDatabase 增 `Future<(bool ok, String? detail)> integrityCheck()`:`customSelect('PRAGMA integrity_check')` + 3 条悬挂引用计数(entries.accountId∉accounts / budget_items.accountId∉accounts / goal links∉目标表),任一非零→(false, 摘要)。启动处(app.dart initState 后异步)调用,结果经 `ValueNotifier<String?>` 挂 getIt;AppShell 底部非侵入 MaterialBanner 风格条(仅异常时)。
- **Alternatives**:阻断式对话框——崩溃级 UX,reject;修复能力——out of scope。

## HLD

```
新增:transaction/data/balance_updater.dart(BalanceLocalUpdater)
     core/localdb/integrity_check 能力(AppDatabase 方法)
改:transaction/data/transaction_local_ds.dart(注入 updater;insert/update/delete 联动)
   holding/data/holding_local_ds.dart(_consumeFifo 余量报错;networth 注释口径迁移)
   tag(在 tag_repository_impl.dart 内):addTagToTransaction 校验+幂等
   app/widgets/app_shell.dart(离线徽标+自检横幅)
   app/app.dart(启动自检调用)
测试:E networth 测试口径更新(联动世界)+ 联动 oracle(记支出/删除恢复/坏 id 回滚/update 反向)/FIFO 报错/幂等/重启持久(临时文件库)
```

## LLD 要点

### 联动伪码(TransactionLocalDataSource)

```
_insertWithEntries: [既有写入] + await _balances.applyEntries(entryRows, +1)
update: 旧 entries = 读行 → applyEntries(旧, −1) → [既有替换写入] → applyEntries(新, +1)
delete: 旧 entries = 读行 → applyEntries(旧, −1) → deleteTransactionById
```

### 重启持久测试形态

`Directory.systemTemp.createTemp()` + `NativeDatabase(File(path))` → 全链路写入 → `await db.close()` → 重开同 path → 断言;teardown 删目录。

### 口径迁移(networth)

注释改为:「联动后余额真实(买入扣现金/入投资成本),+ gain 层=未实现利得」——测试:buy 后 cash 余额减/inv 加,networth 不变(转移不改净值)。

## Risks

- **R1 联动波及既有测试**:D/E 断言余额或净值的测试随口径更新(已盘点:E networth/D 无余额断言;holding buy 测试的"余额充足"前置用 seed 余额——联动后仍过,校验先于联动)。
- **R2 update 两段联动的原子性**:全在一个 drift 事务,Reverse 失败整回滚 ✓。

## Migration

无 schema 变更;行为迁移(余额列活)+测试口径更新。

## Open Questions

1. 徽标视觉细节(chip 样式)——执行时按 AppDesign 既有 chip 惯例。
