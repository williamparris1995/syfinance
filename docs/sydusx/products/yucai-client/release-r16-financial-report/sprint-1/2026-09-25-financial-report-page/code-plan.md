# Code Plan — F43 报告汇编层+财务报告页

> execute 2026-09-25。依据 spec.md(FR-1..8/NFR-1..3)+ design.md(ADR-1..7/HLD/LLD)+ prototype v7(变体 B)。生产代码全部在 `yucai/client/`;**零 proto/server 改动**(NFR-3,T6 门)。全局约定:DDD 四层依赖方向、跨模块只走 domain port、中文文案、getIt+injectable、flutter_bloc、fl_chart 复用。

## 任务分解(每 task 一个 unit+测试周期)

- [x] **T1 report domain 纯核**(S1/S2/S3/S4 域层):`lib/report/domain/` — ReportPeriod/ReportDocument+章节 VO、ExpenseBasis(abstract+CashExpenseBasis)、BalanceReplay(单遍前缀累计,delta 规则同 balance_updater)、CashFlowClassifier(表驱动矩阵)+勾稽 assert、ReportLedgerStore(abstract port)。纯 Dart TDD:fixture 进出,勾稽反例必抛,矩阵全组合测试。
  文件:domain/{report_document,expense_basis,balance_replay,cash_flow_classifier,report_ledger_store}.dart + test/ 镜像。
- [x] **T2 ReportLedgerStore adapter + conformance + 性能**(S1 数据层):`lib/report/data/report_ledger_store_impl.dart` — core/localdb DAO 直读(accounts/entries/transactions/holdings 行);conformance 测试:同种子对照 TransactionLocalDataSource.summary(收入/支出/分类构成逐项相等);NFR-1 计时测试:1 万分录种子 ≤2s(VM 测试)。
- [x] **T3 assembler 区间扩展**(S5,holding 模块):`local_performance_assembler.dart` 加 `rangeEnd`(缺省=现状,既有测试零改护栏);区间分解:期初/期末市值/当期净买入/估算收益/区间 TWR;`HoldingRepository.getPortfolioPerformance` + local DS 透传可选区间参数(纯新增)。
- [x] **T4 ReportAssemblyService 编排**(S1+S2 汇编):`lib/report/domain/report_assembly_service.dart` — store→回放→分类→basis→六章节快照+excludedSections+notes;ReportPhase 四阶段回调(FR-8);多币种折 CNY(RateHistories 最近可得→现值回退)。单测:fake store 全链 fixture。
- [x] **T5 bloc+页面+路由**(S6):`FinancialReportBloc`(GenerateReportRequested→Loading(phase)/Loaded/Error+Retry,bloc_test);`FinancialReportPage`(期选择月/年+翻期+生成按钮+四阶段进度>300ms 显示+六章节单页滚动+**变体 B 右缘圆点锚点**+附注两卡,fl_chart 组件复用,design-v2 令牌);router `/reports/full` 静态子路由;/reports 页顶栏「财务报告」入口。widget 测试+bloc 测。
- [x] **T6 门与收尾**(S7):flutter test 全绿+analyze ≤基线(439)+`make client-e2e`(新成员 financial_report 进管道)+proto/server 零 diff 核验;injectable build_runner 重生成核验;注记(文件+函数级中文注释)。

## 依赖与并行

T1 ∥ T3 独立可并行;T2 依赖 T1;T4 依赖 T1+T2+T3;T5 依赖 T4;T6 收尾。SDD:每 task 派 fresh subagent(sydusx-tdd)+两轴 code-review;fix loop 上限 5。

## 验收映射

FR-1→T5;FR-2→T2+T4(纯本地路径,无 remote 依赖);FR-3→T4+T5;FR-4→T1+T4;FR-5→T1(矩阵+assert);FR-6→T3+T4;FR-7→T1+T4;FR-8→T4+T5;NFR-1→T2;NFR-2→T5;NFR-3→T6。
