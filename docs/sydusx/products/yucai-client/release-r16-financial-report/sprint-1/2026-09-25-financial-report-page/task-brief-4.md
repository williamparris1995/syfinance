# Task Brief T4 — ReportAssemblyService 编排(F43 R16 sprint-1)

**工作目录(必须在此)**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f43`(分支 feature/r16-f43;`yucai/client/`)。

**流程**:先调 Skill 工具加载 `sydusx-tdd` 并遵循。前置已就绪:T1 domain(4916db1c:ReportDocument 全套 VO/BalanceReplay/CashFlowClassifier/ExpenseBasis)、T2 adapter(b1cd1697:ReportLedgerStoreImpl+conformance 门+区间强制本地路由)、T3 区间绩效(3f70bde0:PeriodPerformance 五要素)。动手前读这三笔的相关文件+`test/report/data/conformance_summary_test.dart`(你的收入侧聚合必须保持该门绿)。

## 任务

1. **扩 ReportLedgerStore port + adapter(T2 文件追加方法,不动既有)**:
   - `budgetRows()`:预算原始行(budget 头+items+关联账户 id/category/名称),供预算执行章节;实际值口径**对照 `lib/budget/data/budget_local_ds.dart` L157-186**(item 账户当月 max(Σdebit,Σcredit))——先读它,写 conformance 断言。
   - 汇率读取:外币账户折 CNY 的最小读取(查 `core/localdb/tables/reference_tables.dart` 的 Currencies/RateHistories 现状后定形态;默认策略:RateHistories 该日最近可得,缺失回退现值 exchangeRate,再缺失跳过折算并在 notes 注记)。默认币种账户直加。
2. **`lib/report/domain/report_assembly_service.dart`** — 编排服务(@Injectable,构造注入 ReportLedgerStore+ExpenseBasis+HoldingRepository):
   - `Future<ReportDocument> generate(ReportPeriod period, {void Function(ReportPhase)? onPhase})`,四阶段回调顺序 loadingLedger→replaying→assembling→performance(design LLD 进度契约,FR-8 数据源)。
   - **总览**:期初/期末净资产(=Σ资产账户回放余额[折 C]+持仓时点市值[PeriodPerformance.mvStart/mvEnd]−Σ负债回放余额)、income/expense/surplus/savingsRate、现金净变动。
   - **资产负债**:期初/期末两栏、资产/负债按 category 构成(CategoryAmount)、变动(ReportPeriod 内)。
   - **收支**:CashExpenseBasis 支出构成+**收入侧内聚**(income 科目 credit 单边,与 conformance 门同口径,T2 遗留#4 收编)、日均(byDay)、prior 对比(月报环比上月/年报同比上年:同一 entries 重过滤前期即可,PriorComparison.create)。
   - **现金流**:CashFlowClassifier,期初/期末现金余额由 BalanceReplay 传入(勾稽已在 classifier assert)。
   - **预算执行**:budgetRows×期内聚合;月报=当月各 item,年报=全年(item 限额×年内月数或逐月汇总,以 budget_local_ds 语义为准并注释);无预算→章节 null+excludedSections 记「预算执行(本期无预算)」。
   - **投资绩效**:HoldingRepository.getPortfolioPerformance(rangeStart/rangeEnd 强制本地路由)→ PeriodPerformance 五要素映射;无持仓或 period==null(坏价)→章节 null+excluded 记「投资绩效(本期无持仓)」。
   - **notes**:口径附注三条(回放近似含与 dashboard 现值可能小差额/历史汇率近似/现金及等价物=仅 savings,定存按投资活动列示)+未包含项。
3. **测试**(`test/report/domain/report_assembly_service_test.dart`,fake store+fake holding repo):
   - 全链 fixture:六章节齐全(有预算有持仓)→ 各章节数值手算 oracle;phase 回调顺序钉死。
   - 自适应隐藏:无预算→budget null+excluded 文案;无持仓→investment null+excluded 文案(FR-3)。
   - 年报口径(prior=同比上年);月报(环比上月)。
   - budget actuals conformance:同种子对照 budget_local_ds 口径。
   - 收入侧保持 conformance_summary_test 绿(若需挪入服务,以门不红为准)。

## 硬约束

- 汇编服务在 domain 层:可依赖本模块 port(ReportLedgerStore/ExpenseBasis)+holding domain port;**不得 import 任何 data 层**(T2 adapter 的接线在 DI/core 注入配置,若需改 injection.config 跑 build_runner)。
- 零 proto/server 改动;中文注释;cents;不碰 test/holding 既有文件。
- `flutter test test/report`+`flutter analyze` 零新增;全量 `flutter test` 也绿(interface 追加方法按 conventions 跑全量)。

## 完成动作

commit `feat(report): T4 汇编服务——四阶段编排+六章节快照+自适应隐藏+口径附注`。回报:文件清单、测试数、全量绿证据、commit hash、遗留。
