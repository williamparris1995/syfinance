# Holding UI 重设计(页内 tab + OD 设计)· 设计

- 日期:2026-07-12
- 分支:`holding-asset-management`
- 状态:设计完成,待用户 review → writing-plans
- 相关:[holding-module-nav](./2026-07-11-holding-module-nav-design.md)(二级侧栏,待回退)、[handoff](./2026-07-11-holding-ui-redesign-handoff.md)

## 背景

`holding-module-nav`(二级垂直侧栏 `SubMenuShell`,commit `9256a8f..277f2d7`,final review Ready to merge Yes)用户 `flutter run` 实测后**整体不满意**(形态太重 + 视觉/层级 + IA + 各页)。

用 **Open Design MCP**(`mcp__open-design__*`)重新设计:生成 holding 模块 4 页 desktop 原型(页内 tab 方向)。用户 review preview 后同意 OD 设计方向。

OD 原型(2 个 OD 项目):
- `yucai-holding-ui-redesign-f494`:`holdings-desktop.html`(列表页,39KB)
- `yucai-holding-pages-v2-abe4`:`security-desktop.html`(33KB)/ `performance-desktop.html`(24KB)/ `goals-desktop.html`(22KB)

## 目标

**回退二级侧栏**(`SubMenuShell`),改 **页内 tab**(OD 设计);holding 4 页(列表/Security/收益/goals)**对齐 OD 设计语言**(御财 token 严格)。

## 设计

### §1 导航:页内 tab(替代二级侧栏)

- **删** `core/widgets/sub_menu_shell.dart`(`SubMenuShell`/`SubMenuSidebar`/`SubMenuTab`/`SubMenuItem`,Task 1 产物)
- holding 各页顶部(页面头下)加 **页内 tab**:4 格(持仓列表/Security 管理/收益统计/投资目标),当前页 active = 金下划线 2px `#b08d57`
- 新建 `HoldingModuleTabs` 组件(共享,4 格金下划线,路由感知 active,点击 `context.go`)
- **router branch 5**:去 `ShellRoute(SubMenuShell)`;`/holdings` + 子路由(security/performance/goals/trade/new/:id)独立,各页 builder 渲染页面(页面自带 `HoldingModuleTabs`)。trade/new 是 `/holdings` 子路由(回退到 holding-module-nav 之前的 `/holdings` GoRoute + children 结构;静态在 `:id` 前,路由优先级自然满足)
- 全局侧栏(资产 › 投资组合)+ 顶栏(面包屑 财务 › 持仓管理 + 创建)**不变**
- **响应式**:页内 tab 桌面 ≥1100 + 窄屏 <1100 一致(横向 4 格,窄屏横滚)—— 页内 tab 本就是横向,无需降级

### §2 御财 token(严格,OD :root)

| token | 值 | 用途 |
|---|---|---|
| bg | `#faf9f5` | 米白背景 |
| surface | `#fff` | 卡片 |
| surface-2 | `#f6f4ee` | 表头/次级面 |
| border | `#e6e5e0` | 边框 |
| fg | `#232019` | 暖黑主文字 |
| muted | `#8c8578` | 辅助/label |
| **gold** | `#b08d57` | **accent 点缀**(active tab/主按钮/进度条/超额框,非泛滥) |
| gold-deep | `#94703f` | 金深(hover/强调) |
| gold-soft | `#f3ebdd` | 金软背景 |
| **green** | `#2e7d32` | **盈绿(仅盈亏)** |
| **red** | `#c0392b` | **亏红(仅盈亏)** |
| sidebar | `#1c1e21` | 全局侧栏深色 |

- 衬线 display(Georgia + Noto Serif SC,h1 26px)/ mono tabular-nums(所有数字)
- **盈绿亏红仅落盈亏数字**(年化/bench/目标计数中性化)—— OD agent P0 自检通过
- lucide inline SVG(1.6–1.8px stroke,round cap,**无 emoji**)
- **全站无渐变**(brand mark/进度条/fill 均 solid)

### §3 4 页布局(对齐 OD)

**持仓列表**(`holdings-desktop.html`):
- page-head:h1「持仓列表」+ sub「共 N 只 · 跨 N 账户 · CNY 视图」+ search 230px + refresh icon-btn + 添加持仓 gold btn
- 页内 tabs(持仓列表 active)
- 4 StatCard(总市值/总成本/总盈亏/收益率,gold-soft icon bg + mono value + sub,盈亏色)
- desk-grid:资产配置 donut(300px,conic-gradient + center 合计 + legend)‖ 持仓明细表(8 列 sortable:证券/持有量/成本价/现价/市值↓/走势 sparkline/盈亏/收益率,cell-security 含 type-tag + 账户 flag)
- 多币种汇总条(人民币/美元/合计,金强调合计)

