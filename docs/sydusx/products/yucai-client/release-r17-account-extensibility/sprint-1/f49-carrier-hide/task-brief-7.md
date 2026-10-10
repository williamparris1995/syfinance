# Task Brief T7 — 债删自动关户(FR-5)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。
先读 feature 目录 `spec.md`(FR-5)与 `design.md`(单元7)。T1 已落 Account.isSystem。

## 任务(TDD)
1. port:`account/domain/repositories/account_repository.dart`(或 domain 合适位置)定义 `abstract class AccountCloser { Future<void> closeIfEmptyCarrier(String accountId); }` —— 语义:该账户 isSystem=true 且 currentBalanceCents==0 且名下无其他 debt_type=1 债 → 置 status=关闭;任一不满足为 no-op。实现放 account data 层(注入 DB;关闭语义与 T3 同源,查既有账户关闭代码取 status 值)。
2. `debt/data/debt_local_ds.dart` 的 `delete(String id)`:事务内既有序列(清账分录→deleteDebtById)之后,若被删债 subtype==card_loan 且其载体户满足 closeIfEmptyCarrier 条件 → 调 port 关户(在**同一事务**内语义最佳;若 port 实现无法入事务,改为事务后调用并在失败时静默留待下次删除/启动收敛,注释钉死取舍)。
3. 接线:debt_local_ds 构造注入(照既有 _txns 注入范式;getIt 注册补齐——main 或注入文件里,先查现有绑定风格)。

测试(`test/debt/data/debt_local_ds_test.dart` 增测):
- 并入型债全额清偿(载体 0)删除 → 载体户 status=关闭
- 载体非零 → 删除后不关
- 独立账单模式账户(即使清零)→ 不关(isSystem=false 天然挡)

## 约束
只动上述三处+测试;跨模块走 port(debt 不 import account 实现);禁碰 accounts_page/repairs/detail。

## 完成判据
三测绿;analyze 零新增;报告事务取舍说明+改动清单。
