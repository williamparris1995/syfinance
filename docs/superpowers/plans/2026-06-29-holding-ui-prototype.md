# Holding UI OD 原型(A-od)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 open-design MCP 生成 holding 模块**完整三端 OD 原型**(6 界面 × desktop/tablet/mobile),御财设计语言 + 行业最佳实践,Mock 数据 + API 标注,导出到 `design-output/holding/`,作 A-flutter 完整设计源。

**Architecture:** open-design 驱动的原型生成(**非 TDD 代码**)。一个 OD 项目 `yucai-holding-prototype`:Task 1 建项目 + 设计系统(御财 CSS/组件);Task 2–7 每界面一次 `start_run`(详细 prompt 基于 spec + 御财设计 + Mock + 3 端);Task 8 导出 + 完整闭环验证。生成不符则 **prompt 修正重 run,不手编辑 HTML**(memory od-prototype-to-flutter:OD 原型直接作 Flutter 源)。

**Tech Stack:** open-design MCP(create_project / start_run / get_run / get_artifact / get_file / write_file)+ HTML/CSS/JS(御财 CSS 变量,Tailwind 可选)+ 图表(SVG 或 Chart.js,御财配色)+ Mock JS const。

## Global Constraints

- **设计语言**:御财 OD —— 金色 `#b08d57` + 衬线 Georgia/'Noto Serif SC' + 米白 `#f7f6f2` + tabular-nums + StatCard/chips/group/tabbar+FAB。复用 [design-output/accounts-responsive/mobile.html](../../../design-output/accounts-responsive/mobile.html) 的 CSS 变量(`--accent`/`--bg`/`--surface`/`--fg`/`--muted`/`--income`/`--expense`/`--radius`/`--font-*`)与组件类(summary/chip/group/acc/tabbar/fab)。
- **盈亏色规约**:盈利 = `--income:#2d8a6e`(绿)/ 亏损 = `--expense:#c4544d`(红),对齐御财资产语义(非中国股市红涨绿跌)。
- **Mock 数据**:JS const(`SECURITIES`/`HOLDINGS`/`TRADES`/`ACCOUNTS`/`PRICE_HISTORY`/`GOALS`),无网络;**空态也要设计**(无持仓/无交易/无目标)。
- **三端**:desktop(≥1024px 多列宽屏)/ tablet(768–1023px 紧凑)/ mobile(<768px 卡片+step wizard),transaction-trisize 模式。
- **API 标注**:每界面 HTML 注释标对应端点 + 请求/响应数据模型 + **实现状态**(✅ A-server 已实现 / ⏳ 待实现)。
- **lucide icon**:用 lucide icon(对齐 od-prototype-to-flutter),不用 emoji 占位(accounts-responsive 用了 emoji,holding 改用 lucide 更专业)。
- **不手改 HTML**:OD 生成不符 → prompt 修正重 `start_run`,**不手编辑生成产物**。
- **设计源 spec**:[docs/superpowers/specs/2026-06-29-holding-ui-design.md](../specs/2026-06-29-holding-ui-design.md)(每界面详节,§1–§6 + API 标注汇总表)。
- **commit**:中文 conventional;每界面导出 `design-output/holding/` 后 commit。
- **验证(非 TDD)**:open-design run `succeeded` + `get_artifact` 文件存在 + `previewUrl` 视觉对照 spec 该节"验证清单"。

## File Structure

- **open-design 项目** `yucai-holding-prototype`:6 界面 × 3 端 HTML/JSX(Mock + API 标注 + 图表)。
- **本地导出** `design-output/holding/`:`<view>-<device>.html`(如 `holdings-mobile.html`、`trade-sheet-desktop.html`)+ 共享 `mock-data.js` + `styles.css`(御财设计系统)。
- **设计源**:spec(已 commit `015fb98`)。

---

## Task 1: OD 项目 + 设计系统 scaffolding

**Files:**
- Create: open-design 项目 `yucai-holding-prototype`
- Create: `design-output/holding/styles.css`(御财设计系统提取)、`design-output/holding/mock-data.js`(共享 Mock 数据)

**Interfaces:**
- Produces: OD 项目 id + 御财设计系统 CSS + 共享 Mock 数据。Task 2–7 在此项目生成界面,复用 styles.css + mock-data.js。

