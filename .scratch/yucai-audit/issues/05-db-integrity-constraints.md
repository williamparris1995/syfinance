# 05 · DB 完整性约束(FK + CHECK + Immutable + UNIQUE)

Type: grilling
Status: open
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
