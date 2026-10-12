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

## Stories

- [ ] S1 其余 detail 页迁移(逐页照 F58 范式)
- [ ] S2 form 页导航收敛(表单态面包屑/取消语义 spec 拍板)
- [ ] S3 categories/订阅管理特例收敛
- [ ] S4 返回链接退役 + 全量回归门(flutter test + analyze + client-e2e + 金图)
