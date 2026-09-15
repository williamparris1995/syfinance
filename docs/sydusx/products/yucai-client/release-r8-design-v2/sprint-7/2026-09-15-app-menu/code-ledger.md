# Code Ledger — F22

| task | 状态 | fix-rounds | 裁决/备注 |
|---|---|---|---|
| T1 TraySettings+AppExitPort | done (TDD) | 0 | brief: task-brief-1.md;DI 走 build_runner 路径(@LazySingleton + regen 成功,未回退手工注册);TrayAppExit 留给 T4 bootstrap 手工注册(onExit=stop 不在图内) |
| T2 设置页 UI | done+reviewed | 0 | 评审:0 HARD/0 MISSING;3 LOW JUDGEMENT 可辩护(死缝/段块同形) |
| T3 首关对话框 | done+reviewed+fix1 | 1 | 修复:scrim 恒定暗/autofocus 实证后加上(Esc 不被吞,框架 DismissIntent 冒泡)/hover 两钮;16/16 绿 |
| T4 控制器收口 | done+reviewed+fix1(后台) | 1 | 评审:0 HARD/0 WRONG;修 watch onError[MEDIUM]/stop 复位 trayReady/quit 守卫;ADR-4 偏差已回写 design |
| T5 全量门 | 进行中 | - | NFR-2 幂等回归账归此 |

## T5 spec↔测试对账(2026-09-15)

| spec 项 | 测试证据 |
|---|---|
| FR-1 退出按钮即时退出 | settings_page_test(点击 exitApp 恰1次+无 AlertDialog)+ app_exit_port_test(await 语义/try-finally 哨兵) |
| FR-2 关闭行为设置 | tray_settings_test(默认/往返)+ settings_page_test(初值 hide+setCloseBehavior verify)+ tray_controller_test 分支②(stop+exit 不 hide) |
| FR-3 首关对话框 | first_close_dialog_test(三态+Esc+×+文案+恒定 scrim+autofocus/Enter+hover 16 用例)+ tray_controller_test 分支④(minimize/quit/null+标记恰一次+重入守卫+无 context 兜底 hide) |
| FR-4 变更即扫 | tray_controller_test(watch 3事件→1扫合流/防抖重置/流错吞+周期兜底/stop 撤订阅) |
| FR-5 可配间隔 | tray_settings_test(15/30/60+默认 30)+ tray_controller_test(60→15 重臂+启动+10s 首扫保留) |
| FR-6 托盘撤项 | tray_controller_test(buildContextMenu 仅 show/quit) |
| NFR-1 fail-safe | tray_controller_test 分支①(!trayReady→exit 不 hide)+ stop 复位 trayReady |
| NFR-2 幂等重入 | due_scanner_test:88 既有「重复调用第二次 0 条」+ 防抖合流用例 |
| NFR-3 零回归 | 全量 1643/1643 绿 + analyze 431=基线 + make client-e2e 全过 |

门证据(T5):flutter analyze 431(=基线,新文件 0)/ flutter test +1643 All passed / make client-e2e all suites passed。

## 整体 review 门(2026-09-15):**pass**
advisory(不阻断,流向后续):①TrayController.quit() 缺 try/finally(stop 抛错不 exit;AppExitPort 路径已有——fail-safe 姿态不一致,F25/polish 轮统一);②negativeSoft 令牌缺失(退出钮 8%/16% vs 原型 10% 派生已注释,记令牌债务);③code-plan T4 watch 测试措辞与实现口径小偏差(注入流 vs 真表)。
