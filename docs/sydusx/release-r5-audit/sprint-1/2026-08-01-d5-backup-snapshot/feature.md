# Feature — D5 backup 快照隔离 + D18 OnConflict

> audit 04 决策点 1(D5 P0)+ polish(D18)。sprint-1 首个 feature(基础,unblock B/D)。
> 依赖 03 sqltx(已 done,共享 `*sql.DB` + TxContext)。

## Description

当前 backup 链路无 snapshot isolation —— 循环 Export 各 `Query().All` 默认隔离级别,并发写产生**撕裂备份**(账户 T1 状态 + 交易 T2 状态);sha256 校验只防传输损坏,不防逻辑撕裂。

实施:共享 `*sql.DB` 起 `REPEATABLE READ` + `ReadOnly=true` 的单个 tx,经 TxContext 传播给各模块 `Export`。单连接天然共享快照 → 不需 `pg_export_snapshot`;只读 backup 不需 Serializable 的防写偏序开销。snapshot Save 改 `OnConflictDoNothing`(D18,重复 tick 不再硬错中断当日 snapshot)。

## Stories

1. backup service 经 sqltx 起 `REPEATABLE READ` + `ReadOnly=true` 单 tx
2. 各模块 Export port 接受 TxContext 传播(account/transaction/debt/budget/goal/holding/currency/tag/template)
3. Export 循环在同一 tx 内执行 → 快照一致(无撕裂)
4. snapshot Save 改 `OnConflictDoNothing`(D18,first-wins 保留时点快照语义)
5. 并发写下 backup 一致性测试(oracle:模拟并发写 + 验证 backup 是某一致时点快照,非撕裂)

## title

D5 backup 快照隔离(REPEATABLE READ + TxContext 传播)+ D18 OnConflict

## keywords

backup, snapshot, REPEATABLE READ, TxContext, Export, D5, D18, 04