**Mock 数据契约**(写入 `mock-data.js`,所有界面共享):
```js
const SECURITIES = [
  {id:'s1', symbol:'AAPL', name:'Apple Inc', type:'stock', exchange:'NASDAQ', currency:'USD', price_cents:18500},
  {id:'s2', symbol:'600000', name:'浦发银行', type:'stock', exchange:'SSE', currency:'CNY', price_cents:1085},
  {id:'s3', symbol:'510300', name:'沪深300ETF', type:'etf', exchange:'SSE', currency:'CNY', price_cents:412},
  {id:'s4', symbol:'GOLD', name:'纸黄金', type:'gold', exchange:'SHFE', currency:'CNY', price_cents:45200},
];
const HOLDINGS = [
  {security_id:'s1', quantity:50, avg_cost_cents:17000, current_price_cents:18500},  // 盈利 USD
  {security_id:'s2', quantity:1000, avg_cost_cents:1200, current_price_cents:1085},  // 亏损 CNY
  {security_id:'s3', quantity:2000, avg_cost_cents:380, current_price_cents:412},    // 盈利 CNY
];
const ACCOUNTS = [
  {id:'a1', name:'招商储蓄', type:'savings', currency:'CNY', balance_cents:1285400, category:'asset'},
  {id:'a2', name:'美股账户', type:'investment', currency:'USD', balance_cents:25000, category:'asset'},
  {id:'a3', name:'分红收入', type:'income', currency:'CNY', balance_cents:0, category:'income'},
];
const TRADES = [/* buy/sell/dividend/split 样本,见 Task 5 */];
const PRICE_HISTORY = {/* per-security 日/月 sparkline + 曲线数据 */};
const GOALS = [/* holding-backed goals,见 Task 7 */];
```

- [ ] **Step 1: 创建 OD 项目**

Run(MCP `create_project`):
```
name: "yucai-holding-prototype"
```
Expected: 返回 project id(后续 task 用)。记录 id 到 progress ledger。

- [ ] **Step 2: 提取御财设计系统到 styles.css**

读 [design-output/accounts-responsive/mobile.html](../../../design-output/accounts-responsive/mobile.html) 的 `<style>` 块,提取 `:root` CSS 变量 + 通用组件类(summary/chips/group/tabbar/fab/sheet)到 `design-output/holding/styles.css`。补 holding 专用变量:`--pnl-up`(=--income)/`--pnl-down`(=--expense)/图表色板。

- [ ] **Step 3: 写 mock-data.js**

按上面契约写 `design-output/holding/mock-data.js`(SECURITIES/HOLDINGS/ACCOUNTS 完整;TRADES/PRICE_HISTORY/GOALS 留 Task 5/6/7 补)。

- [ ] **Step 4: 验证 + Commit**

验证:`styles.css` 含御财 `:root` 变量;`mock-data.js` 含 SECURITIES/HOLDINGS/ACCOUNTS。
```bash
git add design-output/holding/styles.css design-output/holding/mock-data.js
git commit -m "feat(holding-ui): A-od scaffolding(御财设计系统 + 共享 mock 数据)"
```

---

## Task 2: 持仓列表 holdings_page(3 端)

**Files:**
- Create(open-design): holdings 界面(3 端:desktop/tablet/mobile)
- Export: `design-output/holding/holdings-{desktop,tablet,mobile}.html`

**Interfaces:**
- Consumes: styles.css + mock-data.js(SECURITIES/HOLDINGS/ACCOUNTS)
- Produces: 持仓列表 3 端 HTML(持仓入口页)

**生成 prompt**(用于 `start_run`,基于 spec §1):
```
生成 holding 模块「持仓列表」界面,三端(desktop/tablet/mobile)。
设计语言:御财(金色#b08d57+衬线+米白#f7f6f2+tabular-nums),复用 styles.css。
组件(自上而下):
1. StatCard 概览:总市值/总成本/总盈亏(盈利绿/亏损红)/收益率%;大数字 count-up + ▲▼。
2. 资产配置饼图(环图+图例):按 type 占比(stock/fund/etf/bond/gold)。
3. chips 筛选:type 横滑(带持仓数 cnt)。
4. 持仓表:symbol(等宽)+名称+量+成本价+现价+市值+sparkline 迷你走势+盈亏(色块)+盈亏%;列头排序。
5. 多币种汇总条:本币合计+原币种明细(USD/CNY 换算)。
6. FAB/顶部+:触发交易/Security 管理。
7. 空态(无持仓引导)。
三端:desktop 宽屏(饼图+表全列+侧栏 type 导航);tablet(饼图+紧凑表+chips);mobile(卡片行+sparkline 缩略+饼图折叠+StatCard 纵向)。
Mock 数据:mock-data.js 的 SECURITIES/HOLDINGS/ACCOUNTS。
API 标注(HTML 注释):ListHoldings ✅(A-server 已实现);聚合/饼图/多币种汇总首批前端计算。
lucide icon(非 emoji)。
```

