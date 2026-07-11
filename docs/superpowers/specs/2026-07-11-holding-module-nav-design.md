# Holding 模块二级导航整合 · 设计

- 日期:2026-07-11
- 分支:`holding-asset-management`
- 状态:设计完成(brainstorm 完成),待用户 review → writing-plans
- 相关:[holding-late-ui-align](./2026-07-09-holding-late-ui-align-design.md) · memory `ui-align-visual-companion-workflow` / `holding-asset-management-todo`

## 背景

御财 holding 模块有 6 个子界面(持仓列表 / 交易 Sheet / Security 管理 / 持仓详情 / 收益统计 / 投资目标)。全局侧栏只有「资产 › 投资组合」一个入口(branch 5 → 持仓列表),**security / 收益统计 / 投资目标 是孤岛** —— 进了这些页无法在模块内切换。

上个会话的临时方案(`e9a129f` `HoldingModuleNav`):在 holdings/security/performance 三页顶部加横向 tab。**被否两次**(不对齐 OD 垂直左栏),且 goals 页漏接 tab 仍是孤岛。

## 目标

对齐 OD 原型 + 行业最佳实践,给 holding 模块一个**垂直二级模块导航**(桌面),解孤岛;并沉淀一个**可复用的 `SubMenuShell`** 供后续模块按需使用。

## 调研依据(deep-research,核心结论 high-confidence 3-vote 验证)

- **M3(Material Design 3)**:桌面端二级导航**必须垂直** navigation rail/sidebar,**禁止横向 nav bar**;2025-05(M3 Expressive)弃 navigation drawer、推 expanded rail。→ 直接否决横向 tab 方案。
- **NN/g**:local/section navigation(通常左栏)是与全局导航并列的主导航层,面包屑只补充不替代;**兄弟页横向跳转应有独立 nav UI**(非全局单入口)。→ 孤岛页(security/收益/目标)是持仓列表的兄弟页,塞全局单入口是反模式。
- **Apple HIG**:侧栏层级 ≤2 层(御财全局 L1 + 模块 L2 合规);「3-click rule」已被实证证伪。→ 加一层二级导航在深度与点击数上都站得住。
- **推荐**:Apple HIG「sidebar within a tab」(模块内嵌套二级垂直左栏)。

