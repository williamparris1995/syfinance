# Sprint 7 — R8 应用菜单 + 品牌图标

> `/sydusx-portfolio`(2026-09-15)。来源:brainstorm 四项用户拍板(顶栏应用菜单/字符标「御」/关闭行为设置化+首次提示/归属 sprint-7)——缺口:托盘菜单 3 项(显示/立即检查/退出)是这些功能的**唯一**入口,Windows 11 托盘默认折叠进 overflow,托盘失败(trayReady=false)时「立即检查」彻底不可达;exe 图标仍为 Flutter 模板默认,design-v2 品牌视觉未落地系统层。

## Sprint Goal

托盘功能的应用内平价入口 + 品牌视觉落地:顶栏应用菜单承载 显示/立即检查/设置/退出(托盘失效=唯一入口,托盘正常=完整入口——对齐 Microsoft Win32 通知区指南的「双 surface」共识),关闭到托盘行为设置化+首次一次性提示(对齐「尊重 X 按钮」业界共识);字符标「御」多尺寸图标替换 exe/任务栏/托盘全套。

## Feature roster

- [ ] **feature F22** app-menu — 顶栏应用菜单(_TopBar 最右 MenuAnchor 复用 F5 yucaiMenuStyle:显示御财/立即检查(提醒/记账)/设置…/退出御财;TrayController scan/stop 提为可注入)+ 关闭行为设置化(设置页「关闭按钮:隐藏到托盘[默认]/退出程序」+ 首次隐藏一次性提示「已最小化到托盘」) **[claimed: zcode 2026-09-15]**
- [ ] **feature F23** app-icon — 字符标「御」图标全套(墨底 #0B0E13 圆角方块 + 鎏金渐变 #E8C07A→#C9964A「御」;SVG 1024 源 → 多尺寸 ICO 16/24/32/48/64/256 替换 windows/runner/resources/app_icon.ico;托盘 assets/tray_icon.ico 单独 16/24 简化形;不用 flutter_launcher_icons——Windows 端只生成单尺寸 ICO,issue #573)

## defer

- 自定义窗口标题栏(仍是系统默认;后续 shell 打磨线候选)
- 托盘菜单与应用菜单的条目同步策略(两处入口本期各自维护,条目少不构成漂移风险;条目增多时再抽单一事实源)
- i18n(菜单/提示文案随项目阶段二统一)

## status: pending
