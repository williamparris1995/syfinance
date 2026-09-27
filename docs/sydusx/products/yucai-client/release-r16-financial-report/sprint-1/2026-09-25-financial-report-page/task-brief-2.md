# Task Brief T2 — ReportLedgerStore adapter + conformance + 性能(F43 R16 sprint-1)

**工作目录(必须在此)**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f43`(分支 feature/r16-f43;客户端 `yucai/client/`)。

**流程**:先调 Skill 工具加载 `sydusx-tdd` 并遵循。前置已就绪:T1 domain 纯核(commit 4916db1c,`lib/report/domain/report_ledger_store.dart` 的 port+行 VO 已定)、T3 区间扩展(3f70bde0,`HoldingRepository.getPortfolioPerformance({rangeStart, rangeEnd})` 已有)。

## 任务

1. **`lib/report/data/report_ledger_store_impl.dart`** — `ReportLedgerStore` 的 drift adapter(@Injectable):直读 `core/localdb` DAO(AccountDao/TransactionDao 及 holdings/budgets 相关 DAO),产出 T1 定义的行 VO。注意:AccountRow.category 用本地库存储形态映射到 T1 约定的枚举名字符串(读 T1 注释);proto int ↔ 枚举名换算照 `account/data/mappers/account_mapper.dart` 惯例但**不 import proto**(用本地列值)。若 T1 port 的行 VO 字段不够表达(如 budget/holding 读取),**最小扩 port**(conventions:改接口 grep 全 implementer——目前仅你一个)。
2. **区间绩效的本地强制路由(FR-2 三态一致的接口约束;T3 评审 Important 落点)**:`holding_repository_impl.dart` 的 `getPortfolioPerformance` 加一条路由规则——**rangeStart/rangeEnd 显式给出时强制走本地 DS**(即 `_useLocalDs || rangeStart != null || rangeEnd != null`;guest/bound 一致;server proto 无区间字段,在线直达 server 会丢参数破坏三态一致——T3 评审实证 impl:255-261 远端调用不传区间)。domain 接口注释写明该语义。既有无区间调用行为零改(护栏测试:无参→原路由)。**顺带补 T3 评审 Minor MISSING**:在 `test/holding/data/local_performance_assembler_range_test.dart` 追加 spec FR-6 负值场景用例(期初 10000→期末 12000、净买入 5000 → 估算收益 **−3000**,spec.md:54 逐字)。
3. **conformance 测试**(ADR-2 护栏):同种子 drift 内存库,报告侧支出/收入聚合(经 CashExpenseBasis+LedgerEntryRow)对照 `TransactionLocalDataSource.summary`(测试内 import 允许)——income/expense 总额与分类构成**逐项相等**。种子必须含:多 expense 科目、贷方分录(冲抵语义:两侧都 debit 单边,应相等)、跨期分录(期外不进)。
4. **NFR-1 计时测试**:1 万条分录(若干账户×随机日期)种子,回放+分类+basis 全链 ≤2s(wall clock,`test/report/data/` 下 vm 测试, Stopwatch 断言,阈值留余量写 2s)。

## 硬约束

- report/data 不得 import 其他模块 data 层(holding/budget/transaction 的 data);core/localdb DAO 是共享基建可用;holding 的 domain port(HoldingRepository)可用。
- 零 proto/server 文件改动;中文注释;金额 cents;不碰 test/holding 既有文件。
- adapter 读全量:entries()/accounts() 一次拉全(报告汇编单遍消费),不做流式分页(YAGNI,NFR-1 管性能)。

## 测试文件

`test/report/data/report_ledger_store_impl_test.dart`(adapter 映射+内存库)、`test/report/data/conformance_summary_test.dart`、`test/report/data/replay_perf_test.dart`(计时);holding 侧护栏可加 `test/holding/data/repo_range_routing_test.dart`(新文件)。

## 完成动作

`cd yucai/client && flutter test test/report`(及 holding 套件)+`flutter analyze` 零新增 → commit `feat(report): T2 LedgerStore adapter+conformance 门+性能测试;区间绩效强制本地路由`。回报:文件清单、测试数(新旧)、conformance/计时数字、commit hash、遗留。