- [ ] **Step 1: start_run 生成持仓列表**

MCP `start_run`(project = Task 1 项目 id,prompt = 上)。记录 runId。

- [ ] **Step 2: 轮询 get_run 直到 succeeded**

MCP `get_run(runId)` 轮询(每 ~10s),直到 `status: succeeded`(拿 `previewUrl` + `agentMessage`)。若 `failed`,读 error,prompt 修正重 `start_run`。

- [ ] **Step 3: get_artifact 检查生成**

MCP `get_artifact(entry = holdings)`:确认 3 端 HTML 生成,含 spec §1 全部 7 组件。

- [ ] **Step 4: 视觉验证(对照 spec §1 清单)**

`previewUrl` 浏览器检查:StatCard 4 格 + 数字 tabular-nums / 饼图 type 占比 / chips 筛选 / 持仓表含 sparkline + 盈亏色块 / 排序 / 多币种汇总 / 空态 / 3 端布局差异 / lucide icon / 盈利绿亏损红。不符 → prompt 修正重 run。

- [ ] **Step 5: 导出 + Commit**

MCP `get_file` 拿 3 端 HTML → Write 到 `design-output/holding/holdings-{desktop,tablet,mobile}.html`。
```bash
git add design-output/holding/holdings-*.html
git commit -m "feat(holding-ui): 持仓列表 OD 原型三端(StatCard+饼图+sparkline+多币种)"
```

---

## Task 3: 交易 Sheet(buy/sell/dividend/split 4 种,3 端)

**Files:**
- Create(open-design): trade-sheet 界面(4 种类型切换 × 3 端)
- Export: `design-output/holding/trade-sheet-{desktop,tablet,mobile}.html`

**Interfaces:**
- Consumes: styles.css + mock-data.js(SECURITIES/ACCOUNTS)
- Produces: 统一交易 Sheet 4 类型(字段随类型变)

**生成 prompt**(基于 spec §2):
```
生成 holding「交易 Sheet」界面,统一 Sheet 顶部 segmented 切换 4 种(buy/sell/dividend/split),三端。
设计语言:御财,复用 styles.css。
4 种字段:
- buy/sell:security 搜索选择 + from-account picker(选 asset 账户,币种需与 security 一致,跨币种 disabled+提示)+ 数量+价格+费用+日期+备注;实时金额(price×qty,buy 含 fee)+ 余额 fail-fast 预览(buy 不足红字)。
- dividend:security + income-account picker(分红入账)+ 每股股息+持有量(自动)+ 日期;金额=股息×量。
- split:security + 拆分比例(如 1:2)+ 日期;预览拆分后量/成本(无现金流)。
三端形态:desktop/tablet = bottom sheet 滑入;mobile = 全屏 step wizard(选类型→security→账户→数量价格→确认,顶部进度条)。
Mock:mock-data.js。API 标注:BuyHolding/SellHolding ✅;RecordDividend ✅proto/⏳双写;RecordSplit ⏳。from_account_id 必填。lucide icon。
```

- [ ] **Step 1: start_run** | **Step 2: 轮询 get_run** | **Step 3: get_artifact**(按上方 prompt + Global Constraints open-design 工作流:`start_run` → 轮询 `get_run` 至 `succeeded` → `get_artifact` 检查 3 端生成)

- [ ] **Step 4: 视觉验证(对照 spec §2)**
4 类型切换 + 字段随类型变 / from-account picker 币种约束(跨币种 disabled)/ 实时金额 + 余额 fail-fast 红字 / desktop bottom sheet + mobile step wizard 进度条 / income-account(dividend)/ 拆分比例(split)/ API 标注 + 实现状态。

- [ ] **Step 5: 导出 + Commit**
```bash
git add design-output/holding/trade-sheet-*.html
git commit -m "feat(holding-ui): 交易 Sheet OD 原型三端(buy/sell/dividend/split 4 种+step wizard)"
```

---

## Task 4: Security 管理(3 端)

**Files:**
- Create(open-design): security-admin 界面(3 端)
- Export: `design-output/holding/security-{desktop,tablet,mobile}.html`

