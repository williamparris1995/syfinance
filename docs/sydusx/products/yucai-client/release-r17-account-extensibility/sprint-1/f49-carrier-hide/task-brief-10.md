# Task Brief T10 — 编辑切换同步 + debt_form 下拉过滤 + 测试补硬(评审 follow-up)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。
来源:批次评审(755e47cf)两项 Minor-MISSING + T4 报告的缺口 B + spec FR-1 已补「编辑切换同步」条款(先读 spec.md FR-1/FR-3 现版)。

## 任务(TDD)
1. **编辑切换同步(FR-1 评审补)**:`debt_form_page.dart` 编辑路径(UpdateDebtRequested 提交处,约 714-740),检测卡贷出账方式切换(`_cardLoanIndependent` vs `e.collectionAccountId` 空/非空):
   - 并入→独立:同事务/紧随更新,把债务所属账户 `isSystem→false`(经 AccountRepository.update 或 account DS 直更——**UpdateAccountParams 需增可选 isSystem 与 creditBillingDay/creditRepaymentDay 清空通道**;按 T1 的 patch 语义扩展,缺省 absent 不动)。
   - 独立→并入:账户 `isSystem→true` 且账单日/还款日清空。
   - 无切换:零动作。guest 本地路径;注释钉死语义。
2. **debt_form 关联账户下拉过滤(FR-3 补消费点,T4 缺口 B)**:`_visibleAccounts` 非信用卡分支经 `AccountVisibility.userVisible`,**但当前债务已挂的账户(编辑态)始终保留**(否则编辑既有债时下拉丢当前值)。
3. **测试补硬**:①T2 评审缺的 accountId 接线断言(debt_form 建户测补 `captureThat accountId == 载体户id`);②T7 评审缺的守卫分支测(account_local_ds_test 补「同户两债,删其一 → 不关」)。

## 约束
只动 debt_form_page/account_repository(params)/account_local_ds(update 通道,若需)+ 对应测试;禁碰 accounts_page(T5 并行中)/repairs/detail。

## 完成判据
切换两向测绿+接线断言+守卫测绿;analyze 零新增;报告 UpdateAccountParams 扩展面+改动清单。
