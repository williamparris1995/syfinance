# Task Brief — F35 贷款账户详情页还款计划面板(TDD)

## 任务
①新组件 `lib/core/widgets/repayment_plan_panel.dart`:`AccountRepaymentPlanPanel`——入参 `List<({Debt debt, List<PaymentEntry> upcoming})> plans`(+`VoidCallback` 不可用,跳转在页面层做;组件带 `onOpenDebt(String debtId)` 回调),每笔债一节:counterparty + 剩余本金 badge(`DebtSubtypes.labels[subtype]` 徽标可选)+ 未来期次前 3 条(日期 yyyy-MM-dd / 本期合计 totalCents 千分位)+ 尾部「查看完整还款计划 →」;色值全 `context.yucai` 令牌,零裸 hex;只读零交互(除跳转回调)。
②页面接线 `lib/account/presentation/pages/account_detail_page.dart`:新增 `_loadRepaymentPlans()`(getIt<DebtRepository>().list(typeFilter: DebtType.borrowedIn) → `d.accountId == widget.id` 过滤 → 逐笔 repo.get(id) → 未还期次按 paymentDate 升序取前 3),initState + didPopNext(hotfix 已有该方法,追加调用)各调一次;build 中 `a.category == AccountCategory.loan` 分支:`_debtPlans.isNotEmpty` → 渲染面板(onOpenDebt → `context.push('/debts/$id')`,go_router 已有该路由),空 → `SizedBox.shrink()`(替换「待 payment_schedule 模块接入」占位)。投资类占位不动。

## 已知事实
- `DebtRepository.list({DebtType? typeFilter})` / `get(String id)` → `Either<Failure, DebtDetail>`;DebtDetail{debt, schedule:List<PaymentEntry>};PaymentEntry{paymentDate, principalCents, interestCents, totalCents, paid, paidCents}。
- 页面模式参考本页 `_loadAccounts`/`_refreshTxn`(getIt 直取);`_panel(String title, String hint)` 是占位助手(被替换)。
- 跳转:`context.push('/debts/$id')`(go_router,router.dart:457 已注册 DebtDetailPage)。
- debt 分支观察者已由 hotfix 接好(didPopNext 存在)。

## TDD(test/account/presentation/pages/account_detail_page_test.dart,沿用其 harness)
RED:
1. loan 账户 + getIt 注册 mock DebtRepository(list→1 笔 subtype=mortgage 的债,get→2 条未还期次)→ pump → 面板含 counterparty 文本 + 期次日期 + 「查看完整还款计划」。
2. loan 账户 + 空债务列表 → `find.text('还款计划')` findsNothing(旧占位消失)。
3. (若 harness 支持便利)面板 badge 显示剩余本金千分位。
GREEN 后回归:`flutter test test/account/` + `dart analyze lib/account/ lib/core/widgets/` 零新增。

## 约束
**禁止 git stash/checkout/restore**;只动 account_detail_page.dart + repayment_plan_panel.dart + account_detail_page_test.dart(+harness 内 DebtRepository mock);勿提交 git。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f35`
完成后报告:改动文件、RED→GREEN 证据、回归与 analyze 结果;BLOCKED 即停(如 harness 缺 DebtRepository 注入点,报告后再动 harness)。
