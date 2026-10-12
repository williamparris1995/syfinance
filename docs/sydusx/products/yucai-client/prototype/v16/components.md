# v16 components

> F58 壳层导航统一。基准页 `ui/crumb-nav-variants.html`(OD 拍板形态 B)。令牌延续 v15 `design-system.md`/`tokens.css`(套件 SSOT)。

## FloatingActionDock(形态 B · 竖排悬浮操作簇)

- **purpose**:详情页右下角常驻操作簇——primary 主操作(52px 金渐变圆,`--fab-bg`/`--fab-shadow`)+ secondary 次级钮(44px 方圆,surface+border)自上叠列;不折叠、不随滚动。
- **states**:常驻可用 / 项禁用(onTap=null 降饱和)/ 归档降级(仅「更多」,其余隐藏)。
- **token 对齐**:`--fab-bg`(渐变)·`--fab-shadow`·`--surface`·`--border`;Flutter 侧经 DesignTokens.accentGradient/actionShadow/surface/border 缝注入。
- **location**:区块三「形态 B」演示视口;区块二统一方案内右下锚定。Flutter 实现于 design_kit(F58 design ADR-2)。

## CrumbNav(全路径面包屑)

- **purpose**:顶栏唯一导航面包屑 `section › page › current`;page 级可点回列表(link 色+hover 下划线),section 纯标签,current 加粗不可点。
- **states**:两段(列表页,无 current)/三段(detail,current=注入标题或加载占位「…」)/单级(section 空,仪表盘等既有形态)。
- **token 对齐**:`--muted`/`--fg`/`--link`;紧凑(compact)顶栏同构。
- **location**:区块二「统一方案」;Flutter 实现于 app_shell `_BreadCrumb` 改造(F58 design ADR-4)。