**生成 prompt**(基于 spec §3):
```
生成 holding「Security 管理」界面,三端。御财设计语言,复用 styles.css。
组件:列表(symbol/name/type/exchange/currency/现价/更新时间)+ 搜索(symbol/name 实时过滤)+ 创建表单(symbol/name/type 下拉/exchange/currency)+ 价格管理(行内编辑现价手动 + 自动 sync 开关 disabled + 行情源下拉 mock:Yahoo/新浪/腾讯 + last-updated + 刷新 loading)。
三端:desktop/tablet 表格;mobile 卡片+创建/sync 走 sheet。
Mock:mock-data.js SECURITIES。API 标注:CreateSecurity/ListSecurities/SearchSecurities/UpdateSecurityPrice ✅;自动 sync provider ⏳(B)。lucide icon。
```

- [ ] **Step 1–3**: start_run / 轮询 / get_artifact(按上方 prompt + Global Constraints open-design 工作流:`start_run` → 轮询 `get_run` 至 `succeeded` → `get_artifact` 检查 3 端生成)
- [ ] **Step 4: 视觉验证(对照 spec §3)**:列表+搜索+创建表单+价格管理(手动行内+自动 sync 开关 disabled+行情源)+ 3 端 + API 标注。
- [ ] **Step 5: 导出 + Commit**:`git commit -m "feat(holding-ui): Security 管理 OD 原型三端(列表/搜索/创建/价格管理)"`

---

## Task 5: 持仓详情(完整,3 端)

**Files:**
- Create(open-design): holding-detail 界面(3 端)
- Export: `design-output/holding/holding-detail-{desktop,tablet,mobile}.html`
- Modify: `design-output/holding/mock-data.js`(补完整 TRADES + PRICE_HISTORY)

**生成 prompt**(基于 spec §4):
```
生成 holding「持仓详情」界面(完整),三端。御财设计语言,复用 styles.css。
组件(自上而下):
1. 头部:symbol(衬线大字)+名称+type chip+当前价(刷新按钮+loading+last-updated)。
2. 持仓卡:持有量/成本价/市值/盈亏(色块)+盈亏%。
3. 收益曲线(日/月/年区间切换):折线图 mock;realized/unrealized 分解数字。
4. 完整交易历史(列表):日期/类型(buy/sell/dividend/split)/数量/价格/金额/余额变化;筛选。
5. 配置占比:该持仓占总持仓%(mini 环图)。
6. 关联目标卡:该持仓关联 goal 进度条(市值 vs 目标额)mock。
7. 操作:buy/sell/dividend/split 按钮(触发统一 Sheet)。
三端:desktop 多列(曲线+历史+关联并列);tablet 上下;mobile 纵向+曲线折叠。
Mock:mock-data.js(TRADES + PRICE_HISTORY)。API 标注:ListHoldings(filter)✅;ListHoldingTransactions ⏳;收益 snapshot ⏳C;goal 关联 ⏳D。lucide icon。
```

- [ ] **Step 0: 补 mock-data.js**:完整 `TRADES`(buy/sell/dividend/split 样本)+ `PRICE_HISTORY`(该 security 日/月数据)。
- [ ] **Step 1–3**: start_run / 轮询 / get_artifact
- [ ] **Step 4: 视觉验证(对照 spec §4)**:头部+刷新 / 持仓卡盈亏色块 / 收益曲线日/月/年切换+realized/unrealized / 交易历史 4 类型+筛选 / 配置占比环图 / 关联目标卡进度 / 4 操作按钮 / 3 端 / API 标注。
- [ ] **Step 5: 导出 + Commit**:`git commit -m "feat(holding-ui): 持仓详情 OD 原型三端(收益曲线+交易历史+配置占比+关联目标)"`

---

## Task 6: 收益统计页(独立,3 端)

**Files:**
- Create(open-design): performance 界面(3 端)
- Export: `design-output/holding/performance-{desktop,tablet,mobile}.html`

**生成 prompt**(基于 spec §5):
```
生成 holding「收益统计页」(独立),三端。御财设计语言,复用 styles.css。
组件:
1. 总收益曲线:日/月/年切换,区间(1M/3M/6M/1Y/全部);折线 mock。
2. realized/unrealized 分解:已实现+未实现数字+占比。
3. 年化收益率 + 基准对比 mock。
4. 按持仓/类型分解:每持仓/类型收益贡献条。
三端:desktop 宽屏多图并列;tablet 上下;mobile 纵向。
Mock:mock-data.js PRICE_HISTORY。API 标注:收益 snapshot 表 ⏳C;曲线首批前端从 ListHoldingTransactions 聚合 mock。lucide icon。
```

