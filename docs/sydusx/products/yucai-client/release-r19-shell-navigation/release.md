# Release R19 — 壳层导航统一(shell-navigation)

> /sydusx-portfolio 2026-10-12 立项。product checkpoint:重读 [vision.md](../vision.md),Product Goal(可分发的商业级个人专业理财客户端、19 模块行业级 UI 交互/操作效率)ongoing;导航统一直接服务「操作效率达行业 4-5 分」路径。
> 起因:用户 2026-10-12 实测反馈——顶部面包屑不可点回退、详情页两层面包屑叠加;OD 视觉伴侣(项目 crumb-nav-variants)现状还原/统一方案/悬浮簇两形态对比后拍板形态 B。

## Release Goal

导航心智从「双层割裂」变「单层全路径 + 就近操作」:面包屑统一为顶栏全路径(section › page › 当前级),page 级祖先可点回退(对齐套件 account-detail.html crumb 先例:中间级 `<a>` 可点、section 纯标签、当前级加粗);详情/表单页第二层导航条(AppBar 面包屑 / BackButton 标题条 / categories·订阅管理专属 topbar)全部退役,内容上移;页面级操作(编辑/记一笔/转账/更多)收敛为右下角常驻竖排 FAB 悬浮簇。

## Decisions(用户拍板 2026-10-12,OD crumb-nav-variants)

- **悬浮簇 = 形态 B 竖排 FAB 堆叠**:主 FAB「记一笔」52px 金圆(套件 .fab/--fab-bg/--fab-shadow 语言)+ 其上次级 编辑/转账/更多 44px(surface+border);**常驻不折叠**;底部留白 padding ≥ 242px 防遮挡(OD 对比表 B 列口径)。横排胶囊(形态 A)留参考不实施。
- **面包屑层级**:顶栏单层全路径;**page 级做链接**回列表 root,**section 级纯标签**(套件先例:仅中间级可点);当前级加粗不可点。
- **波及面 = 全部 shell 内页面**(用户确认「其他页面也需要修改」):不止债务/账户两演示场景,全部 detail/form 页 + categories/订阅管理特例页统一收敛。
- **两票串行**:F58 地基+范式迁移 → F59 全量扫页(F59 依赖 F58 机制与组件)。
- **编号 = R19**:R18 已被 yucai-server agent-ready 立项占用,顺延。

## Sprint roster

- [ ] [sprint-1](sprint-1/sprint.md) — F58 壳层导航地基+范式迁移 / F59 全量扫页(串行)

## Done criteria

1. 所有 shell 内页面顶栏面包屑 = 全路径且 page 级可点回退;detail 当前级标题由页面注入(shell 不猜,机制 ADR 拍板)。
2. 第二层导航条零残留:detail/form 页自带 AppBar 导航语义、categories/订阅管理专属 topbar、account-detail「‹ 返回账户列表」类链接全部退役;`_isReceivableDetail`/`_isCategoryManagement` hideTopBar 特例收敛。
3. 右下角常驻竖排 FAB 簇按页面语义配置操作集;底部留白防遮挡(≥242px)。
4. 窄屏(compact/mobile)布局语义不回归(与底栏导航/既有 .fab 共存形态 spec 拍板)。
5. 全门:flutter test 全绿 + analyze 基线 + `make client-e2e`(零 proto 改动免 go 门)。

## status: pending
