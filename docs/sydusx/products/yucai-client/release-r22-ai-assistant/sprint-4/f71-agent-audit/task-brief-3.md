# Task Brief T3 — 全门 + 帽石 + 覆盖表

- worktree `.claude/worktrees/r22-f71`(T1/T2 已合入,HEAD a07efc8e)。不碰生产码。
- 任务:
  1. **帽石集成测**(扩 write_pipeline_integration_test 或新文件):真库+真 executor+真 sink——记账→agent_audit 恰一行(逐字段+实体 id 与交易可关联查询回)→改+删各一行→失败重试后同键两行(failed+ok)→**取消零行**(F70 幂等语义在审计面的体现)→对话框数据源 watchPage 与表一致(DAO 直查互证)。
  2. **全门**:全量 flutter test(精确数)/analyze 466/git diff main -- yucai/server 空。
  3. **覆盖表 code-ledger.md**:spec FR-1..3+NFR-1..2↔用例映射零 BLOCKED+T1-T3 commit+偏差记档(v15→v16 实证/_createIndexIfAbsent 新家法/入口行卡底部+超前天日期兜底差异/dialog watch Timer 烧毁测试基建家法)。
- 验证门:全门三条+帽石绿(输出摘要)。commit `test(assistant): F71-T3 审计帽石+全门+覆盖表`。汇报:帽石断言摘要/全门输出/覆盖表摘要/commit hash。
