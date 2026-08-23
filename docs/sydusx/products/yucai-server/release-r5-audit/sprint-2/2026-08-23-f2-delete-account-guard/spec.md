# Spec — F2 delete-account-guard(R5 sprint-2 feature F)

> 源 ticket [.scratch/yucai-audit/issues/05](../../../../../../../.scratch/yucai-audit/issues/05-db-integrity-constraints.md) 决策 5 后半(D17)。05 决策 1 明确:**跨模块 orphan 靠 DeleteAccount 拒绝引用**(跨模块 FK 不加)。
> branch `feature/r5-delete-account-guard`,worktree `.claude/worktrees/r5-del-guard`。

## Problem

`DeleteAccount`(`internal/account/application/service.go:134`)只检查 `CurrentBalanceCents != 0` 即软删。被 transaction/budget/debt/holding/goal/template 引用的账户删掉后,这些模块的行指向 ghost 账户(列表/详情/报表 join 断裂)——正是 D17 orphan 问题。`DeleteCategory`(`service.go:202`)同样裸软删(分类被交易引用同样断裂)。

## 现状盘点(2026-08-23 grep)

**引用 account 的跨模块列**(排除派生表 holding_snapshots):

| 模块 | 列 | 软删过滤 |
|---|---|---|
| transaction | transaction_entries.account_id | `deleted_at IS NULL`(join transactions) |
| budget | budget_items.account_id | `deleted_at IS NULL`(join budgets) |
| debt | debt_details.account_id + collection_account_id | 无(debt 无软删) |
| holding | holdings.account_id + holding_transactions.account_id | 无(Holding 不软删,决策 5) |
| goal | goal_account_links.account_id + goals.linked_account_id | 无 |
| template | transaction_template.source/destination_account_id | 无 |

> ticket 决策 5 字面列了 4 个引用方(transaction/holding/budget/debt);goal 与 template 的引用列同样存在(D17 的意图是"拒绝有引用",不是白名单),纳入同一 port,一个 count 方法各一行增量。

**version CAS grep**(决策 3 复核):account/budget/tag/goal/debt/transaction/template 7 模块 repo 更新路径全带 `Where(Version(x-1))` ✅。两个例外记录为 accepted:**holding**(交易引擎 upsert 单写者路径,tx 内串行)与 **backup**(上传管线元数据更新)version 存在但不做 CAS——并发面在交易入口(D12 freeze + 03 tx),本 feature 不改语义。

## FRs

- **FR-1 port 定义**:`account/domain` 新增 `AccountReferenceSource` 接口(`CountAccountReferences(ctx, tenantID, accountID) (int64, error)` + `AccountReferenceSourceName() string`)。生产方=各消费模块 repo,结构化实现(不 import account;镜像 goal/domain.AccountBalanceSource 范式,方向反转:这次 account 是消费方)。
- **FR-2 六模块实现**:各 repo 加 count 方法,语义=「非软删父记录引用该账户的条数」:transaction=有 entry 落在该账户的非软删交易数(E edge `entries` 可用 HasEntriesWith);budget=有 item 落在该账户的非软删 budget(edge `items`);debt=account/collection 任一命中;holding=holdings+holding_transactions 两表合计;goal=links+linked_account_id;template=source/destination 任一。
- **FR-3 guard 接线**:`Service.SetAccountReferenceSources([]domain.AccountReferenceSource)` setter 注入(NewService 签名不变,wire 手编);`DeleteAccount` 在余额检查后逐源 count,>0 返错 `cannot delete account: referenced by N <source> record(s)`。
- **FR-4 fail-closed**:count 出错→包装返错;**sources 为空→返错**(未接线=拒绝删除;镜像 C-feature 写守卫 fail-closed 决策——静默 fail-open 会回退到 orphan 行为)。
- **FR-5 DeleteCategory 同守卫**:分类被交易引用同样拒绝(同 sources 复用,零额外 port)。
- **FR-6 DeleteByTenant 不变**:灾难清理路径保留(ticket 原文;D6 purge 依赖它)。

## NFRs

- 跨模块边界:account 不 import 六消费方;六 repo 不 import account;wiring 只在 wire/(CLAUDE.md port 约束)。
- 错误信息结构化可判别(客户端可展示"被 N 笔交易引用")。
- 现有单测受 FR-4 影响的补 stub source。

## 测试计划

- 六 repo count 单测(引用/不引用/软删父过滤)。
- Service guard 单测:有引用拒 / 无引用过 / count 错误 fail-closed / 空 sources fail-closed / DeleteCategory 同。
- 集成(tests/):建账户+记账→删账户拒→删交易→删账户过;DeleteByTenant 仍工作。