**Security 管理**(`security-desktop.html`):
- page-head:h1「Security 管理」+ sub「N 证券 · 行情源 新浪财经」+ search + refresh + 新建 gold-soft btn
- 页内 tabs(Security 管理 active)
- 筛选 chips(全部/股票/ETF/基金 + count)+ 批量同步
- 证券主表 8 列(symbol+code+type-tag/名称/类型/交易所/币种/现价/上次同步/操作)
- **行内改价**:点现价 → input → 保存✓/取消✕(Enter 保存 / Esc 取消)
- 行情源 chip(A 股/基金=新浪 只读,AAPL=Yahoo)+ 同步时间 HH:mm + 手动刷新(旋转)

**收益统计**(`performance-desktop.html`):
- page-head:h1「收益统计」+ sub「总市值 · 总盈亏 (+%) · 基准 沪深300」+ 区间 segmented(日/月/年)
- 页内 tabs(收益统计 active)
- 4 stat(总市值/总成本/总盈亏 绿/年化 —— 计数中性)
- 总收益曲线 SVG(**组合金实线 + area fill vs 沪深300 灰 dashed** 双线,去 `preserveAspectRatio="none"` 避描边变形,gridline + 末端点 + legend)
- realized/unrealized 分解卡(已实现/未实现/合计)
- bench-mini(我组合 vs 沪深300 中线对比条 + 超额框,年化近似)
- 持仓贡献条(按贡献排序,正绿负红)

**投资目标**(`goals-desktop.html`):
- page-head:h1「投资目标」+ sub「N 目标 · 跨账户总览 · 合计 ¥X」+ 新建目标 gold-soft btn
- 页内 tabs(投资目标 active)
- 4 stat(总数/超目标≥100%/进行中/落后<80%,**计数中性** + 角标 icon 状态色 ✓/⚠)
- 目标卡列表(monogram icon + 名 + status badge + 关联持仓 chips + 预计达成/每月投入 + 当前/目标 mono + **金进度条%**,落后红条/超目标绿条)

## 实现(client,回退 + 新)

1. **删** `core/widgets/sub_menu_shell.dart`(`SubMenuShell` 等)
2. **新建** `HoldingModuleTabs`(holding/presentation/widgets/,4 格金下划线,路由感知)
3. **router branch 5**:去 `ShellRoute(SubMenuShell)`;`/holdings` + 子路由独立(各页 builder 渲染含 `HoldingModuleTabs`);trade/new 仍 branch 级(路由优先级 fix 保留);`:id` 在静态后
4. **4 页对齐 OD**:`holdings_page` / `security_page` / `performance_page` / `goal_link_page` 重做布局 + 御财 token
5. **app_design.dart**:确认/补全御财 token(gold `#b08d57` / green `#2e7d32` / red `#c0392b` / 衬线 / mono tabular-nums);复用现有 + 补缺
6. **goal_link_page 空 holding 逻辑保留**(从 sidebar 进显跨账户全部,2026-07-11 final fix)

## 范围 / Non-goals

- **in-scope**:holding UI 重设计(页内 tab + 4 页 OD)+ 回退 `SubMenuShell`
- **out-of-scope**:
  - **XIRR/TWR server 收益修正**(P0 基础正确性,UI 后单独 spec/plan)
  - 风险调整指标/多维配置/相关性(调研 P1/P2,不做)
  - tablet/mobile 专属端稿(OD 列表页有断点,暂只 desktop + 响应式降级)

## 测试

- 4 页 widget test(布局结构 + tab active + 关键数据渲染)
- `HoldingModuleTabs` test(4 格 + 路由高亮 + 点击 go)
- router test(branch 5 去 ShellRoute 后子路由可达 + trade/new 优先级)
- 全量回归(基线:account_detail 等 3 预存 fail)
- desktop GUI 视觉确认(flutter run,对齐 OD preview)

## 风险 / 待验证

- **回退 SubMenuShell**:删 `sub_menu_shell.dart` + router 去 ShellRoute,确保 holding-module-nav(9256a8f..277f2d7)的改动干净回退(router ShellRoute → 独立路由;3 页 HoldingModuleNav 已删)
- **页内 tab vs M3**:OD 选页内 tab(内容切换,M3 灰区);用户已同意 OD 设计
- **OD 设计转 Flutter**:OD 是 HTML+CSS,Flutter 实现需转(TableCard/Donut/Sparkline 等组件);部分 OD 视觉(donut conic / SVG 曲线)用现有 fl_chart/Painting 还原

## 参考

- OD 原型:open-design 项目 `yucai-holding-ui-redesign-f494`(列表)+ `yucai-holding-pages-v2-abe4`(Security/收益/goals)
- 现有(待回退):[holding-module-nav spec](./2026-07-11-holding-module-nav-design.md) + [plan](../plans/2026-07-11-holding-module-nav.md)
- 调研:holding 功能完整性(deep-research,选 XIRR P0,本 spec out-of-scope)
