# 05 · DB 完整性约束(FK + CHECK + Immutable + UNIQUE)

Type: grilling
Status: resolved
Blocked by: —

## Question

ent schema 层防御纵深缺失,数据正确性几乎全靠 app 层(详见 `findings.md` D8/D10/D11/D15/D16/D17/D20):

- **[D8 P1]** 全库无真实 FK(除 User↔UserIdentity),所有 *_id 裸列;无 OnDelete 策略。
- **[D10 P1]** 金额字段无符号/范围约束(无 `Min(0)`/CHECK),余额/本金可负;全库仅 1 个 CHECK(transaction_entry debit/credit 互斥)。
- **[D11 P1]** `version` 字段多为装饰性(ent 不自动 CAS);`SyncLog.(tenant_id,version)` 非 UNIQUE 破坏单调版本契约。
- **[D15 P1]** 缺唯一约束:User.email / SyncDevice.device_name / Backup.filename / BudgetItem.(budget_id,account_id) / PaymentSchedule.(debt_id,payment_date)。
- **[D16 P1]** FK-like 列(account_id/security_id/budget_id 等)非 Immutable,可被 re-parent。
- **[D17 P1]** DeleteAccount 不查引用方,物理删留 orphan;DeleteByTenant 硬删。
- **[D20 P2]** 软删仅 4/33 表 + 唯一索引不含 `deleted_at`,Budget/Tag 同名软删重建冲突。

**决策点:**
1. 是否加 DEFERRABLE Postgres FK(跨模块表 tenant_id+id)for restore safety + query integrity?(评估 ent edge 重启 vs 手 SQL migration)
2. 金额字段加 `field.Min(0)` + DB CHECK(金额非负、liability ≤ credit_limit)的范围?
3. `version` 字段:确认哪些是乐观锁(repo 补 `WHERE version=?`)vs 装饰性?
4. 补齐唯一约束清单 + 关键 FK 列 `Immutable()`?
5. 软删策略:抽 `TimeMixin` 统一 + 唯一索引含 `deleted_at`?Holding 是否要软删?

## Answer(resolved 2026-07-26)

grilling 决策(5 点 + findings 纠正):

1. **Q1 FK(D8)**:同模块 ent edge 加(budget↔BudgetItem / transaction↔TransactionEntry / holding↔HoldingTransaction·HoldingLot / debt↔PaymentSchedule 等;ent 单模块 codegen 内,加 edge + OnDelete,低成本高收益:模块内 orphan 防 + ent 自动 join);**跨模块 FK 不加**(ent 跨 codegen 不支持 edge + 手 SQL FK 叠加 D14 auto-migrate 无版本化债 + ent/FK 双源冲突 + 03 跨模块 tx 原子 + 01 tenant scoping + service 已 app 层防 orphan)。跨模块 orphan 靠 Q5 DeleteAccount 拒绝引用。
2. **Q2 金额(D10)**:`field.Min(0)` 精细加在明确非负字段(debt principal / transaction_entry debit·credit / budget planned·actual amount / holding price·quantity·fee / goal target / schedule·payment amount);**余额·realized PnL 不加**(语义可负:负债账户余额·亏损)。**不加 DB CHECK**(靠 field.Min builder-level + 03 tx + 私域单机;`liability ≤ credit_limit` 跨字段规则 app 层 service 校验更合适)。
3. **Q3 version(D11 纠正)**:**findings D11"version 装饰性"判断错** —— 7 模块 repo 实际都做 CAS 乐观锁(`account_repo:201` / `transaction_repo:445` / `tag_repo:113` / `debt_repo:192` / `goal_repo:170` / `template_repo:166` / `budget_repo:203`,全 `Where(XXX.Version(obj.Version-1))`)。version 保持现状(已正确)+ grep 确认带 version 表全覆盖(漏的补)。`SyncLog.(tenant_id,version) UNIQUE` **挂 16**(sync cancelled 2026-07-25,SyncLog 残留 scaffolding;16 重开时定)。
4. **Q4 UNIQUE+Immutable(D15/D16)**:D15 unique 加 4 项(`User.email` / `Backup.filename` / `BudgetItem.(budget_id,account_id)` / `PaymentSchedule.(debt_id,payment_date)`;`SyncDevice.device_name` 挂 16)。D16 Immutable 加在关键 FK 列(`account_id` / `security_id` / `budget_id` / `template_id` / `debt_id` / `holding_id` / `transaction_id` 等,创建后不 re-parent)。
5. **Q5 软删+DeleteAccount(D20/D17)**:现软删表唯一索引含 `deleted_at`(partial unique 解同名软删后重建冲突);**不扩全表软删**(私域,查询全加 IsNil + 容量增长过度);**Holding 不软删**(交易·lot 历史必须完整可逆)。`DeleteAccount` 改**拒绝有引用**(查 transaction/holding/budget/debt 引用方,有则返错);`DeleteByTenant` 保留(灾难清理)。TimeMixin 抽取**挂 10**(A10 schema 债,05 只决策策略不强制抽 mixin)。

**跨 ticket 取舍**:
- TimeMixin 抽取 → 10(A10)。
- `SyncLog.(tenant_id,version)` UNIQUE + `SyncDevice.device_name` unique → 16(sync 重开时定)。
- 03 与 05 非同一批 migration(03 已落无 schema migration;05 独立 ent schema 改 + regen)。

**grilling 价值**:独立确认纠正 findings D11 误判(7 模块 CAS),避免浪费精力。

unblocks 无下游(05 叶子)。**实施留专项 plan/session**(ent schema 多模块改 + regen + DeleteAccount 引用检查 + 测试,中等规模)。
