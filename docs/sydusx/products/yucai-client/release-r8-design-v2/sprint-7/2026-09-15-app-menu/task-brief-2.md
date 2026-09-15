# Task Brief T2 — 设置页「窗口与提醒」区 + 底部退出按钮

> F22 code-plan Task2。TDD;controller 不改你的产物;评审独立。依赖 T1(已合:TraySettings/AppExitPort 在 lib/core/notifications/)。

## 环境

- worktree:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r8-f22`(分支 feature/r8-f22;勿切分支勿 commit)
- 客户端 `yucai/client/`;测试 `flutter test test/...`;分析 `flutter analyze`。注释中文。

## 上下文(先读)

- 视觉契约:docs/sydusx/products/yucai-client/prototype/v1/ui/settings-window-reminders.html(区结构/两行 SegmentedButton/hint 文案/底部按钮样式)+ components.md 的 setting-row-seg 与 btn-exit-footer 规格。
- 实装范式:lib/settings/presentation/settings_page.dart 既有分区(「外观·主题模式」的 SegmentedButton 行 = 你的直接模板);语义色一律 context.yucai(YucaiTheme extension,先读 lib/core/theme/app_design.dart 确认可用字段——negative 系若缺 soft 变体,用 negative 令牌 + Opacity 表达并在注释说明,禁裸 hex)。
- T1 产物:lib/core/notifications/tray_settings.dart(TraySettings)、app_exit_port.dart(AppExitPort)。

## 交付

1. settings_page.dart 新增「窗口与提醒」card(置于「数据」区之后):
   - 行 1「关闭按钮行为」hint「点窗口 ✕ 时:隐藏到托盘继续运行,或直接退出」;SegmentedButton<TrayCloseBehavior> 两段(隐藏到托擎/退出程序——文案照原型),初值+切换→TraySettings.setCloseBehavior。
   - 行 2「提醒检查频率」hint「到期提醒与自动记账的定时扫描间隔;数据变更时总会即时检查」;SegmentedButton<TrayScanInterval> 三段(15/30/60 分钟),→setScanInterval。
   - 值经 getIt<TraySettings>(照页面既有 ThemeSettings 消费方式);setX 异步 fire-and-forget 可接受(listenable 已广播)。
2. 页面**最底**(所有 card 之后、页面 padding 内)「退出御财」按钮:全宽高 40、圆角 12、negSoft 底+neg 描边+neg 文字、hover 加深;含退出图标(lucide_icons_flutter,仓内已有依赖,log-out 图标);点击→`getIt<AppExitPort>().exitApp()` **即时无确认**。AppExitPort 生产注册在 T4——页面 resolve 用 getIt 直取(测试注册 fake;若既有测试 harness 无 DI 图会炸,按 app_shell 的 isRegistered 守卫先例处理并注释)。
3. 测试:settings_page_test 增(或新文件,若既有文件过大照仓内拆分习惯):区标题存在/两 SegmentedButton 初值(默认 hide+30)与切换调用对应 setX(verify)/退出按钮存在且点击触发 fake AppExitPort.exitApp/文案 hint 断言。测试 harness 需注册 TraySettings fake(照 ThemeSettings fake 范式)+ AppExitPort fake。

## 禁区

- 不改 tray_controller/notifications_bootstrap(T4);不改 YucaiTheme 令牌定义;禁裸色值。

## 完成门

flutter analyze 新文件无新增 issue;新增测试全绿;全量 flutter test 无回归(基线 1606 绿)。报告:文件清单/测试数/DI 消费方式/偏差。