来源:[M3 navigation rail](https://m3.material.io/components/navigation-rail/guidelines) · [NN/g breadcrumbs & local nav](https://www.nngroup.com/articles/breadcrumbs/) · [Apple HIG sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) · [NN/g 3-click rule](https://www.nngroup.com/articles/the-three-click-rule/)

## 设计决策

### §1 形态:方案 B — 模块内嵌套二级垂直左栏

进 `/holdings` 后:`[全局侧栏 240][holding 子侧栏 ~180][内容]`。对应 Apple HIG「sidebar within a tab」—— 全局侧栏的 branch 相当于 tab,模块内二级侧栏相当于 sidebar。

**未选方案 A(全局侧栏内「投资组合」展开子项)**:会让全局侧栏结构不对称(只有 holding 可展开);且其依据(2014 版 M1 expanding drawer)现行 M3 有效性未能验证。

### §2 nav-item 粒度:4 个独立页,两组

| 分组 | nav-item | 路由 |
|---|---|---|
| 持仓管理 | 持仓列表 | `/holdings` |
| 持仓管理 | Security 管理 | `/holdings/security` |
| 统计 & 目标 | 收益统计 | `/holdings/performance` |
| 统计 & 目标 | 投资目标 | `/holdings/goals` |

**不含**「交易 Sheet」(操作型 bottom sheet,需从列表/详情触发,无上下文)和「持仓详情」(`/holdings/:id` 需具体 id)—— 这两项是 OD 原型的设计瑕疵(非独立可达页),侧栏只放可独立直达的页面。详情 `/holdings/:id` 在 shell 内容区内渲染,侧栏高亮「持仓列表」(详情从属列表)。

### §3 视觉:方案 A 统一深色

- 两级侧栏同深色系:全局 `#26262a` / 子侧栏 `#2c2c31`(略浅,同系区分),内容区浅色突出
- 子侧栏宽 180;两组 label(uppercase 小字);高亮 = left-border accent `#b08d57` + 选中底色(复用全局 `_NavItemTile` 视觉模式)
- 对齐 OD 深色侧栏 + VS Code/Slack 两级深色惯例

### §4 响应式

- **≥1100 桌面**:全局侧栏(240) + `SubMenuSidebar`(180,垂直) + 内容
- **<1100 平板/手机**:全局底栏 + `SubMenuTab`(横向 4 项,横滚) + 内容。无二级侧栏(窄屏左栏占空间太多)
- **不与「否掉横向 tab」冲突**:否的是**桌面**横向(M3 禁);mobile 横向 tab 是标准降级,M3 允许
- 底栏保持现状(7 目的地略挤是已知问题,属另一优化,本次不动)

## 组件设计(通用化)

三个通用组件放 `core/widgets/`,**items 配置驱动**,holding 模块只定义并传入自己的 items(后续模块按需复用,不为预设模块实现)。

### `SubMenuShell`(branch 内 ShellRoute builder)

- 参数:`{required List<SubMenuItem> items, required Widget child}`
- `LayoutBuilder` 切换形态:
  - `≥1100`:`Row[SubMenuSidebar(items), Expanded(child)]`
  - `<1100`:`Column[SubMenuTab(items), Expanded(child)]`
- `child` = 当前匹配子路由的 outlet(由 GoRouter ShellRoute 注入)

### `SubMenuSidebar`(垂直,桌面)

- items 驱动;按 `group` 字段分组渲染(两组 label);路由感知高亮(当前 `matchedLocation` 命中 item.route);点击 `context.go(route)`
- 视觉照 §3(深色 + left-border accent + 选中底色)

### `SubMenuTab`(横向,窄屏降级)

- items 驱动;扁平渲染(不分组,横向 scrollable);路由感知高亮;点击 `context.go(route)`
- 替代现有 `HoldingModuleNav`

### `SubMenuItem` 数据类

```
label / icon(LucideIcons) / route / group(可选,用于侧栏分组)
```

## 接入与回退改造

1. **新建** `core/widgets/sub_menu_shell.dart` + `sub_menu_sidebar.dart` + `sub_menu_tab.dart`(含 `SubMenuItem`)
2. **holding 模块定义** nav items:持仓管理[列表 `trendingUp`/Security `layers`] + 统计&目标[收益 `percent`/目标 `target`]
3. **router branch 5** 改造:
   - 用 `ShellRoute` 包 holding 子路由,builder = `SubMenuShell(items: holdingItems, child: child)`
   - ShellRoute routes:`/holdings`、`/holdings/security`、`/holdings/performance`、`/holdings/goals`、`/holdings/:id`(详情,高亮列表)
   - `trade` / `new` 移出 shell,保持 `context.push` modal(操作型 sheet,不占侧栏)
   - 静态路由仍在 `:id` 前(路径优先级)
4. **删** `holding/presentation/widgets/holding_module_nav.dart`(`HoldingModuleNav`,逻辑进通用 `SubMenuTab`)
5. **3 页去顶部 tab**:`holdings_page.dart:60` / `security_page.dart:117` / `performance_page.dart:135` 去掉 `const HoldingModuleNav()`(nav 统一由 shell 提供)
6. **goals 页**:本无 nav → shell 统一提供,**孤岛彻底解决**(列表/Security/收益/目标 4 页都在侧栏可达)

## 测试

- `SubMenuShell`:LayoutBuilder 宽屏渲染 `SubMenuSidebar` / 窄屏渲染 `SubMenuTab`
- `SubMenuSidebar`:items 渲染 + 两组 label + 点击 `context.go` + 当前路由高亮
- `SubMenuTab`:items 渲染(扁平)+ 补 goals 断言
- router:branch 5 ShellRoute 子路由可达 + goals 不再孤岛 + trade/new 仍可 push
- 现有页 test:去掉对 `HoldingModuleNav` 的旧断言(nav 已移 shell);goals 页加 nav 可见断言
- 全量回归(基线:`account_detail_page_test` 等 3 预存 fail,非本次引入)

## 范围 / Non-goals

- **in-scope**:holding 模块二级导航(桌面垂直 + 窄屏横向 tab)、解孤岛、通用 `SubMenuShell`/`Sidebar`/`Tab`(items 驱动)
- **out-of-scope**:
  - 列表页「类型筛选侧栏」(OD 列表页特有)—— 御财 `_ChipsRow` 已覆盖类型筛选(chips 形态);OD 多出的「账户筛选」属另一 feature
  - 底栏 7 目的地拥挤优化
  - 其他模块接入 `SubMenuShell`(本次只建通用件 + holding 接入,其余按需)

## 风险 / 待验证

- **GoRouter 嵌套**:`StatefulShellBranch.routes` 内嵌套 `ShellRoute` 的具体语法,plan 阶段验证(标准用法,预期可行;若不可行则用等效的 branch 内常驻 shell widget + 子路由 outlet)
- **泛化程度**:本次只 holding 接入;`SubMenuItem` 设计保持最小(label/icon/route/group),不为假想模块加字段(YAGNI)
- **桌面横向空间**:全局 240 + 子侧栏 180 = 420,内容区在 ≥1100 屏剩 ≥680,可接受;<1100 切横向 tab 规避

## 参考文件

- 调研:deep-research 报告(M3 / NN/g / Apple HIG)
- OD 原型(模块导航侧栏):`design-output/holding/{security,performance,goal-link,holding-detail}-desktop.html`
- 现状:`app/widgets/app_shell.dart`(`_Sidebar` / `_NavItemTile` 视觉模式)、`app/router.dart`(branch 5,520-701)、`holding/presentation/widgets/holding_module_nav.dart`(tab patch,待删)
