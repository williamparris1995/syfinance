# Feature — D6 restore purge+import 跨模块 tx 原子

> audit 04 决策点 2(D6 P0)。sprint-1 feature B(依赖 A)。
> 依赖:03 sqltx(已 done)+ A 的 RR 快照(safety backup 已免费快照一致)。

## Description

当前 RestoreBackup 非原子:purge(清空各模块数据)+ import(写回备份)分步执行,import 中途失败 → purge 已成既实 → 永久数据丢失(D6 P0 根因)。

实施:purge + import 包进**单个跨模块 tx**(经 03 sqltx TxContext 传播,同 A 的 Export 模式),import 失败 → 整 tx rollback(purge 一并回滚)→ restore 原子。pre-restore safety backup 保留作「人为错误」兜底(选错备份文件 / 导入垃圾数据的回滚路径 —— tx 原子只防事务失败,不防人为错误);其快照一致已由 feature A 免费赋予(RestoreBackup 的 safety backup 现走 RR tx),加密分层(D13)归 feature D。

三层防御:D5 导出快照(A done)+ tx 原子(本 feature)+ safety backup 人为错误兜底。

## Stories

1. RestoreBackup 的 purge + import 包进单个跨模块 tx(sqltx.WithTx,传播 TxContext)
2. 各模块 Import/Purge port 接受 TxContext 传播(镜像 A 的 Export clientFor 模式)
3. import 中途失败 → 整 tx rollback(purge 回滚),restore 前后状态一致
4. safety backup 定位确认:快照一致(A 收益),加密(D13)归 feature D,本 feature 不做
5. 原子性测试(oracle:模拟 import 中途失败,验证库 = restore 前一致状态,非半 purge 状态)

## title

D6 restore purge+import 跨模块 tx 原子 + safety backup 快照一致

## keywords

restore, atomic, purge, import, cross-module tx, TxContext, rollback, D6, 04
