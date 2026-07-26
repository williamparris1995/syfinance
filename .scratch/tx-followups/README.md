# tx-followups — 03 事务一致性架构实施的 defer tickets

03 事务架构重构(11 commits `9ba8a80..400a3e3`,2026-07-26 merged to 本地 main)的 final whole-branch review 标出的 defer 项。**均非 merge-blocking**(已 merge)。

## Tickets

- [01 DeleteTransaction 原子化](issues/01-delete-transaction-atomicity.md) — P1
- [02 CreateDebt 双写原子化](issues/02-create-debt-double-write.md) — P1
- [03 runInTx dialect 注入](issues/03-runintx-dialect-inject.md) — P2(cross-cutting Tasks 4-7)
- [04 RecordSplit WithTx 包裹](issues/04-record-split-withtx.md) — P2
- [05 cash TransactionDate 用 trade date](issues/05-cash-transaction-date.md) — P2(pre-existing)
- [06 db.Close shutdown wiring](issues/06-db-close-shutdown.md) — P2

## Cosmetic(留 memory,未立 ticket)

provideDB 注释 "12"→"13" 池 / vestigial `time.Time{}` import(holding_handler)/ raw-SQL `TransactionSummary` 非 tx-aware(加注释,scheduler 用)/ `recorded++` metric 把 idempotent-skip 算成功 / read-`clientFor` 不对称(template 全改 vs debt surgical)。均非 correctness,视反馈排。

## 关联

- 03 spec:`docs/superpowers/specs/2026-07-26-transactional-architecture-design.md`
- 03 plan:`docs/superpowers/plans/2026-07-26-transactional-architecture.md`
- 审计 wayfinder:`.scratch/yucai-audit/`(03/04 ticket)
