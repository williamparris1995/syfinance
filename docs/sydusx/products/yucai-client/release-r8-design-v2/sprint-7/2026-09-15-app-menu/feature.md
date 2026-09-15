# Feature — F22 顶栏应用菜单 + 关闭行为设置化(R8 sprint-7)

> 2026-09-15 brainstorm 拍板(方案 A + 关闭行为「设置化+首次提示」)。

## Description

缺口:托盘菜单 3 项(显示御财/立即检查/退出)是这些功能的唯一入口——侧栏底部「登出」是账号登出(LogoutRequested)≠ 退出进程,唯一退出路径是 X→隐藏到托盘→右键托盘→退出(三步);Windows 11 托盘默认折叠进 overflow 可发现性差;托盘失败(trayReady=false)时「立即检查」彻底不可达;关闭行为强制隐藏、无设置无提示(业界共识:close-to-tray 应设置化或首次提示)。

方案:_TopBar 最右新增应用菜单钮(MenuAnchor + 复用 R8-F5 yucaiMenuStyle/菜单资产),菜单项:显示御财 / 立即检查(提醒/记账) / 设置… / 退出御财。托盘在=完整入口,托盘失=唯一入口。菜单动作需接入 TrayController 的 scan/quit(当前在 notifications_bootstrap 构造,提为可注入——getIt 注册或等价 port)。配套:设置页「关闭按钮行为」(隐藏到托盘[默认,保持现状]/退出程序,持久化镜像 ThemeSettings 模式)+ 首次隐藏时一次性提示「已最小化到托盘」(本地标记持久化)。

依据:Microsoft Win32 UX 通知区指南(应用内必须提供显式退出;close-to-tray 用户可选)+ Electron/Wails 托盘指南(双 surface:应用内=完整功能,托盘=快捷动作+退出)。

## Stories

- [ ] S1: TrayController 可注入化(菜单/关闭行为共用 scan/stop/退出路径;getIt 注册,保持现有容错语义不变)
- [ ] S2: _TopBar 应用菜单钮 + 4 菜单项(显示/立即检查/设置/退出;yucaiMenuStyle;窄屏 compact 顶栏同样保留;设置项路由到现有设置页)
- [ ] S3: 设置页「关闭按钮行为」(隐藏到托盘[默认]/退出程序;持久化;onWindowClose 按设置分支——退出程序走 TrayController.stop + exit 复用托盘退出路径)
- [ ] S4: 首次关闭一次性提示(行为=隐藏且 trayReady 时弹「已最小化到托盘」提示,本地标记,仅首次;托盘失败态不提示直接退出)
- [ ] S5: 测试(菜单各项触发/设置持久化与分支/首提示一次性/托盘失败态;全量门 flutter test + analyze)

## Keywords

`应用菜单` `menu-bar` `顶栏菜单` `托盘` `tray` `关闭行为` `close-to-tray` `退出入口` `立即检查`
