# Task Brief T1 — report domain 纯核(F43 R16 sprint-1)

**工作目录(必须在此)**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f43`(git worktree,分支 feature/r16-f43;客户端代码 `yucai/client/`)。

**流程**:先调 Skill 工具加载 `sydusx-tdd` 并遵循(RED→GREEN→REFACTOR,每 unit 后立即跑单测)。

## 任务

新建 `yucai/client/lib/report/domain/`(report 模块全新,照项目 DDD 四层惯例,参考现有模块如 `lib/tag/domain/`、`lib/budget/domain/` 的文件风格):

1. **report_document.dart** — 报告模型(immutable VO,金额一律 int cents):
   - `ReportPeriod`(sealed/abstract:monthly(year,month)/yearly(year);提供 `start`/`endInclusive` 边界、`label` 中文如「2026 年 8 月」「2025 年度」)
   - `ReportDocument` + 章节 VO,结构照 design.md LLD:overview(netWorthStart/End、income、expense、surplus、savingsRate、cashDelta、notes)、balanceSheet(assets/liabilities 各 List<CategoryAmount{category 代码,amountCents,pct}>,startVsEnd 变动行)、incomeStatement(income/expense 列表、dailyAvgCents、priorComparison{label,deltaPct})、cashFlow(operating/investing/financing 各 ActivityFlow{inflowCents,outflowCents,netCents},netDeltaCents,reconciled)、budget?/investment? 可空章节、excludedSections List<String>(未包含项附注文案)。
2. **expense_basis.dart** — `abstract class ExpenseBasis`(契约:`List<CategoryAmount> expenseByCategory(List<LedgerEntry> entries, ReportPeriod period)` + `int totalExpense(...)`)+ `CashExpenseBasis`(expense 类型科目按 debit−credit 汇总,分类维度=expense 科目账户)。
3. **balance_replay.dart** — `BalanceReplay` 纯函数:输入账户列表(id、type、initialBalanceCents)+按日期升序分录,输出 `Map<accountId, BalanceAtPeriod>`(start=period 起点前缀、end=period 终点含);**delta 规则必须照抄 `yucai/client/lib/transaction/data/balance_updater.dart` L38-48**(asset/expense: debit−credit;liability/equity/income: credit−debit)——先读该文件核对。
4. **cash_flow_classifier.dart** — 表驱动矩阵:`现金=仅 savings 类账户`;对手 income/expense 科目→经营;对手投资类资产(investment/fixedDeposit/goldFx/storedValue/realEstate/otherAsset)→投资;对手负债/权益→融资;现金↔现金→不计;非现金×非现金→不计。输出三类 ActivityFlow + `netDeltaCents`,内含**勾稽 assert**:三类净额之和 == 期末现金−期初现金,不等抛 `StateError`(消息含两侧数值)。
5. **report_ledger_store.dart** — `abstract class ReportLedgerStore`(数据源 port):定义原始行 VO(AccountRow{id,type(int 1..5),category(String?),initialBalanceCents,currencyCode}、LedgerEntryRow{accountId,counterpartyAccountId?,date,debitCents,creditCents,accountType,int? counterpartyType,counterpartyCategory}——字段按汇编所需最小集定)+ 读取方法(accounts()/entries()…)。**不实现 adapter**(T2 的事)。

## 硬约束

- **纯 Dart**:domain 文件零 flutter/drift/proto import;不碰 yucai/proto、yucai/server、其他模块任何文件。
- 分录行如何取对手方:一条双录分录有借贷两条目,现金流分类需要「现金科目条目 + 对手条目」配对——LedgerEntryRow 携带 transactionId,BalanceReplay/Classifier 按 transactionId 配对借贷双方(设计如此,若与数据现实冲突以能表达矩阵为准,在代码注释说明)。
- 中文注释(文件头+函数级),文案中文直写。
- 金额展示 pct 保留一位小数的计算放 VO(factory 构造时算)。

## 测试(yucai/client/test/report/domain/ 镜像)

- balance_replay_test:FR-4 场景(initial 0,8-15 一笔 debit 1000 → 期初 0/期末 1000)+跨期边界(7 月末/9 月分录不影响 8 月期初)+负债方向(credit 增加余额)。
- cash_flow_classifier_test:FR-5 四场景(储蓄→储值卡 500=投资流出500/现金净−500;储蓄→expense 300=经营流出300;信用卡刷卡+还款=经营0+融资300;勾稽反例必抛 StateError)+矩阵全组合穷举(现金/非现金 × 五类对手)。
- expense_basis_test:多 expense 科目汇总+分类构成+期内过滤。
- report_document_test:period 边界(月 8-01..8-31 23:59:59;年 1-01..12-31)+label+savingsRate=pct。
- 全部先 RED 后 GREEN;跑 `cd yucai/client && flutter test test/report/domain` 全绿,再 `flutter analyze`(不得新增告警,基线 439 info)。

## 完成动作

绿了之后 commit(仅本任务文件):`feat(report): T1 domain 纯核——报告模型/回放/现金流矩阵/ExpenseBasis(TDD)`。回报:文件清单、测试输出摘要(通过数)、commit hash、遗留问题。
