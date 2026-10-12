# F58 壳层导航地基+范式迁移

> /sydusx-portfolio 2026-10-12 分解。R19 sprint-1 首票(串行,F59 依赖本票)。依据:OD 视觉伴侣 crumb-nav-variants(用户 2026-10-12 拍板形态 B)。
> keywords: 面包屑,breadcrumb,导航,顶栏,AppShell,shell,FAB,悬浮簇,navigation,crumb

## Description

现状:AppShell 顶栏 `_BreadCrumb` 纯文本不可点(`app_shell.dart`);债务/债权详情页自带 AppBar 面包屑(「债务管理 › X」+ 右侧编辑/更多,`debt_detail_page.dart`/`receivable_detail_page.dart`),账户详情 BackButton+标题+编辑/记一笔/转账/更多四钮(`account_detail_page.dart`)——两层面包屑叠加、回退路径割裂、纵向空间双倍占用。套件先例:design-output-v2/ab/account-detail.html crumb 三级(page 级 `<a>` 可点、当前级加粗)+ 每页右下 `.fab` 金圆。

本票立壳层机制+组件,迁移三个代表页作范式(F59 照扫):

1. 顶栏面包屑可点化:page 级祖先 → 列表 root 回退;section 纯标签;当前级加粗不可点。
2. detail 当前级标题注入:shell 顶栏显示 detail 页当前级(债务 counterparty / 账户名),机制 ADR 拍板(ValueNotifier port / route extra / bloc 通道)。
3. 全局竖排 FAB 悬浮簇:主 FAB「记一笔」52px 金圆 + 其上次级钮 44px(surface+border),按页配置操作集;右下常驻不折叠;页面底部留白 ≥242px 防遮挡;窄屏形态 spec 拍板。
4. 范式迁移:债务/债权/账户三详情页自带 AppBar 导航语义退役(操作入悬浮簇);`_isReceivableDetail` hideTopBar 特例移除。
5. 回归:三页 widget/e2e + 相关金图重录。

## Stories

- [ ] S1 顶栏面包屑可点化(page 级导航动作 + 当前级注入消费)
- [ ] S2 detail 标题注入机制(ADR 拍板通道形态)
- [ ] S3 竖排 FAB 悬浮簇组件(design_kit 归属评估 + 按页配置 API)
- [ ] S4 三页范式迁移 + hideTopBar 特例收敛
- [ ] S5 回归门(flutter test + analyze + client-e2e)
