# Design: F43 报告汇编层+财务报告页

prototype: v7(OD run `64dbf66b` 产出中;变体 A/B 用户拍板后 CURRENT 指 v7)

## Context

- 上游:[spec.md](spec.md)(FR-1..8 + NFR-1..3,grill 六决策已拍板);release 级决策见 release.md。
- 现状:report 模块仅 /reports 图表页(TransactionRepository.summary 单源,三态路由 local/remote)。
- **架构事实**:client 本地 drift 库已落地(schemaVersion=11,29 表;绑定后=全量镜像 `bound_mirror.dart` rebuild,guest 恒本地)——**注意 [architecture.md](../../../architecture.md) 的「本地 DB:无」(ADR-005 行)已过时**(R6 落地后未更新),本设计按实际架构,文档修正走 fast-lane,不耦合本票代码。
- 约束:零 proto/server 改动;三态一致纯本地(FR-2);≤2s@1 万分录(NFR-1);fl_chart + design-v2 令牌复用(NFR-2)。
- 关键既有资产:余额规则(`balance_updater.dart` 与 server 同款)、`TransactionDao.getAllTransactions/getAllEntries`、`LocalPerformanceAssembler.assemble({DateTime? rangeStart})`(缺 rangeEnd)、budget 本地读时 actuals 口径(max(Σdebit,Σcredit)/item/月)。

## Goals / Non-Goals

**Goals**:FR-1..8 全覆盖——期选择+入口、纯本地三态一致汇编、六章节快照(含回放/严格现金流/勾稽/绩效区间/TWR)、ExpenseBasis 抽象、分阶段进度、报告页 UI。
**Non-Goals**:MD&A 规则(F44)、导出(F45)、待摊口径实现(R17 仅接口预留)、目标章节(backlog)、AI 叙述、server 端聚合。

## Decisions(ADRs,均含挑战-辩护;challenge/defense 全文见 spec Grill record + 本节)

- **ADR-1 纯快照 ReportDocument + 分阶段进度**。汇编=一次性纯函数(本地库输入 → immutable ReportDocument);bloc 只管期选择/触发生成/渲染。挑战:惰性章节加载首屏更快;防御:回放 O(n) 单遍(1 万分录百毫秒级,NFR-1 预算宽裕)、**ReportDocument 是 F43/F44/F45 三票共享契约**(F44 规则输入=快照,F45 导出=同文档渲染)、勾稽不变式在快照内单点 assert、fixture 进出可测试性最强。**用户确认并追加要求:生成过程必须有进度显示 → FR-8**(四阶段:读取账本/回放余额/汇编章节/计算绩效)。
- **ADR-2 汇编数据访问 = report 自有 port + core DAO 直读,投资绩效经 HoldingRepository 扩展**。备选否决:①直接复用各模块 repository 汇总(三态路由会走 remote 破坏 FR-2 纯本地;networth/performance 锚定 now 无时点能力);②跨模块 import 各模块 local DS(违反「消费方不 import 生产方 data 层」port 约束)。定案:`ReportLedgerStore`(report domain port)读 accounts/entries/transactions/holdings/budgets 原始行,adapter(report/data)直读 core/localdb DAO(core=共享基建,非任何模块私有);收支/现金流/资产负债/预算执行**全部自算单源**(同一份 entries 推导,勾稽天然成立);投资绩效=TWR/市值链,经 `HoldingRepository.getPortfolioPerformance` **纯新增可选区间参数**(domain 接口+local assembler `assemble(rangeStart, rangeEnd)`,默认行为不变向后兼容)。**语义一致性护栏**:conformance 测试——同种子账本,报告自算收支对照 `TransactionLocalDataSource.summary`(测试内 import 允许),数值必须相等,防两套聚合漂移。
- **ADR-3 回放引擎 = 纯函数单遍扫描**。entries 按日期升序,前缀累计 delta 至期初(exclusive)/期末(inclusive)两时点;账户余额@T = initialBalanceCents + Σ(T 前分录 delta),delta 规则照 balance_updater(asset/expense: debit−credit;liability/equity/income: credit−debit);持仓时点市值经 assembler 的 qty@T×price@T(成交价 ffill)。多币种:折算基准 CNY,历史汇率取 RateHistories 该日最近可得,缺失回退现值汇率——**附注披露**(spec FR-4 已确认接受近似)。
- **ADR-4 现金流分类器 = 表驱动规则矩阵**。维度:本方科目是否现金(savings 类)×对手方科目类型(income/expense/投资类资产/现金/其他负债权益)。映射:对手 income/expense→经营;对手投资类资产(investment/fixedDeposit/goldFx/storedValue/realEstate/otherAsset)→投资;对手负债/权益→融资;现金↔现金→内部抵消不计;非现金×非现金→不计(如储值卡消费)。矩阵即测试全组合清单。勾稽:三类净额之和 == 期末−期初现金余额(汇编内 assert+测试钉死)。
- **ADR-5 报告页 = 单页滚动六章节 + sticky 章节锚点 + 四阶段进度**。变体 A(顶部 sticky 锚点条)/B(右缘点状锚点)由原型拍板。挑战:tab 分章更轻;防御:财报一体感(用户原始诉求)、锚点导航已解决长滚动定位、F45 导出渲染同结构。
- **ADR-6 ExpenseBasis = domain port,构造注入**。`abstract class ExpenseBasis { ... }`(签名见 LLD),默认 `CashExpenseBasis`(现状 TransactionSummary 语义:expense 科目 debit 口径);汇编服务构造函数注入,测试以 fake basis 替换验证章节结构不变(FR-7)。
- **ADR-7 assembler 区间扩展 = 可选参数向后兼容**。`assemble({DateTime? rangeStart, DateTime? rangeEnd})`,两者缺省=现状(now 锚定),既有调用/测试零改;新增参数仅 report 汇总路径使用。TWR 区间计算按日粒度市值链式(期初起链,净现金流子期链接)。

