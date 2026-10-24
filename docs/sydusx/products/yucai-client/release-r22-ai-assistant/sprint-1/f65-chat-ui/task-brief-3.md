# Task Brief T3 — 浮层宿主与聊天渲染(V1 形态)

- worktree `C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f65`(T1/T2/T4 已合入)。TDD(widget 测);不碰 server/F46;**UI 照 prototype v19**(先读 `docs/sydusx/products/yucai-client/prototype/v19/ui/assistant-entry-variants.html` 的 V1 段与 `assistant-chat-states.html` 全页——消息气泡/状态条/输入行/引导态/动效的视觉事实源)。
- 必读:design.md(ADR-1/HLD AssistantOverlayHost/风险 dock 错位)+spec FR-1 三场景;`packages/design_kit` 与 design-v2 令牌用法;**R19 FloatingActionDock**(`grep FloatingActionDock packages/design_kit`)——错位共存关系:助手 FAB 位于 dock 主 FAB 正上方 56px(令牌间距),两者同屏;T2 的 AssistantPanelBloc 与 PanelMessage。
- 任务:
  1. **`lib/assistant/presentation/widgets/assistant_overlay_host.dart`**:全局宿主 widget(app shell 挂载点——grep 既有 FloatingActionDock 挂载位同层挂);含助手 FAB(sparkle 图标 lucide,金渐变与记一笔区分照 v19)+400px 聊天浮层(右下锚定,卡片+阴影令牌,头部「御财助手 · 本机运行」+关闭+「新对话」;消息流区;输入行+发送);**打开浮层即预热**(EngineManager.ensureReady(),ADR-1/F66 拍板)。
  2. **消息渲染**:`PanelMessage` sealed 分型渲染——UserMsg 右侧气泡;AssistantMsg 左侧气泡(流式光标闪烁动效);ToolStatusMsg 状态条(「正在查询… · 图标」,完成打勾);ErrorMsg 错误条+重试按钮;GuideMsg 引导卡(notEnabled→「去设置」跳转/modelNotReady→下载引导+进度(ModelState 绑定)/engineStarting→**加载动效**(旋转指示+「引擎启动中…」,F66 拍板)。
  3. **流式合帧消费**:bloc 已 30ms 合帧,widget 直接 emit rebuild;输入框发送时禁用发送钮(streaming 态);Enter 发送。
  4. **widget 测**:FAB 点击开合浮层/打开即 ensureReady 被调(fake)/消息各型渲染(含动效态存在性断言——动效用 AnimatedRotation 类可测性照仓内 spinner 测惯例)/发送禁用态/重试按钮回调/新对话清屏/引导三型。
  5. **app shell 挂载**:grep app_shell/主 scaffold,把 host 挂到与 FloatingActionDock 同层的全局位(最小侵入,汇报挂点)。
- 验证门:`flutter test test/assistant/` 绿/`flutter analyze` 零新增(459)/`git diff yucai/server` 空/**v19 对齐自查**(对照原型逐状态核视觉结构,差异列表汇报)。commit `feat(assistant): F65-T3 聊天浮层宿主与渲染(V1)`。汇报:文件清单+测试数+挂点+v19 对齐差异表+commit hash。
