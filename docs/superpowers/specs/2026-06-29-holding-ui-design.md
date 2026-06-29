# Holding UI OD 原型(A-od)设计

> **修订(2026-06-29):** 扩大到**完整 holding UI 全景**。原 v1 按 A/B/C/D 子项目分阶段(UI 分阶段),用户纠正:**UI 原型一次设计完整,功能/数据用 mock 或空填充**;只有功能实现(后端 API、A-flutter 移植)才分阶段。本 spec 据此重写。
>
> 总体设计见 [2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md)(§8 OD UI)。本 spec 是 A-od 的设计源,作 A-flutter 完整移植依据。

**Goal:** 产出 holding 模块**完整三端(desktop/tablet/mobile)OD 原型**(open-design 项目,HTML/JSX),覆盖 holding 全部 UI(6 个界面),内置 Mock/空数据演示,**注释标注完整 holding API(区分已实现/待实现)**,为 A-flutter(Flutter 移植 + 真 API 对接)提供完整设计源。

**设计理念(核心):** UI 原型**一次设计完整**,不分 A/B/C/D 阶段;功能/数据用 mock 或空。只有**后端 API 实现**与 **Flutter 移植**分阶段。这样 A-flutter 移植时有完整 UI 全景可依,不会因后端未实现而缺设计。

**设计基调:** 御财 OD 设计语言为基础(金色/衬线/米白/StatCard/chips/tabbar),**借鉴金融行业优秀产品(Ghostfolio/MoneyWiz/雪球/Robinhood)最佳实践做适当改良优化**。

## 目标 / 非目标

**目标:**
- 6 界面三端完整原型:持仓列表 / 交易 Sheet(buy/sell/dividend/split)/ Security 管理 / 持仓详情 / 收益统计页 / 投资目标关联
- 御财设计语言一致 + 行业最佳实践改良
- Mock/空数据演示完整 UI 闭环(含收益曲线/交易历史/目标进度/饼图/sparkline)
- 每界面 HTML 注释标注对应 API 端点 + 数据模型 + **实现状态(✅ 已实现 / ⏳ 待实现)**
- 三端响应式(transaction-trisize 模式)

**非目标(只留 A-flutter):**
- 真 server API 对接(原型用 mock/空)
- Flutter 移植(留 A-flutter)
- Dart stub 重生成(留 A-flutter handoff)

## 设计语言(御财 + 行业改良)

### 基础:复用御财 OD 设计系统
沿用 [accounts-responsive/mobile.html](../../../design-output/accounts-responsive/mobile.html) CSS 变量与组件类:
- **配色**:`--accent:#b08d57`(金)/ `--bg:#f7f6f2`(米白)/ `--surface:#fff` / `--fg:#1a1916` / `--muted:#7a7770`
- **字体**:`--font-display:Georgia,'Noto Serif SC'`(衬线)/ `--font-body:'PingFang SC'` / `--font-mono:'SF Mono'`(tabular-nums)
- **圆角**:`--radius:10px` / `--radius-lg:14px`
- **组件**:summary card(deco 圆装饰)/ chips / group / tabbar + FAB / sheet

### 行业最佳实践改良(授权范围)
- **盈亏色规约**:沿用御财资产语义 —— **盈利 = `--income:#2d8a6e`(绿)/ 亏损 = `--expense:#c4544d`(红)**,与 account 余额增减一致(非中国股市红涨绿跌),保持 app 内"正向=绿"统一。
- **数字排版**(Ghostfolio/MoneyWiz):金额/数量 `tabular-nums` 右对齐;盈亏 `%` 色阶;大数字等宽。
- **持仓表**(Ghostfolio):列头排序 + 固定表头 + 盈亏列色块背景。
- **图表**(D3/Chart.js 或纯 SVG):饼图(配置占比)+ 折线(收益曲线)+ sparkline(走势迷你图),御财配色。
- **下单流程**(Robinhood/雪球):字段分组 + 实时金额预览 + 余额 fail-fast 预览。
- **StatCard**(Mint/MoneyWiz):大数字 + ▲▼ 趋势 + 分解明细。

## 1. 持仓列表 holdings_page(holding 入口)

**布局**(top→bottom):
1. **StatCard 概览**:总市值 / 总成本 / 总盈亏(绿红)/ 收益率%;大数字 tabular-nums + count-up 滚动 + ▲▼。
2. **资产配置饼图**(环图 + 图例):按 type 占比(stock/fund/etf/bond/gold);点击图例高亮对应持仓。
3. **chips 筛选**:type 横滑(带持仓数 cnt)。
4. **持仓表**:symbol(等宽加粗)+ 名称 + 持有量 + 成本价 + 现价 + 市值 + **sparkline 走势列**(迷你折线)+ 盈亏(色块)+ 盈亏%;列头排序。
5. **多币种汇总条**(跨国证券):本币合计 + 原币种明细(USD/CNY 等,用 currency rate 换算)。
6. FAB / 顶部 +:触发交易 Sheet / Security 管理。
7. 空态引导。