## HLD

```
lib/report/
  domain/
    report_document.dart        # ReportDocument + 章节 value objects(immutable)
    expense_basis.dart          # abstract ExpenseBasis + CashExpenseBasis
    report_ledger_store.dart    # abstract ReportLedgerStore(port:原始行读取)
    report_assembly_service.dart# 纯域服务:store 数据 + basis → ReportDocument(带 phase 回调)
  data/
    report_ledger_store_impl.dart # @Injectable adapter:core/localdb DAO 直读
  presentation/
    financial_report_bloc.dart  # GenerateReportRequested(period)→Loading(phase)/Loaded(doc)/Error(retry)
    pages/financial_report_page.dart      # 期选择+进度+报告体(/reports/full 子路由)
    widgets/  # overview_hero, section_anchor_bar, category_bars, cashflow_table,
              # budget_bars(参照预算页), perf_cards, notes_card(口径/未包含项)
lib/holding/(最小改动)
  domain/repositories/holding_repository.dart  # getPortfolioPerformance 追加可选区间参数(纯新增)
  data/local_performance_assembler.dart       # assemble 追加 rangeEnd;区间分解(期初/期末市值/净买入/TWR)
lib/app/router.dart            # /reports/full 子路由(静态,在 /:id 之前——本项目无参数子路由,直接加)
report_page.dart               # 顶栏加「财务报告」入口按钮(FR-1)
```

依赖方向:presentation→domain←data(DDD 四层);report **不 import** 任何其他模块的 data 层(HoldingRepository domain port 注入,合法消费);core/localdb=共享基建。

## LLD(设计契约,非实现码)

**ReportDocument**(核心数据结构,三票共享):

```
ReportDocument {
  ReportPeriod period;                 // month(year, m) | year(y)
  DateTime generatedAt;
  OverviewSection overview;            // netWorthStart/End, income, expense, surplus,
                                       // savingsRate, cashDelta, notes: List<ReportNote>
  BalanceSheetSection balanceSheet;    // assets/liabilities: List<CategoryAmount{category,
                                       //   amount, pct}>, startVsEnd rows
  IncomeStatementSection incomeStmt;   // income/expense: List<CategoryAmount>, dailyAvg,
                                       // priorComparison{label, deltaPct}(月报环比/年报同比)
  CashFlowSection cashFlow;            // operating/investing/financing: ActivityFlow{inflow,
                                       //   outflow, net}, netDelta, reconciled: bool
  BudgetSection? budget;               // items: List<BudgetItemView{name, actual, limit, pct,
                                       //   overran}>;null=隐藏
  InvestmentSection? investment;       // mvStart, mvEnd, netBuy, estGain, twr;null=隐藏
  List<String> excludedSections;       // 未包含项附注来源(FR-3)
}
```

**回放算法**(ReportAssemblyService 内,ADR-3):

```
1. entries = store.entries() 按 (date, id) 升序
2. 单遍:for e in entries → 按 e.date < periodStart ? 累入 startPrefix : (e.date <= periodEnd ? 累入 endPrefix : break)
3. balanceStart(account) = initial + startPrefix[account];balanceEnd = initial + endPrefix[account]
4. 净资产@T = Σ asset 账户 balance@T(折 CNY)+ 持仓市值@T(assembler)− Σ liability 余额@T
```

**现金流矩阵**(ADR-4,分类器唯一事实源):

| 本方(现金) | 对手方 | 活动 |
|---|---|---|
| 现金 | income/expense 科目 | 经营(in=credit income 侧现金增加;out=debit expense 侧) |
| 现金 | 投资类资产 | 投资 |
| 现金 | 负债/权益 | 融资 |
| 现金 | 现金 | 不计(内部) |
| 非现金 | 任意 | 不计 |

**ExpenseBasis 契约**:`List<CategoryAmount> expenseByCategory(entries, period)` + `Money totalExpense(entries, period)`;CashExpenseBasis 实现=expense 科目 debit 汇总(byCategory 按 expense 科目账户)。

**进度契约**(FR-8):`ReportPhase { loadingLedger, replaying, assembling, performance }`;`generate(period, {void onPhase(ReportPhase)?})`;bloc Loading(phase) 状态驱动 UI;>300ms 才显示进度提示(spec 验收)。

**勾稽 assert**(汇编内):`cashFlow.netDelta == balanceEnd(cash) − balanceStart(cash)`,不等即抛 StateError(测试构造反例钉死必抛)。

## Risks / Trade-offs

- [回放 vs dashboard 净值口径差] → 附注披露,用户已确认(spec Grill #1)。
- [历史汇率近似] → RateHistories 最近可得回退现值,附注披露。
- [assembler 扩展动 holding 既有代码] → 可选参数向后兼容+既有测试零改护栏(全量回归门)。
- [自算聚合 vs transaction_local_ds 漂移] → conformance 测试同种子对照,数值相等才绿。
- [大账本性能] → O(n) 单遍+NFR-1 计时测试(1 万分录种子)。
- [drift schema 演进] → ReportLedgerStoreImpl 单点隔离,表结构变化只改 adapter。

## Migration Plan

纯新增:页面+服务注册(getIt)+路由+/reports 入口按钮;holding 两处纯增量参数。回滚=还原路由/注册,无数据迁移无写入。

## Open Questions

- 原型变体 A(sticky 锚点条)/B(右缘点状)待用户拍板(OD run 收敛后)。
- architecture.md「本地 DB:无」条目过时 → fast-lane 修正(R6 事实),与本票代码解耦。
