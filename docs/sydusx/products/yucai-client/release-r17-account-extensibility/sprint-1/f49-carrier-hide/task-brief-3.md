# Task Brief T3 — 存量 repair:标记 + 孤儿一次性关闭(FR-2)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。
先读 feature 目录 `spec.md`(FR-2 三场景)与 `design.md`(单元3 LLD 的 SQL 语义)。同文件先例:`unhookEDaiCardMerges`/`seedEDaiBillDays`(app_meta 幂等模式)。

## 任务(TDD)
`core/localdb/repairs.dart`:
1. 新 `Future<void> runF49CarrierHideRepair(AppDatabase db)`,marker `f49_carrier_hide_v1`(已 done 直接 return):
   - ①标记:`UPDATE accounts SET is_system=1, updated_at=? WHERE EXISTS(SELECT 1 FROM debts d WHERE d.account_id=accounts.id AND d.subtype='card_loan' AND d.debt_type=1 AND d.collection_account_id IS NOT NULL)`
   - ②孤儿关闭:`UPDATE accounts SET status=<closed 值>, updated_at=? WHERE notes='信用卡贷款(卡贷)自动创建' AND current_balance_cents=0 AND credit_billing_day IS NULL AND NOT EXISTS(同上子查询)`;status 的 closed 枚举值先查项目里账户关闭语义的实际取值(accounts 表 status 列/AccountStatus 枚举/既有关闭代码)再定,勿猜。
   - ③非零余额与带账单日账户零动作(由 WHERE 天然保证)。
2. 挂 `runRepaymentHistoryRepairOnce` 链尾(e_dai 系列之后)。

测试 `test/core/localdb/f49_carrier_hide_test.dart`(照 e_dai_unhook_test 范式):
- 场景A 挂接非空卡贷债的账户 → isSystem=1;e招贷(解挂,collectionAccountId NULL)不置位
- 场景B 孤儿(notes 匹配+0 余额+无账单日+无卡贷债)→ status 关闭
- 场景C 非零孤儿/带账单日独立户 → 不动
- 幂等:二次运行零变化

## 约束
只动 repairs.dart + 新测试文件;SQL 原子、参数化时间戳照先例;禁碰其他模块。

## 完成判据
四测全绿;analyze 零新增;报告 status 枚举取值依据+改动清单。