**三端**:desktop 宽屏(饼图 + 表全列 + 侧栏 type 导航)/ tablet(饼图 + 紧凑表 + chips)/ mobile(卡片行 + sparkline 缩略 + 饼图置顶折叠 + StatCard 纵向)。

**API 标注**:`ListHoldings(tenant_id, type_filter?)`(✅ A-server 已实现);聚合统计 + 配置占比 + 多币种汇总**首批前端从 ListHoldings 计算**(server summary 端点 ⏳ 后置)。

## 2. 交易 Sheet(buy/sell/dividend/split 统一,4 种)

**统一 Sheet,顶部 segmented 切换 4 种类型**(字段随类型变):

- **buy / sell**:security 搜索选择 + **from-account picker**(选 asset 账户,币种需与 security 一致,跨币种 disabled + 提示)+ 数量 + 价格 + 费用 + 日期 + 备注;实时金额(price×qty,buy 含 fee)+ 余额 fail-fast 预览(buy 不足红字)。
- **dividend**:security + **income-account picker**(分红入账账户)+ 每股股息 + 持有量(自动)+ 日期;金额 = 股息 × 量。
- **split**:security + **拆分比例**(如 1:2)+ 日期;预览拆分后量/成本调整(无现金流)。

**三端形态**:desktop/tablet = bottom sheet 滑入;mobile = 全屏 step wizard(选类型 → security → 账户 → 数量价格 → 确认)。

**API 标注**:
- `BuyHolding` / `SellHolding`(✅ 已实现,双写 credit/debit from + holding)。
- `RecordDividend`(✅ proto 有,handler 双写待 income account 设计)。
- `RecordSplit`(⏳ 待实现)。
- `from_account_id` 必填(A-server 已加,Dart stub 需重生成 handoff)。

## 3. Security 管理

**布局**:
- **列表**:symbol / name / type / exchange / currency / 现价 / 更新时间 + 搜索(symbol/name 实时过滤)。
- **创建**:表单(symbol/name/type/exchange/currency)。
- **价格管理**:行内编辑现价(手动)+ **自动 sync 开关**(disabled,B 子项目;旁有行情源选择下拉 mock:Yahoo/新浪/腾讯)+ last-updated 时间戳 + 刷新 loading 态。

**三端**:desktop/tablet 表格;mobile 卡片 + 创建/sync 走 sheet。

**API 标注**:`CreateSecurity` / `ListSecurities` / `SearchSecurities` / `UpdateSecurityPrice`(✅ 已实现);自动 sync provider ⏳(B 子项目,scheduler + 行情 API)。

## 4. 持仓详情 holding_detail(完整)

**布局**(top→bottom):
1. **头部**:symbol(衬线大字)+ 名称 + type chip + 当前价(刷新按钮 + loading + last-updated)。
2. **持仓卡**:持有量 / 成本价 / 市值 / 盈亏(色块)+ 盈亏%。
3. **收益曲线**(日/月/年区间切换):折线图 mock 数据(走势);realized/unrealized 分解数字。
4. **完整交易历史**(ListHoldingTransactions 流):日期 / 类型(buy/sell/dividend/split)/ 数量 / 价格 / 金额 / 余额变化;首批 mock,支持筛选。
5. **配置占比**:该持仓占总持仓 % (mini 环图)。
6. **关联目标卡**(D):该持仓关联的 goal 进度条(市值 vs 目标额);mock。
7. **操作**:buy / sell / dividend / split 按钮(触发统一 Sheet)。

**三端**:desktop 多列(曲线 + 历史 + 关联并列)/ tablet 上下 / mobile 纵向 + 曲线折叠。

**API 标注**:`ListHoldings(security_id filter)`(✅);`ListHoldingTransactions(holding_id)`(⏳ 待实现);收益 snapshot(⏳ C);goal 关联(⏳ D)。

## 5. 收益统计页(独立,C UI 原型)

**布局**:
1. **总收益曲线**:日/月/年切换,区间选择(1M/3M/6M/1Y/全部);折线 mock。
2. **realized/unrealized 分解**:已实现(卖出)+ 未实现(浮动)数字 + 占比。
3. **年化收益率** + 基准对比(mock)。
4. **按持仓/类型分解**:每持仓/类型收益贡献条。

**三端**:desktop 宽屏多图并列 / tablet 上下 / mobile 纵向。

**API 标注**:收益 snapshot 表(日/月/年聚合,⏳ C 子项目实现);曲线首批前端从 ListHoldingTransactions 聚合(mock)。

## 6. 投资目标关联(D)

**布局**:
1. **投资目标概览**(独立或持仓详情聚合):holding-backed goals 列表 —— 目标名 / 关联持仓(或 security)/ 当前市值 / 目标额 / **进度 %**(进度条)+ 预计达成时间(mock)。
2. **goal 关联 holding 选择**:在 goal 创建/编辑里选 holding 作 backing(目标进度 = 持仓市值 vs 目标额);mock 操作。
3. **持仓详情关联卡**:见 §4.6。

