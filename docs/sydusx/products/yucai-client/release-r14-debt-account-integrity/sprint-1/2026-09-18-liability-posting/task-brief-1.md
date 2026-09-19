# Task Brief T1 — client 负债分录补齐(不变式 TDD)

## 不变式(北极星)
任意操作序列后:**负债账户 currentBalanceCents == −Σ(该账户名下 borrowedIn 债 remainingPrincipalCents)**,其中 remaining = totalPrincipalCents − Σ(entry.paidCents)(与 _toEntity 同式)。

## 任务(lib/debt/data/debt_local_ds.dart,三处缺口)
1. **创建无到账**:borrowedIn 且 sourceAccountId 空 → 现在**零分录**。补:借 权益户 +P / 贷 债务账户 +P。权益户用既有 `_ensureSettlementAccount()`(幂等兜底「历史还款结转」)。
2. **update 改总额**:capture 旧 totalPrincipalCents(row,update 前);写后若 ΔP=newTotal−oldTotal≠0 → 调整分录:ΔP>0 贷 负债 ΔP/借 权益;ΔP<0 借 负债 |ΔP|/贷 权益。与 schedule 重生成同 `_database.transaction`。仅 borrowedIn 需要(本票范围);borrowedOut 更新维持现状。
3. **delete**:删前算 remaining = totalPrincipalCents − Σ(schedule.paidCents);remaining>0 → 借 债务账户 remaining / 贷 权益户(历史现金流分录不动);remaining==0 → 无分录。borrowedOut 维持现状。

## TDD(debt_local_ds_test.dart,真实 drift 模式)
先写不变式助手 + 序列测试(RED):
- 助手:`expectInvariant()` — 断言每个有借入债的负债账户 balance == −Σremaining(经 BalanceLocalUpdater 真实记账后读 accounts 表)。
- 序列①:无到账创建 → 不变式。
- 序列②:创建(有到账)→ recordPayment 一期 → 改总额 P+5,000,000 分 → 不变式。
- 序列③:创建 → 还款部分期次 → 删除 → 不变式(其余债不受影响)。
注意现有测试对 create/update/delete 的既有断言保持兼容(行为只增不改)。
GREEN 后回归:`flutter test test/debt/ test/transaction/` + `dart analyze lib/debt/`。

## 约束
**禁止 git stash/checkout/restore**;只动 debt_local_ds.dart + debt_local_ds_test.dart;勿提交 git;English 注释与日志。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f36`
完成后报告:改动点、RED→GREEN 证据、不变式助手输出、回归结果;BLOCKED 即停。
