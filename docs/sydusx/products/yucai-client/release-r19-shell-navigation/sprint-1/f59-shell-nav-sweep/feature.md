# F59 全量扫页

> /sydusx-portfolio 2026-10-12 分解。R19 sprint-1 次票(串行,依赖 F58 机制与组件)。
> keywords: 面包屑,breadcrumb,导航,扫页,表单页,详情页,categories,订阅管理,返回链接

## Description

F58 范式(顶栏全路径可点面包屑 + 第二层导航退役 + 右下竖排 FAB 悬浮簇)推广到其余全部 shell 内页面:

1. 其余 detail 页:budget / goal / holding / security / transaction detail 等——第二层导航条退役,当前级标题走 F58 注入机制,操作入悬浮簇(按页语义配置)。
2. form 页:debt/receivable/account/budget/goal 等 form 页自带 AppBar 的导航语义收敛(表单页面包屑形态——「page › 新增/编辑」层级与取消语义——spec 拍板)。
3. 特例页:categories 分类管理专属 OD topbar、订阅管理轻条头收敛(全局 _TopBar 统一承载);`_isCategoryManagement` hideTopBar 特例移除。
4. 「‹ 返回 XX 列表」类页面内返回链接退役(面包屑已承担回退)。
5. 全量回归:e2e 套件 + 金图重录 + 窄屏(compact)走查。

## F58 移交(spec 拍板项 + 留档)

- **J-2 择一为范式**:F58 三页 dock 的 loading/error 态口径不一(债务/债权=恒渲染动作全禁用;账户=仅 loaded 渲染)——F59 spec 须钉死其一作扫页范式。
- **A12 存量 FINDING(T6 门上报,非 F58 引入)**:列表页「记一笔/新建债务/新建借出」文本入口缺失(按钮文案仅存在于表单页标题);F59 或后续票处理。
- **走查项(用户验收)**:归档账户页右下金圆禁用态(Opacity 0.45 半透明降权)视觉是否接受——不接受则单点改隐藏。
- 复用件直接可用:FloatingActionDock / DetailTitleSync(TickerMode 守卫)/ FormLeaveGuard;go_router 两契约已入测(push 不改 currentConfiguration;分支回退重建信号=TickerMode)。
- T3 处置注记:holding 实际操作集=买入/卖出/分红/拆分(代码真身,无清仓/删除 handler,muted 组空);spec FR-4 的『清仓/[删除]』按此订正理解。

## Stories

- [ ] S1 FloatingActionDock 分级升级(全圆/分隔线/淡显组)+ 单测(FR-1/2,NFR-1/2)
- [ ] S2 F58 三页回改(C' 重配,菜单退役)(FR-2/3)
- [ ] S3 其余详情页迁移(budget/goal/transaction/holding+扫页清单)(FR-4/7)
- [ ] S4 表单页收敛(三级面包屑+FormLeaveGuard 接线+无簇)(FR-5)
- [ ] S5 categories/订阅管理特例收敛(FR-6)
- [ ] S6 全量回归门(test+analyze+e2e+金图+窄屏走查)(NFR-3)
