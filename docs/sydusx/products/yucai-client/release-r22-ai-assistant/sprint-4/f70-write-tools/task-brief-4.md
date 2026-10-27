# Task Brief T4 — 写链帽石集成测 + 全门 + 覆盖表

- worktree `.claude/worktrees/r22-f70`(T1-T3 已合入,HEAD d8b9698c)。不碰生产码(缺陷如实 FAIL)。
- 任务:
  1. **写链帽石集成测**(扩 `test/assistant/integration/`,新文件 `write_pipeline_integration_test.dart`):内存 drift 真库+真 registry(三写工具)+脚本化 LlmStreamClient(首轮回 transaction_add 的 tool_call 分片,次轮文本收尾)+真 AgentLoopServiceImpl+真 bloc(真 WriteExecutorImpl)——断言全链:①工具 ToolData(requiresApproval)→loop WriteProposed→bloc pending 卡(preview 含解析后 id 与摘要)②**确认前 DB 零行** ③ConfirmWrite→executor 真写→DB 一行逐字段(金额 cents/科目账户/资产账户/note)④审计 logWrite 行 ⑤loop 会话上下文含「已记:」单行(appendToolOutcome)⑥改:脚本二轮 update 提案→diff 卡 before/after→确认→DB 更新逐分 ⑦删:提案→destructive 卡→确认→DB 零行 ⑧幂等:同 key 二次确认→DB 笔数不变 ⑨取消:卡 cancelled→DB 零写。真库直查独立断言(不 import 工具)。
  2. **全门**:全量 flutter test(精确数)/analyze 466 零新增/git diff main -- yucai/server 空。
  3. **覆盖表**:新建 code-ledger.md(F64-F70 格式):spec FR-1..5+NFR-1..4↔用例映射零 BLOCKED+T1-T4 commit+领域发现记档(分类=account-as-category/update 全分录重建+direction 扩展/预填无路由)+真壳手验移交注记(用户实际使用即验收)。
- 验证门:全门三条+帽石测本机绿(输出摘要)。commit `test(assistant): F70-T4 写链帽石集成测+全门+覆盖表`。汇报:帽石九断言摘要/全门输出/覆盖表摘要/commit hash。