- [ ] **Step 1–3**: start_run / 轮询 / get_artifact
- [ ] **Step 4: 视觉验证(对照 spec §5)**:总收益曲线日/月/年+区间 / realized/unrealized 分解 / 年化+基准 / 持仓/类型贡献条 / 3 端 / API 标注。
- [ ] **Step 5: 导出 + Commit**:`git commit -m "feat(holding-ui): 收益统计页 OD 原型三端(曲线+realized/unrealized+年化+分解)"`

---

## Task 7: 投资目标关联(D,3 端)

**Files:**
- Create(open-design): goal-link 界面(3 端)
- Export: `design-output/holding/goal-link-{desktop,tablet,mobile}.html`
- Modify: `design-output/holding/mock-data.js`(补 GOALS)

**生成 prompt**(基于 spec §6):
```
生成 holding「投资目标关联」界面(D 子项目 UI),三端。御财设计语言,复用 styles.css。
组件:
1. 投资目标概览:holding-backed goals 列表(目标名/关联持仓/当前市值/目标额/进度%进度条/预计达成时间 mock)。
2. goal 关联 holding 选择:在 goal 卡里选 holding 作 backing(进度=持仓市值 vs 目标额)mock 操作。
Mock:mock-data.js GOALS。API 标注:goal.backing_holding_id ⏳D;进度计算(市值 vs 目标)。lucide icon。
三端:desktop 列表+侧栏详情;tablet/mobile 卡片。
```

- [ ] **Step 0: 补 mock-data.js**:`GOALS`(holding-backed goals + 进度)。
- [ ] **Step 1–3**: start_run / 轮询 / get_artifact
- [ ] **Step 4: 视觉验证(对照 spec §6)**:目标概览列表+进度条 / 关联 holding 选择 mock / 预计达成时间 / 3 端 / API 标注。
- [ ] **Step 5: 导出 + Commit**:`git commit -m "feat(holding-ui): 投资目标关联 OD 原型三端(D:holding-backed goal 进度)"`

---

## Task 8: 完整闭环验证 + 导出收尾

**Files:**
- Modify: `design-output/holding/mock-data.js`(确保全界面数据一致)
- Verify: 全部 6 界面 × 3 端 = 18 HTML + styles.css + mock-data.js

- [ ] **Step 1: 完整闭环走查**

浏览器逐个打开 18 个 HTML,走完整交互闭环(模拟用户流):
- 建 security(Task 4)→ 买入(Task 3)→ 看持仓列表(Task 2)→ 进持仓详情(Task 5)→ 看收益统计(Task 6)→ 设投资目标(Task 7)→ dividend/split(Task 3)。
确认:界面间导航通畅 / Mock 数据一致(同一 SECURITIES/HOLDINGS)/ 设计语言统一(金色/衬线/盈亏色)/ 三端布局都完整 / 空态都设计。

- [ ] **Step 2: spec 对照检查**

逐条对照 spec §1–§6 + API 标注汇总表:每界面覆盖 spec 所有要求 / API 标注(✅/⏳)正确 / handoff 标注(Dart stub 重生成 + 跨币种预校验)存在。列出任何遗漏 → 该 task 重 run 补。

- [ ] **Step 3: Commit 收尾**

```bash
git add design-output/holding/
git commit -m "feat(holding-ui): A-od 完整 holding UI 原型(6 界面三端,完整闭环验证通过)"
```

- [ ] **Step 4: 更新 handoff memory**

更新 memory `holding-asset-management-todo`:A-od 完成(6 界面三端原型),A-flutter 下一步(前置:Dart stub 重生成 + from-account picker + 完整 UI 设计源在 design-output/holding/)。

---

## 范围边界(本 plan 不做)

- 真 API 对接 / Flutter 移植(留 A-flutter)。
- Dart stub 重生成(A-flutter handoff)。
- 后端 ⏳ 端点实现(ListHoldingTransactions/收益 snapshot/RecordSplit/goal 关联/价格自动 sync;各自子项目)。
- 手编辑 OD 生成 HTML(不符则 prompt 修正重 run)。

## 参考

- 设计源 spec:[2026-06-29-holding-ui-design.md](../specs/2026-06-29-holding-ui-design.md)
- 御财 OD 设计语言:[accounts-responsive/mobile.html](../../../design-output/accounts-responsive/mobile.html) + open-design 项目(yucai-account/transaction-trisize/debt-prototype/receivables-prototype)
- holding API(A-server):[holding.proto](../../../yucai/proto/holding/v1/holding.proto)
- 工作流约束:[[od-prototype-to-flutter]](OD 原型作设计源直接产 Flutter,lucide icon,不手改 HTML)
