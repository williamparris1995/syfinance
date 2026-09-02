# Task Brief T2 — 记录与聚合管道三文件

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f6`,客户端 `yucai/client/`。**不改生产代码,只新增测试文件 + Makefile 尾追加。**

## 先读(必读)

1. `docs/.../2026-09-02-e2e-module-links/design.md` 的 ADR-3/4/6 与 LLD-2/3/4/5/7(断言口径)
2. `yucai/client/integration_test/link_support.dart`(T1 落地的共享 helper:**必须复用** resetTestDb/fundsAccount/balanceOf/fixedToday/deleteTestDb)
3. `yucai/client/integration_test/link_receivable_collect_test.dart`(T1 范式样板)
4. 涉及生产代码(读签名,别改):`lib/template/data/template_local_ds.dart`、`lib/core/notifications/auto_record_scheduler.dart`、`lib/budget/data/budget_local_ds.dart`、`lib/goal/data/goal_local_ds.dart`、`lib/tag/data/tag_repository_impl.dart`(TagLocalDataSource)、`lib/transaction/data/transaction_local_ds.dart`(summary/recordTransaction)、`lib/report/presentation/widgets/category_breakdown_pie.dart`(aggregateCategorySlices 纯函数)

## 交付物(3 个新测试文件 + Makefile 追加)

共同模式:文件头中文注释(FR 编号+单独跑警告+运行命令);setUpAll `resetTestDb()`;夹具独立前缀(订链*/预链*/标链*);断言前后差值+手算 oracle 注释;tearDownAll `deleteTestDb()`。

### 1. `link_subscription_template_test.dart` — FR-2 订阅 + FR-3 模板

查证过的语义(以代码为准,有出入读代码后按代码写注释说明):
- `TemplateLocalDataSource.create(...)` 参数含 direction(expense/income/transfer)、sourceAccountId/destinationAccountId、cycle(weekly/monthly/yearly/custom)+cycleDays+billingDay、startDate/endDate(date-only 字符串)、autoRecord、category。**nextDate 在 create 时算 = startDate 后一个周期**(首期发生日)。
- `record(templateId)` → RecordResult{transactionId, nextDate}:交易日期=当前 nextDate、description=模板名、direction 配对复式;**category 为空或指向已删账户 → 自动建 `订阅·<模板名>` 分类账户**(a7e580ac 回归点);暂停模板 → ServerFailure('模板已暂停')。
- `AutoRecordScheduler({templates, notifier}).run(today)`:对 autoRecord&&!paused 模板循环 record 直到 nextDate>today 或 >endDate(cap 1000);`TemplateRepoAutoRecord` 包装 template repo。notifier 用什么实现读 `due_scanner.dart`/现有调用处,选可注入的 no-op/最小实现(测试不测通知)。

断言(LLD-2/3):
1. 订阅补账:monthly 模板 startDate = fixedToday 减 4 个月(首期 nextDate≈减 3 个月)→ `run(fixedToday)` → 恰 3 笔交易(description=模板名,余额 −3×amountCents 差值),模板 nextDate 前移至 fixedToday 之后;RunResult.recorded==3。
2. endDate 截断:endDate = fixedToday 减 1 个月 → 只补 2 笔(到 endDate 为止)。
3. 空 category fallback:expense 模板 category 留空 → record 后存在名为 `订阅·<模板名>` 的分类账户(账户列表查名)且交易入列 —— a7e580ac 回归。
4. 模板 record:expense 模板(有 category 指向分类账户)→ 交易字段与模板一致+余额联动+nextDate 推进一个周期+lastTransactionId 落位;paused 模板 → 抛'模板已暂停'。

### 2. `link_budget_goal_test.dart` — FR-5 预算(含跨月) + FR-6 目标

查证过的语义:
- `BudgetLocalDataSource.createBudget({name, month:'YYYY-MM', currencyCode, items:[(accountId, plannedAmountCents, notes?)]})`;`getBudgetByMonth(month)` → actual = **max(Σdebit, Σcredit)** 该账户 entries 在月窗口内(UTC 月界);窗口来自预算行存储 month,无 wall-clock。
- 记支出用 `TransactionLocalDataSource.recordTransaction(RecordTransactionParams(...))` 直接配复式(expense:debit 分类账户/credit 资金账户),参数形态参考 `template_local_ds.dart` 的 `_createTxnForRow` 或 demo_seed 的写法。
- `GoalLocalDataSource.createGoal({name, type(GoalType: 1 Savings/2 DebtPayoff/3 Investment), targetAmountCents, linkedAccountIds, ...})`;`recordContribution({id, amountCents})` 只加存储列不动余额;有关联时读时聚合(Savings=Σ关联账户 currentBalanceCents)覆盖存储值。

断言(LLD-4/5):
1. 当月消耗:预算 month='2026-09' 绑分类账户,记一笔该月支出(交易日 mid-month 避月界)→ item actual +金额、余额差值 oracle。
2. 跨月隔离:上月(2026-08)另记一笔 → getBudgetByMonth('2026-09') 不含它(actual 不变);getBudgetByMonth('2026-08')(若有该月预算或建第二个)含 —— 至少断言 09 不含 08。
3. 手动注资:无链目标 recordContribution → currentAmount +额、**资金账户余额不变**(显式断言不变);累计 ≥100% → 状态/进度翻转(GoalView 字段读代码确认)。
4. 关联读时聚合:Savings 目标 linkedAccountIds=[资金账户] → 记交易使余额 B1 → 目标 actual==B1(非存储列)。

### 3. `link_tag_report_test.dart` — FR-4 标签(改形) + FR-8 报表 oracle

查证过的语义:
- `TagLocalDataSource.create({name, color})` / `addTagToTransaction({tagId, transactionId})`(幂等)/ `removeTagFromTransaction` / `getTransactionTags(transactionId)`。**没有按标签反查**(全库只有交易→标签方向),不要写反查断言。
- `TransactionRepository.summary(y, m, {accountId?, scope, day?})`(实现于 TransactionLocalDataSource.summary):income=收入账户 credit 和、expense=支出账户 debit 和、net、dailyAvg、byDay[].byCategory[](按账户名聚合,降序);裸 cents 无 FX。
- `aggregateCategorySlices(MonthlySummary, {filter})`(category_breakdown_pie.dart:55,纯函数)可 import 使用。

断言(LLD-6/7):
1. 标签:建 2 标签挂同一交易(其一重复挂)→ getTransactionTags 恰 2(幂等);移除 1 → 恰 1。
2. 报表 oracle:夹具跨 2026-08/09 两月、两个分类账户、N≥4 笔已知收支 → summary(2026,9) 的 income/expense/net/dailyAvg/byDay 手算 oracle;aggregateCategorySlices 占比 oracle;summary(2026,8) 独立 oracle(月窗口隔离)。

### 4. Makefile

`E2E_FILES` 尾部追加这三个文件(保持注释说明)。

## 验证(全部执行并贴证据;三文件必须逐个单独跑,先杀 yucai_client 残留)

1. 每文件:`cd yucai/client && flutter test integration_test/<file> -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db` → 0 failures
2. `flutter analyze` → 新文件 0 条
3. `cd yucai && make -n client-e2e` → 7 文件列表
4. 每文件跑完确认 `yucai_test.db` 已删

## 约束

中文注释;不改生产代码;oracle 手算注释;不 commit。完成后报告:文件清单+每文件测试输出摘要+analyze/make -n 证据。
