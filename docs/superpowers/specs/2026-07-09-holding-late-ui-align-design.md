# Holding 后期 4 项 UI 对齐 OD 原型 — Design Spec

**Date**: 2026-07-09
**Branch**: `holding-asset-management`
**Status**: design(待 plan)
**OD 原型**: `design-output/holding/{performance,security,trade-sheet,holdings}-desktop.html`(+ tablet/mobile)
**Flutter 现状**: `yucai/client/lib/holding/presentation/pages/{performance,security,trade_sheet,holdings}_page.dart`

## Goal

将 holding 模块 4 个页面的「后期视觉差距」对齐 OD 原型。差距已通过 visual companion side-by-side 与用户确认(2026-07-09)。**纯 client 改动**(presentation 为主),不碰 server/proto —— 因 server B-sync 已完成(provider 链固定 Sina + `SyncPrices` RPC + scheduler),provider 选择器做视觉占位。

4 项:
1. performance ⑤ **bench-mini**(基准对比条 + 超额)
2. security **行情源 + 同步状态**(provider bar,只读占位)
3. trade_sheet **per-type 配色**(buy/sell/dividend/split)
4. holdings **desktop 双栏**(desk-grid 饼图‖表)

## Background — 差距清单(visual companion 已确认 2026-07-09)

### #1 performance bench-mini(High · 视觉 + 数据近似)
- OD ⑤ 有 `bench-mini`:「我的组合 vs 沪深300」中线对比条(`bm-track`/`bm-fill my/bench`/`bm-mid`)+ 超额行。
- Flutter 现状:⑤ 只有 benchmark **文字 label**(`benchmarkName` 有 → "基准 XXX",无 → "基准 沪深300 · ⏳C mock"),无对比条 / 沪深300 数值 / 超额。
- 数据层:`PortfolioPerformance` 有 `annualizedPct`(我的年化)/ `totalPct`(我的累计)/ `benchmarkPoints`(基准曲线)/ `benchmarkName`;**基准年化 / 累计% 未算** → 纯前端从 `benchmarkPoints` 近似。

### #2 security 行情源 + 同步状态(Medium · 视觉占位)
- OD 有 provider bar:全局行情源下拉(Yahoo/新浪/腾讯)+ 自动同步开关(disabled,B 预留)+ per-row provider 下拉。
- Flutter 现状:只有「自动同步未启用 · B 子项目」提示条 + 行内改价;**无行情源标识 / 同步时间 / 手动刷新入口**。
- ⚠️ server provider 链固定(`CompositeRouter`/`SinaProvider`,client 不可选)→ provider 做**只读占位**(展示「新浪财经」),不假装能切。补同步时间 + 手动刷新(已有 `RefreshPricesRequested`)。

### #3 trade per-type 色(Medium · 纯视觉)
- OD:seg 4 按钮 + amount 预览条 + 余额 fail-fast,**4 类型各有色**(`.t-buy`/`.t-sell`/`.t-dividend`/`.t-split`)。
- Flutter 现状:统一 form,4 类型全灰,无配色区分。

### #4 holdings desktop 2-col(Medium · 纯视觉)
- OD desktop:`stat-grid cols-4`(4 格横排)+ `desk-grid`(资产配置饼图 ‖ 持仓表 并排)。
- Flutter 现状:有 `LayoutBuilder` + `GridView`(stat 卡 2 列),但饼图与持仓表**单列堆叠**,非桌面并排。

## Architecture(纯 client)

```
client(Flutter DDD,仅 presentation + 必要 data)
  lib/holding/presentation/pages/performance_page.dart   #1 新增 _BenchmarkMiniBar(替换 ⑤ benchmark label)
  lib/holding/presentation/pages/security_page.dart      #2 改造提示条 → provider bar(只读 chip + 同步时间 + 刷新)
  lib/holding/presentation/pages/trade_sheet_page.dart   #3 seg/amount/余额 per-type 上色
  lib/holding/presentation/pages/holdings_page.dart      #4 LayoutBuilder 断点:desktop desk-grid 并排 + stat 4 格
  lib/holding/presentation/widgets/                      按需抽 _BenchmarkMiniBar / _ProviderBar / _TradeTypeStyle
```

