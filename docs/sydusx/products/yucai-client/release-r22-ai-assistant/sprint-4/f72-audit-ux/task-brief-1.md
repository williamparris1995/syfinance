# Task Brief T1 — DAO 搜索 + 对话框增强(分组/搜索/复制)

- worktree `.claude/worktrees/r22-f72`。TDD;不碰 server/F46;DAO keyword 参数与对话框增强豁免面。
- 必读:design.md(ADR-1/2/5)+spec FR-1/2/3+**prototype v22 audit-ux-enhanced.html**;F71 的 agent_audit_dao/dialog;仓内右键菜单先例(grep ContextMenu)+AppToast。
- 任务:
  1. **DAO**:watchPage/count 增 `String? keyword`(summary LIKE '%kw%',%/_ 转义;null=全量);单测(匹配/转义/空串处理/大小写——SQLite LIKE 默认对 ASCII 不敏感,中文精确)。
  2. **对话框**:
     - 分组:已加载行按日历日聚合段头(今天/昨天/前天/yyyy年M月d日;复用 T2 相对时间纯函数族扩展);跨「加载更多」续组;搜索态照分组。
     - 搜索框:标题下输入(图标+清除钮);输入防抖 300ms 触发 DAO 重查(页 offset 重置);副行双态(全量「共 N 条·全部操作均经你确认」↔过滤「n 条匹配「kw」·清除搜索」);空匹配态。
     - 复制:行包 ContextMenuRegion 单项「复制摘要」→Clipboard+AppToast「已复制」。
  3. widget 测:分组段头/跨页续组/搜索双态+防抖/空匹配/右键菜单项+剪贴板内容断言+toast。
- 验证门:`flutter test test/assistant/` 绿/analyze 466 零新增/server diff 空。commit `feat(assistant): F72-T1 审计搜索分组复制`。汇报:文件清单+测试数+v22 对齐差异表+commit hash。
