# v17 components

> F59 全量扫页。基准页 `ui/f59-flat-compare.html`(模型 C' 终局)+ `ui/f59-form-nav.html`(表单页)。令牌延续 v16;**本版 FloatingActionDock 契约为 C' 修订版(取代 v16 形态 B:次级方圆+菜单已废)**。

## FloatingActionDock(C' · 全平铺三段式)

- **purpose**:详情页右下常驻竖排操作簇,**零菜单零折叠**——主操作一步直达,一切操作可见。
- **structure**:三段全圆钮——`primary` 主操作 52px 金渐变圆(居底)→ `secondary` 高频次级 44px 圆(surface+border,正常亮度)→ 细分隔线 → `muted` 低频/危险 44px 圆(**降饱和淡显**,hover 恢复亮度,危险项置顶离主钮最远);间距 10/右下 28;分隔线仅在 muted 非空时渲染。
- **states**:常驻可用 / 项禁用(onTap=null 半透明降权)/ loading-error 全禁用(恒渲染)。
- **token 对齐**:--fab-bg/--fab-shadow/surface/border;淡显=透明度令牌化(Flutter 侧 DesignTokens 缝)。
- **location**:f59-flat-compare 区块二(满配 6 钮)+ 各页速览;Flutter 实现 design_kit(F59 design ADR-1,F58 版升级)。

## CrumbNav(全路径面包屑 · v17 增表单态)

- **purpose**:顶栏唯一导航面包屑 `section › page › current`;page 级可点回退(经 FormLeaveGate 守卫);**表单态 current=「新增 X」/「编辑 · 实体名」**(v17 新增,表单页无簇,保存/取消在表单底部)。
- **states**:两段(列表)/三段(detail=实体名/表单=新增·编辑态串)/单级(section 空);加载占位「…」。
- **location**:f59-form-nav 区块二;Flutter=app_shell `_BreadCrumb`(F58 版增表单态注入)。
