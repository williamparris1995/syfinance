# Code Ledger — F41 应用内反馈入口

> execute 记账:task/轮次/裁定,流向 review。

## Tasks

- [x] T1 FeedbackLauncher 核心 —— 完成(首轮);fix-1 重构:accountMode 改经 SessionModeTracker(core→core),删 auth_bloc/auth_state/flutter_bloc import,回归 design HLD「依赖零模块」契约
- [x] T2 三入口接线 + 发布链 —— 完成(release.yml dart-define + 三入口 + 测试)

## 评审与修复轮

- **轮 0(两轴评审)**:1 Important + 4 Minor。
  - P-1/S-1 [Important|WRONG/HARD-ish] core/feedback import auth presentation 违 design「依赖零模块」→ **fix-1 修**(SessionModeTracker;顺带修正语义:isGuest=false 覆盖 OfflineAuthenticated,旧写法误标 guest)
  - P-2 [Minor|MISSING] FR-6 缺省态提示零 widget 覆盖 → **fix-1 修**(+2 widget 测逐字断言两条 SnackBar 文案)
  - S-4 [Minor|JUDGEMENT] launch 缝异常未守卫违文件头承诺 → **fix-1 修**(try/catch 视同 false→剪贴板降级 + 1 单测 RED→GREEN)
  - S-2 [Minor|JUDGEMENT] FeedbackEntry 静态可变缝全仓首例 → **裁定不修**(辩护成立:AppShell 由 router 构造堵死构造缝;tearDown 纪律 + 文件头注明 production never overrides;getIt 替代全局性相同)
  - S-3 [Minor|JUDGEMENT] _SidebarFeedbackRow 复制 _NavItemTile 骨架 ~40 行 → **裁定不修**(辩护成立:tile 携带 selected/badge/「敬请期待」语义为 FR-2 所弃;两处演化方向不同)

- **轮 2(e2e 实测回归,用户裁决)**:720p 默认窗口下 `_SidebarFeedbackRow`(~52px 固定区)把「债务管理/债权管理」挤出侧栏视口(ListView 懒构建,e2e tap 0 命中)。
  - **fix-2 修(用户拍板)**:反馈行移入导航 ListView 尾部(`_navGroups` 展开后追加 + AppSpacing.xs 顶距),整行样式/交互/回调不变;固定区零增高,主导航全部回位,1080p+ 全列表可见即常驻。spec FR-2/基线锚点、design HLD/LLD 锚点同步,Grill record 增「侧栏锚点」一行。
  - 宽屏 widget 测试适配:改 `tester.scrollUntilVisible`(真实用户滚动语义,scrollable 显式取侧栏 ListView = 树序首个 Scrollable),并新增 fix-2 验收断言「债务管理 hitTestable 可见」;点击→假 launch 缝被调断言保留。窄屏底栏/设置页入口不受影响。

- **轮 3(review 门 pass,合并前两条一行级 Minor)**:
  - P-F1 [用户可见视觉] 反馈行双重水平内缩(自带 12px + ListView padding 12px → 胶囊左缘 24px,与 tile 左缘 12px 错位)→ **修**:自带水平内缩清零(`fromLTRB(0,4,0,8)`,竖向保留),胶囊与 _NavItemTile 左缘对齐。
  - P-F1b 图标 20px vs _NavItemTile 18px 相邻不一 → **修**:改 18px 同构;design.md LLD「20px」系对 tile 的错误转述,已同步 18px。
  - S-F1 陈旧注释(`_Sidebar.onFeedback` 字段注释仍写 fix-2 前锚点 "row above the user area")→ **修**:改「导航列表尾部」。顺带 feature.md Description 锚点字样同步。定向门:app_shell_test(含 scrollUntilVisible 路径)+ analyze,见门禁记录轮 3 行。

## 门禁记录(控制器复证,fix-2 后终态)

- flutter test 全量:1904(轮 0)→ 1907(fix-1)→ **1907 全绿**(fix-2;移位不加测,数字持平)
- flutter analyze:437 ≤ 439 基线(全程持平,feedback_launcher.dart 零命中)
- make client-e2e:**全套件 exit 0**;app_pages 单套件 +5 全绿(验收点「债务管理」tap 找到 1 widget —— fix-2 主导航回位实证)
- 环境注记:①worktree 初名 r15-f41-in-app-feedback 过长致 MSVC C1083(MAX_PATH),已 `git worktree move` 至短名 r15-f41(照 F39 worktree 命名先例);②fix-2 子代理 shell 通道损坏(bash ENOENT),门禁由控制器代跑复证,数字如上,不采信子代理估计值
- 轮 3 定向门(app_shell_test + analyze):子代理 shell 通道仍损坏(同注记②)**待控制器代跑**——命令:`flutter test test/app/widgets/app_shell_test.dart` + `flutter analyze`(预期:7 绿含 scrollUntilVisible 路径;437 持平)
