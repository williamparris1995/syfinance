# Sprint 7 — R8 应用菜单 + 品牌图标 + 托盘数据头

> `/sydusx-portfolio`(2026-09-15)。来源:brainstorm 四项用户拍板(顶栏应用菜单/字符标「御」/关闭行为设置化+首次提示/归属 sprint-7)+ grill 中两轮扩展(D3 连带:变更即扫+可配扫描间隔、撤「立即检查」;拆分 F24 更新/F25 托盘数据头)——缺口:托盘菜单 3 项(显示/立即检查/退出)是这些功能的**唯一**入口,Windows 11 托盘默认折叠进 overflow,托盘失败(trayReady=false)时无入口;exe 图标仍为 Flutter 模板默认,design-v2 品牌视觉未落地系统层。

## Sprint Goal

托盘功能的应用内平价入口 + 扫描调度治本 + 品牌视觉落地:顶栏应用菜单(设置/退出,MenuAnchor 复用 F5 yucaiMenuStyle)+ 关闭行为设置化+首提示;到期扫描从「跨日门槛+手动逃生口」升级为「变更即扫 + 用户可配间隔周期扫」(对齐 Microsoft Win32 通知区指南双 surface 共识与提醒类应用事件驱动最佳实践);字符标「御」多尺寸图标替换 exe/任务栏/托盘全套;托盘菜单数据头+快捷操作(骑 F22 地基)。

## Feature roster

- [ ] **feature F22** app-menu — 顶栏应用菜单(设置…/退出御财;MenuAnchor 复用 F5 yucaiMenuStyle;TrayController 提为可注入)+ 关闭行为设置化(设置页「关闭按钮:隐藏到托盘[默认]/退出程序」+ 首次隐藏一次性对话框[最小化/退出二选一,Esc=取消关闭不消耗标记])+ **扫描调度治本**(债务/债权期次写入→防抖触发扫描[变更即扫];30 分钟跨日门槛 → 用户可配间隔周期扫描[默认 30 分钟,无条件重扫,幂等安全];应用菜单与托盘菜单均撤「立即检查」) **[claimed: zcode 2026-09-15]**
- [ ] **feature F23** app-icon — 字符标「御」图标全套(墨底 #0B0E13 圆角方块 + 鎏金渐变 #E8C07A→#C9964A「御」;SVG 1024 源 → 多尺寸 ICO 16/24/32/48/64/256 替换 windows/runner/resources/app_icon.ico;托盘 assets/tray_icon.ico 单独 16/24 简化形;不用 flutter_launcher_icons——Windows 端只生成单尺寸 ICO,issue #573)
- [ ] **feature F25** tray-info — 托盘数据头+快捷操作(菜单顶部动态禁用项:今日收支/本月结余,复用 dashboard 聚合口径;「记一笔」=显示窗口+跳记账表单;设置页「托盘显示金额」隐私开关。**前置:F22 注入化地基,排其后实施**)

## defer

- 自定义窗口标题栏(仍是系统默认;后续 shell 打磨线候选)
- 托盘菜单与应用菜单的条目同步策略(两处入口本期各自维护,条目少不构成漂移风险;条目增多时再抽单一事实源)
- i18n(菜单/提示文案随项目阶段二统一)
- **F24 自动更新(立项候选,建议独立排期)**:auto_updater(Sparkle/WinSparkle)+ GitHub Releases + appcast.xml + GitHub Actions 发布流水线 + EdDSA 签名校验(理财 app 防投毒)+ 托盘/应用菜单「版本号、检查更新」项——跨客户端/CI/发布/安全三面,体量配独立 feature,不夹生进本 sprint。

## status: pending

