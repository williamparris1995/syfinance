# Task Brief T3 — 确认卡 UI(照 v20 六形态)

- worktree `.claude/worktrees/r22-f70`(T1/T2 已合入,bloc 已有 WriteApprovalMsg 六状态+事件面)。TDD(widget 测);不碰 server/F46/T1/T2 生产逻辑(**豁免**:bloc 若差 Guidance 映射一小段+overlay 渲染分支属本票)。
- 必读:**prototype/CURRENT v20 ui/write-approval-cards.html 全页**(六形态视觉事实源:卡头✎待确认/参数行/删除线旧值高亮新值/红警示 destructive/按钮主位反转/状态徽标 confirmed✓·cancelled·superseded·void·failed/重试幂等小字);T2 的 WriteApprovalMsg{action,preview,status} 数据面;design ADR-7。
- 任务:
  1. **`widgets/write_approval_card.dart`**:三形态渲染——Add=参数逐行(方向/金额千分位两位/账户/分类[推导注记小字]/日期)+「确认记账/取消」;Update=前后对比(旧值删除线 muted+新值高亮)+「确认修改/取消」;Delete=红警示条(⚠ 删除后不可恢复)+摘要行+按钮主位反转(取消为主视觉,negative 色确认删除);五状态徽标(pending 无徽标/confirmed 绿✓/cancelled/superseded 灰角标/void/failed ⚠+「重试」钮+幂等小字「重试不会产生重复记录」);pending 才有按钮区,终态收起。design-v2 令牌零裸色(destructive 走 negative 令牌先例 grep)。
  2. **引导卡(V4)**:bloc 映射——add/update 工具 ToolError 的 unknown-account 型(T1 候选消歧错误带结构标记,grep write_tool_support 的错误文案定标记协议;若 T1 无标记则最小扩 ToolError 携 guideHint 枚举=豁免面)→`GuidanceMsg{text,route}` 新 PanelMessage 型;卡片=澄清文本+「新建账户」按钮(context.go 到 /accounts——T1 查证无独立新建路由,跳账户页)+「换个账户试试」次钮(仅关闭卡)。LLM 文本澄清照常并存。
  3. **overlay 渲染接线**:WriteApprovalMsg/GuidanceMsg 分支渲染;浮层内卡片键盘可聚焦;与打字指示/工具 pill 互不干扰(回归)。
  4. **widget 测**:三形态渲染(参数行/对比/警示逐字)/五状态徽标/确认取消重试按钮回调(真调 bloc 事件)/引导卡跳转(mock navigator 或 route 意图断言)/pending 按钮区终态收起/v20 对齐自查差异表(逐形态)。
- 验证门:`flutter test test/assistant/` 全绿/analyze 零新增(466)/server diff 空。commit `feat(assistant): F70-T3 确认卡与引导卡 UI(照 v20)`。汇报:文件清单+测试数+v20 对齐差异表+commit hash。
