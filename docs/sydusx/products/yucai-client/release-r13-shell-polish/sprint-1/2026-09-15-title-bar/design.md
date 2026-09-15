# Design — F29 自定义标题栏

**prototype: none**(唯一新 UI = 单行标题栏:brand-mark 徽标=prototype `.brand-mark` 既有形制(侧栏在用),三窗口钮=行业标准字形,零新视觉词汇;视觉参数照 design-v2 令牌)

## Context

[spec.md](spec.md) 双 A 拍板。现状:main.dart `windowManager.ensureInitialized()` + tray_controller `setPreventClose(true)`;app_shell 桌面=侧栏+`_TopBar`,窄屏=底导;F22 关闭决策树在 TrayController.onWindowClose。

## Decisions(ADR)

### ADR-1 TitleBarStyle.hidden(非 frameless)
- waitUntilReadyToShow(WindowOptions(titleBarStyle: hidden));原生边框/Snap/缩放全保留。备选 setAsFrameless 裁掉(丢 Snap)。
- 注意:启动序在 main,`hide()`(F22 隐藏到托盘)与 hidden 标题栏无冲突。

### ADR-2 经典双层,TitleBar 置 _TopBar 之上
- 新 `core/widgets/app_title_bar.dart`(位置:core 共享件,app_shell 与登录前窗口均可用);app_shell 桌面列 `[_AppTitleBar, _TopBar, ...]`,窄屏 AppBar 上方同款(guest 登录页由 app 根包?——实现取舍:**统一挂 app_shell 外层**与登录页共用的根容器,避免两处;若登录前窗口无 shell,则挂 MaterialApp builder 层最稳,实现时按此优先)。
- 高 38;徽标 34(圆角 11,金渐变 brand 口径,F23 图标同源「御」);「御财」13/w600。

### ADR-3 三钮 = channel 调用,零状态本地化
- minimize/maximize(toggle)/close 全走 windowManager;最大化图标态由 WindowListener.onWindowEvent(maximize/unmaximize) 驱动 ValueNotifier;关闭钮 close() → 既有 onWindowClose(F22 决策树原样)。
- 拖拽=GestureDetector onPanStart→startDragging()(window_manager DragToMoveArea 亦可,取包内建);双击=onDoubleTap→toggle maximize。

### ADR-4 交互色
- 钮 40×38 hover:fg@6% 派生(仓内 hover 先例);关闭钮 hover:negative@10%(F25 数据头 soft 同口径);按下 fg@12%。图标 muted→hover fg。

## HLD

```
lib/core/widgets/app_title_bar.dart   AppTitleBar(徽标/三钮/拖拽/双击/maximize 态)
lib/app/widgets/app_shell.dart        桌面列与窄屏 AppBar 上方接入(builder 层或 shell 顶部,LLD 定)
lib/main.dart                         WindowOptions(titleBarStyle: hidden)
test/core/widgets/app_title_bar_test.dart  渲染/三钮 channel mock/maximize 图标切换/双击/主题探针
```

## LLD

- channel mock 范式:照 tray_controller_test 的 window_manager channel mock(`minimize`/`maximize`/`unmaximize`/`close`/`startDragging`/`isMaximized` 记录断言;is* 返 false 需适配)。
- close 断言:close 钮点击 → channel 收 `close`(决策树归 F22 既有测试,此处只验调用)。
- 双主题探针:暗/亮下标题栏底色=侧栏 bg 令牌、关闭钮 hover resolve=negative 派生。

## Risks

| 风险 | 缓解 |
|---|---|
| hidden 模式登录前窗口(无 shell)漏挂 | builder 层统一挂(ADR-2 优先) |
| startDragging 触摸板双击误触 | 双击阈值系统级;真机走查 |
| 窄屏(移动断点)标题栏与 AppBar 视觉重复 | 标题栏高度 38 保持轻,真机走查 |

## Migration

系统标题栏消失=行为变更,release note 注明(自定义栏即时可用)。

## Open Questions

- 帮助/设置入口是否上标题栏(右键菜单 backlog 在案,不做)。