无 server / proto / ent / wire 改动。

## Tech Stack
- Flutter:flutter_bloc + injectable + lucide_icons + 御财设计语言(gold #b08d57 / serif / cream / up-green / down-red)
- 复用:`PerformanceBloc`/`PerformanceLoaded`、`HoldingBloc`/`HoldingLoaded.lastPriceSyncedAt`、`RefreshPricesRequested`、现有饼图 widget、`PerfPoint`

## Global Constraints(御财)
1. 分支 `holding-asset-management`(不新建 worktree)
2. **纯 client**:不碰 server/proto/ent/wire(YAGNI — server B-sync 已完成,provider 固定)
3. **复用第一**:bench-mini 中线条复用御财 stat/进度条范式;provider bar 复用现有提示条 + 刷新入口;2-col 复用现有饼图 + 持仓列表;trade 色板复用御财 up/down/gold
4. **多币种不硬编码**:货币显示走 `currencySymbol(code)`(bench-mini 基准对比为 %,不涉币种;amount 预览走现有逻辑已合规)
5. **English 结构化日志**(slog/console.error,无 CJK)— 本期纯 UI 改动基本无新日志
6. **flutter analyze 基线 22 error**(全 pbserver)+ 3 预存 fail(account/debt/transaction_detail_page,非本 spec 引入)
7. **每 task commit**(中文 conventional `feat(holding-late-align): ...`)
8. 路由优先级:本期不改路由(holding 路由已接入)

---

## #1 bench-mini(performance_page ⑤)

### 组件
新增 `_BenchmarkMiniBar` widget,替换现有 ⑤ 的 benchmark 文字 label(`annualBenchLabel`)。结构(对齐 OD `bench-mini`):
- 标题行:「年化收益率 · 对比基准 {benchmarkName or 沪深300}」+ ⏳C badge(基准近似)
- `bm-row ×2`:「我的组合」「{benchmarkName}」每行 = label + `bm-track`(中线 `bm-mid` + `bm-fill` 向右,正绿负红 / 基准灰)+ 数值%
- 超额行:`benchDelta = myAnnualized − benchAnnualized`(正绿负红)

### 数据流
`PerformanceLoaded`(镜像 `PortfolioPerformance`):
- `myAnnualized = annualizedPct`(server 算)
- `benchCumulative` = 纯前端从 `benchmarkPoints` 近似:`(last.value − first.value) / first.value × 100`(first 为 0/空 → 0)
- `benchAnnualized` = 纯前端近似:`benchCumulative / 年数`(年数 = 曲线跨度天数 / 365;**年数 < 1 时年化 = `benchCumulative` 不放大**,避免短期数据失真;标注「近似,非 CAGR」)
- `benchDelta = myAnnualized − benchAnnualized`
- 无 `benchmarkPoints`(空)→ 整个 `_BenchmarkMiniBar` 降级:只显我的年化 +「基准 ⏳ 待后端」(维持现状文案)

### 决策(已与用户确认)
对比维度 = **年化**(对齐 OD 视觉);基准年化前端近似 + 标注「近似」。累计% 不显(对齐 OD 只显年化)。

---

## #2 security provider bar(security_page)

### 现状(self-review 核实)
`_SyncDisabledBanner`(lock +「自动同步未启用」+「⏳ 待后端 · B 子项目:scheduler + 行情 API」+ `Switch.adaptive` disabled)+ 顶栏 `refreshBtn`(触发 `LoadSecuritiesRequested` **列表重载**,非价格同步)。
**矛盾**:server B-sync 已完成(scheduler + SinaProvider + `SyncPrices`),但 banner 文案/Switch 还停留在「B 未实现」占位 —— 这是 #2 对齐的核心。

### 组件(对齐 OD provider bar)
改造 `_SyncDisabledBanner` → provider bar:
- lock → globe icon;「自动同步未启用」→「自动同步 · 新浪财经」;去「⏳ 待后端」(已实现)
- 行情源**只读 chip**「新浪财经」(server 固定 Sina,非可点下拉;tooltip「行情源由服务端配置」)
- 上次同步时间 `lastPriceSyncedAt`(格式化「HH:mm」/「刚刚 / N 分钟前」)
- 手动价格刷新按钮(`RefreshPricesRequested`,icon refreshCw)— 与现有 `refreshBtn`(列表重载)区分或合并

### 决策(已确认 2026-07-09)
现有 `Switch.adaptive`(disabled)是 B 未实现时的占位。B 已实现后 scheduler 后台跑(client 不可控启停)。**去掉 Switch**(scheduler 后台跑非 client 控,假开关误导)。

### 数据流
全从 `HoldingLoaded`(security_page 已 `BlocProvider<HoldingBloc>`):`lastPriceSyncedAt`(已有)+ `RefreshPricesRequested`(已有 event);行情源「新浪财经」client 常量(对齐 `price_history.Source="sina"`),非 RPC。**不动 server / proto**。

### 非目标
- 不做 per-row provider 下拉(server 无 per-security provider 配置)
- 不做真能切 provider 的下拉(server 固定 Sina)

---

## #3 trade per-type 色(trade_sheet_page)

### 组件
按 `TradeType` 给三处上色(对齐 OD `.t-{type}`):
- seg 4 按钮:选中态按**类型色**(buy=金 / sell=红 / dividend=绿 / split=蓝灰,见下色板;底色 + 白字)
- amount 预览条(`amt-row`):数值按类型色(现 amtColor 是资金流向色 → 改类型色)
- 余额 fail-fast 预览(`bal-preview`):维持现有 ok/fail 资金流向语义(红=不足),不改

### 色板(对齐 `design-output/holding/styles.css:524-527` OD type 色 — **类型标识色,非资金流向色**)
- buy = `--buy #b08d57`(金)= `AppColors.accent`
- sell = `--sell #c4544d`(红)= `AppColors.negative`
- dividend = `--dividend #2d8a6e`(绿)= `AppColors.positive`
- split = `--split #6b7a8f`(蓝灰)= 新常量(AppColors 无,holding 局部 `const _kSplitColor = Color(0xFF6B7A8F)` + soft `Color(0xFFE7EAEF)`)
- soft 底:buy `--buy-soft #f3ebdd`=`accentSoft`;sell/dividend/split soft 用对应色 `withValues(alpha: 0.10)`

### 数据流
纯 presentation,`TradeType` 已有(`_type`),数据 / proto 不变。

---

## #4 holdings desktop 2-col(holdings_page)

### 组件
`LayoutBuilder` 加断点:
- desktop(≥1024px,对齐 OD `d-desktop`):
  - StatCard 横排 4 格(`stat-grid cols-4`,现有 2 列 → 4 列)
  - `desk-grid`:资产配置饼图(左,flex 1) ‖ 持仓表(右,flex 1.6)并排
- 窄屏(<1024px):维持现有堆叠(stat 2 列 + 饼图整行 + 列表整行)

### 数据流
纯布局,数据不变(饼图 + 持仓列表现有)。

---

## Testing
- `performance_page_test`:`_BenchmarkMiniBar` 渲染 — 有 `benchmarkPoints`(中线对比条 + 超额)/ 无(降级 label);`myAnnualized` 正/负 fill 方向
- `security_page_test`:provider bar 显示「新浪财经」+ `lastPriceSyncedAt` + 刷新按钮触发 `RefreshPricesRequested`
- `trade_sheet_page_test`:4 类型切换 seg/amount 配色正确(buy 绿 / sell 红 / dividend 金 / split 紫)
- `holdings_page_test`:`LayoutBuilder` 断点 — desktop 4 格 + desk-grid 并排 / 窄屏堆叠
- 基线:3 预存 fail 不引入新 fail;analyze 22 error 基线不动

## Scope / Non-Goals
- 不碰 server/proto/ent/wire(YAGNI)
- bench-mini 基准年化 = 前端近似(非 CAGR,C defer 已知);基准真年化待 C-snapshot 后续补 server
- security provider 不真切换(server 固定 Sina);per-row provider / 自动同步开关 不做
- account form(cat-hint + notes)不在本 spec(memory 下个优先级,另开 spec)
- 不重构现有 holding 页面结构(仅对齐 4 处差距)
