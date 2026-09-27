# Task Brief T3 — LocalPerformanceAssembler 区间扩展(F43 R16 sprint-1)

**工作目录(必须在此)**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f43`(git worktree,分支 feature/r16-f43;客户端代码 `yucai/client/`)。

**流程**:先调 Skill 工具加载 `sydusx-tdd` 并遵循。

## 任务(只动 holding 模块,最小增量)

1. **`yucai/client/lib/holding/data/local_performance_assembler.dart`**:
   - `assemble({DateTime? rangeStart})` → `assemble({DateTime? rangeStart, DateTime? rangeEnd})`——**rangeEnd 缺省=现状行为完全不变**(既有调用零改)。
   - 新增区间分解输出(供财务报告 FR-6):期初市值/期末市值/当期净买入(买入金额−卖出金额)/估算收益(期末−期初−净买入)/区间 TWR(按日粒度市值链式:期初起链,现金流子期链接;期初市值为 0 时 TWR 定义为 0 并注释)。返回形态:扩展现有返回模型或新增 `PeriodPerformance` VO(放 holding/domain/entities,二选一以最小侵入为准)。
2. **`yucai/client/lib/holding/domain/repositories/holding_repository.dart`**:`getPortfolioPerformance(...)` 追加**可选**区间参数(纯新增,签名向后兼容)。
3. **`yucai/client/lib/holding/data/holding_local_ds.dart`** + repository_impl(若分流):透传新参数到 assembler。

## 硬约束

- **既有测试零改护栏**:先跑 `cd yucai/client && flutter test test/holding` 记录基线通过数;改后必须原通过数不减、既有测试文件零修改(允许新增测试文件)。
- 不碰 proto/server/report 模块/其他模块;qty@T×price@T 回放与成交价 ffill 复用 assembler 既有私有逻辑(`_qtyAt`/`_priceOf`),**不得复制重写**(单源约束)。
- 中文注释;金额 cents。

## 测试(新增文件,如 `test/holding/data/local_performance_assembler_range_test.dart`)

- FR-6 场景:期初市值 42,770→期末 45,770,净买入 2,000 → 估算收益 +1,000(cents 口径构造);期内无买卖市值不变 → TWR=0;只有期末之后的价格数据不影响区间。
- 缺省参数行为不变:不传 rangeStart/rangeEnd 与旧签名输出一致(对照既有 assemble 用例或构造等价断言)。
- rangeStart+rangeEnd 同时给定时锚定 [start, end]。

跑 `flutter test test/holding` 全绿 + `flutter analyze` 无新增告警。

## 完成动作

commit(仅 holding 相关+新测试):`feat(holding): T3 assembler 区间扩展——rangeEnd+区间分解(期初期末市值/净买入/估算收益/TWR)`。回报:文件清单、新旧测试通过数对比、analyze 结果、commit hash、遗留问题。
