# Task Brief T1 — 全量只读工具×5 + 口径断言八工具化

- worktree `C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f65`(已 rebase 含 F66/F67)。TDD;不碰 server/F46/assistant 既有生产文件(**豁免**:工具注册表 DI 行 2g 段加五工具注册属本票)。
- 必读:同目录 spec.md(FR-2 三场景)+design.md(ADR-3/LLD 五工具 schema);F64 范式=`lib/assistant/data/tools/`(三件工具+tool_args.dart 共用分页/kind 校验);`test/assistant/data/tools/tools_caliber_test.dart`(口径断言范式,扩展它)。
- 五工具(全部 AssistantTool 实现,cents+元双口径,聚合摘要,分页≤50):
  1. **holdings_list{name?,page?,page_size?}**:注入 HoldingRepository;持仓面板口径(每标的:名称/代码/数量/成本 cents+元/市值/浮动盈亏+百分比;汇总:总成本/总市值/总浮盈)。看 holding 面板/bloc 现用字段定口径,断言同源。
  2. **transactions_search{start?,end?,account?,category?,keyword?,direction?(in|out),page?,page_size?}**:注入 TransactionRepository;过滤+分页+汇总(笔数/收入合计/支出合计/净额);top-N 条目(日期/描述/对方/金额/账户)。
  3. **budgets_status{}**:注入 BudgetRepository;每预算(名称/额度/已用/剩余/执行度%/超支标记)+汇总。
  4. **goals_list{}**:注入 GoalRepository;每目标(名称/目标额/当前额/进度%/预计达成若有)+汇总。
  5. **performance_range{start?,end?}(缺省年初至今)**:**直接 import report/domain 的 F43 汇编服务**(grep report_assembly/assembler 的区间计算入口;期初/期末市值/净买入/估算收益/区间 TWR,报告口径);输出含区间日期与口径说明字段;**口径断言=与报告页同区间输出逐分一致**(照 F43 既有测试取数方式)。
- 测试:五工具各单测(过滤/分页/双口径/汇总)+tools_caliber_test 扩展为**八工具参数化**(F64 三件+新五件同库逐分)。
- 验证门:`flutter test test/assistant/` 绿/`flutter analyze` 零新增(基线 459)/`git diff yucai/server` 空。commit `feat(assistant): F65-T1 全量只读工具五件+口径八工具化`。汇报:文件清单+测试数+F43 汇编入口形态+commit hash。
