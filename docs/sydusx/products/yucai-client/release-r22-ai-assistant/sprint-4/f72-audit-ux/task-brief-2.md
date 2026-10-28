# Task Brief T2 — 以此再记一笔 + 全门 + 覆盖表

- worktree 同 T1(T1 已合入)。TDD;不碰 server;note_parser/bloc 扩/dialog onTap 豁免面。
- 必读:design.md(ADR-3/4)+spec FR-4/NFR-1;F70 `_writeNote` 三族格式(成对解析对象=记族「已记:支出 ¥35.00 午饭」);assistant_panel_bloc 事件面;overlay host 挂载逻辑。
- 任务:
  1. **`data/note_parser.dart`**:AddActionFromNote.parse(note)→TransactionAdd 参数(方向/金额/描述;账户分类不猜——按 F70 工具默认推导逻辑在提案时走 accounts 推导?**简案**:解析出三要素后构造与工具同参的提案 JSON,复用 transaction_add_tool 的 execute 全套解析[账户分类描述推导/消歧], ToolError 照常可出);与 _writeNote **成对往返测**(生成→解析→字段相等;格式漂移即红)+畸形串 null。
  2. **bloc 扩**:event `ProposeFromHistoryRequested(String note)`→解析→经 add 工具 execute 生成 WriteApproval(pending 新 uuid 键)→消息流插入;失败(解析 null/ToolError)→ErrorMsg 文案「无法从该记录生成提案」。
  3. **对话框 onTap**:记行可点(hover+右缘提示照 v22;改/删只读态视觉区分)→回调链(对话框→设置卡→全局开浮层+发 bloc 事件;照 design ADR-4 最短路径:对话框直接 getIt<AssistantPanelBloc>? 若 bloc 非 getIt 注册则经回调上抛至 host——按实际接线选并汇报)。
  4. **集成测**:真链(真库+真工具+bloc)——点历史行→pending 卡(新键≠原键)→**点击本身零落库**→确认→新交易+审计新行(原交易不动)→取消零副作用;改/删行点击无事件。
  5. **全门+覆盖表**:全量 flutter test/analyze 466/server diff+code-ledger(FR↔用例+偏差)。
- 验证门:全门三条+集成测绿。commit `feat(assistant): F72-T2 以此再记一笔+全门`。汇报:接线选型/测试数/全门输出/覆盖表摘要/commit hash。