**API 标注**:goal 关联 holding 字段(`goal.backing_holding_id`,⏳ D 子项目);goal 进度计算(持仓市值 vs 目标)。

## API 标注汇总(完整 holding 相关 API)

每端点在对应界面 HTML 注释标注:**请求/响应字段 + 双写联动 + 实现状态**:

| 端点 | 用途 | 双写联动 | 状态 |
|---|---|---|---|
| `CreateSecurity` | 建 security | 无 | ✅ |
| `ListSecurities` / `SearchSecurities` | 列表/搜索 | 无 | ✅ |
| `UpdateSecurityPrice` | 手动改价 | 无 | ✅ |
| `BuyHolding` | 买入 | credit from + debit holding | ✅ |
| `SellHolding` | 卖出 | debit from + credit holding | ✅ |
| `RecordDividend` | 分红 | 待 income account 设计 | ✅ proto / ⏳ 双写 |
| `ListHoldings` | 持仓列表/详情 | 读 | ✅ |
| `RecordSplit` | 拆分 | 无现金流 | ⏳ |
| `ListHoldingTransactions` | 交易历史 | 读 | ⏳ |
| 收益 snapshot(日/月/年) | 收益统计/曲线 | 读 | ⏳ C |
| `goal.backing_holding_id` | 目标关联持仓 | 读 | ⏳ D |
| 价格自动 sync provider | Security 自动刷新 | 写 price | ⏳ B |

**handoff 标注**(为 A-flutter):
- `from_account_id` 已加 proto(Go stub 已生),**Dart stub 需 `buf generate` 重生成**(A-flutter 前置)。
- 跨币种 gap(security vs account 币种)A-server 未校验 —— A-flutter from-account picker 做客户端预校验(disabled 跨币种)作防线。
- ⏳ 端点:原型 mock 演示 UI,A-flutter 移植时按后端实现进度对接(后端先实现先对接)。

## 三端适配(transaction-trisize 模式)

对齐 [yucai-transaction-trisize](open-design 项目):
- **desktop**(≥1024px):多列宽屏,表全列 + 图表并列 + 侧栏导航 + Sheet 右侧滑入。
- **tablet**(768–1023px):紧凑表 + 图表上下 + chips + Sheet bottom。
- **mobile**(<768px):卡片行 + 图表折叠 + step wizard 交易。

每界面产 3 端(三端独立 HTML 贴合 trisize 先例,或响应式单文件由 open-design 生成时定)。

## 交互/动画(御财惯例 + 行业增强)

排序/筛选过渡(150ms)/ Sheet 滑入(ease)/ StatCard count-up 滚动 / 价格刷新 loading + last-updated / 图表 hover tooltip + 区间切换过渡 / mobile step wizard 进度条 / FAB 提交 toast 反馈 / 盈亏色块过渡。

## Mock 数据策略

内置 JS const(仿 accounts-responsive 的 `ACCOUNTS`):
- `SECURITIES`(跨币种:USD/CNY 样本)。
- `HOLDINGS`(盈/亏样本 + 多 type)。
- `TRADES`(buy/sell/dividend/split 历史)。
- `ACCOUNTS`(asset 类资金账户 + income 账户)。
- `PRICE_HISTORY`(sparkline + 收益曲线数据)。
- `GOALS`(holding-backed goals + 进度)。

数据完全前端,无网络;空态(无持仓/无交易/无目标)也设计。A-flutter 替换为真 API。

## 交付物

- **open-design 项目** `yucai-holding-prototype`:6 界面 × 3 端 HTML/JSX(Mock 数据 + API 标注 + 图表)。
- **本 spec 文档**(完整 UI 设计源)。
- 导出到本地 `design-output/holding/`(三端 HTML)。

## 范围边界(本 A-od 不做)

- 真 API 对接 / Flutter 移植(留 A-flutter)。
- Dart stub 重生成(A-flutter handoff)。
- 后端 ⏳ 端点的实现(各自子项目;原型只 mock UI)。

## 参考

- 总体设计 §8 OD UI + §4-7(A/B/C/D):[2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md)
- 御财 OD 设计语言:[accounts-responsive/mobile.html](../../../design-output/accounts-responsive/mobile.html) + open-design:yucai-account / yucai-transaction-trisize / yucai-debt-prototype / yucai-receivables-prototype
- holding API(A-server 已实现):[holding.proto](../../../yucai/proto/holding/v1/holding.proto)(含 from_account_id)
- 行业产品:Ghostfolio(持仓表/配置图)/ MoneyWiz(资产概览/目标)/ 雪球(下单 + 盈亏 + 曲线)/ Robinhood(step wizard)
- 工作流约束:[[od-prototype-to-flutter]](OD 原型作设计源直接产 Flutter,lucide icon,不手改 HTML 中间步骤)
