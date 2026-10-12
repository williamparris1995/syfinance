# F58 code-plan

> 依据 spec.md(FR-1..7)+ design.md(ADR-1..4)。worktree r19-f58。全任务 TDD(先红后绿);每任务后 typecheck+单文件测;结尾全量门。

## Tasks

- [x] **T1 design_kit:DesignTokens 增补 + FloatingActionDock 原语**
  文件:`packages/design_kit/lib/src/design_tokens.dart`(增 `accentGradient List<Color>`/`actionShadow List<BoxShadow>`,带缺省回落)、新 `floating_action_dock.dart`(DockAction/FloatingActionDock,design.md LLD 契约)、`design_kit.dart` 导出、包测试(dock 渲染/禁用态/缺省回落)。
  接口:produce `FloatingActionDock`/`DockAction`;consume DesignTokens 缝。

- [x] **T2 core 两 port:ShellDetailTitle + FormLeaveGate/FormLeaveGuard**
  文件:client `lib/core/`(新 shell_detail_title.dart / form_leave_gate.dart;getIt lazySingleton 注册 injection.dart)、`FormLeaveGuard` widget(PopScope+veto 注册+确认 dialog)。
  测试:标题 set/clear/监听;gate 注册问询 true/false;Guard 脏拦/净放(dialog 交互测)。

- [x] **T3 app_shell 顶栏改造 + 主题注入 + 特例收敛**
  文件:`lib/app/widgets/app_shell.dart`(_BreadCrumb 三段渲染/page 级 onTap 经 FormLeaveGate → context.go(rootPath)/_TopBar 消费 ShellDetailTitle + location-diff 清零/`_isReceivableDetail` 移除)、client 主题构造点注入 accentGradient/actionShadow(对应套件 --fab-bg/--fab-shadow 双主题值)。
  测试:三段渲染/两段/单级;page 级 tap 导航;location 变化清标题。依赖 T1+T2。

- [x] **T4 债务+债权详情迁移**
  文件:`lib/debt/presentation/pages/debt_detail_page.dart`/`receivable_detail_page.dart`(AppBar 整条退役;Scaffold body Stack + FloatingActionDock 挂载;滚动容器 bottom padding ≥242;操作映射=立即记账|收款 primary + 编辑/更多 secondary;标题注入 set/clear)。
  测试:页面无第二层导航条;dock 操作可达/行为;标题注入。依赖 T1-T3。

- [x] **T5 账户详情迁移**
  文件:`lib/account/presentation/pages/account_detail_page.dart`(AppBar 退役;记一笔 primary + 编辑/转账(还款/充值) + 更多(复制/关闭|重新激活/删除);归档降级=仅更多;标题注入=账户名)。
  测试:活跃/归档两态 dock 操作集;标题注入。依赖 T1-T3,与 T4 并行。

- [x] **T6 收尾:守卫 harness 钉死 + 金图重录 + 全量门**
  文件:harness 表单页测试(FR-7 脏拦/净放经面包屑路径);波及金图重录;`flutter test` 全绿 + `flutter analyze` 基线 + `make client-e2e`。
  依赖 T1-T5。

## 并行编排

T1 ∥ T2(独立)→ T3 → T4 ∥ T5 → T6。
