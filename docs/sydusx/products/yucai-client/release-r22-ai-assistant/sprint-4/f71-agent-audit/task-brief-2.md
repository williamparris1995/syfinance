# Task Brief T2 — 审计查看对话框(照 v21)

- worktree `.claude/worktrees/r22-f71`(T1 11d1857f 已合入)。TDD(widget 测);不碰 server/F46/T1 生产(豁免:model_management_card 挂入口行属本票)。
- 必读:**prototype v21 ui/agent-audit-dialog.html**(三态视觉事实源:入口行带条数+chevron/对话框列表[时间相对格式/工具 chip/摘要/✓绿⚠红+原因]/加载更多/副行「全部操作均经你确认」/空态两行文案);T1 的 AgentAuditDao(watchPage/count);model_management_card 结构(挂行位)。
- 任务:
  1. **入口行**:model_management_card 底部加「操作记录」行(label+「N 条 ›」N=count 实时)+点击开对话框。
  2. **`widgets/agent_audit_dialog.dart`**:只读 AlertDialog——标题「AI 助手 · 操作记录」+关闭;副行总数+「全部操作均经你确认」;列表行(相对时间[今天 14:32/昨天 09:15 式,纯日期比较无时区抖动]/工具 chip[记一笔|改一笔|删一笔]/摘要/徽标 ok 绿✓|failed 红⚠+原因小字);「加载更多」append(watchPage limit 20 递增 offset);空态两行照 v21;无编辑无删除。
  3. widget 测:入口行条数/对话框打开/列表渲染(含失败行原因)/加载更多追加/空态/关闭;金额千分位(摘要由 T1 入库串携带,渲染原样)。
- 验证门:`flutter test test/assistant/` 绿/analyze 466 零新增/server diff 空。commit `feat(assistant): F71-T2 审计查看对话框(照 v21)`。汇报:文件清单+测试数+v21 对齐差异表+commit hash。
