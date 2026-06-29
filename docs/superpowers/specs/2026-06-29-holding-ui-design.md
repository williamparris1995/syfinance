# Holding UI OD 原型(A-od)设计

> 子项目 A 的 OD 原型阶段。总体设计见 [2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md)(§8 OD UI)。本 spec 细化 A-od 的界面/交互/数据/三端/API 标注,作 A-flutter 的设计源。

**Goal:** 产出 holding 模块**三端(desktop/tablet/mobile)OD 原型**(open-design 项目,HTML/JSX),覆盖 4 个核心界面,内置 Mock 数据演示,**注释标注 holding API 端点 + 数据模型**,为 A-flutter(Flutter 移植 + 真 API 对接)直接铺路。

**设计基调:** 御财 OD 设计语言为基础(金色/衬线/米白/StatCard/chips/tabbar),**借鉴金融行业优秀产品(Ghostfolio/MoneyWiz/雪球/Robinhood)最佳实践做适当改良优化**——不机械复用现有组件,在持仓表/下单流程/盈亏展示上做专业化提升。

## 目标 / 非目标

**目标:**
- 4 界面三端 OD 原型:持仓列表 / 交易 Sheet(buy/sell)/ Security 管理 / 持仓详情(简化)
- 御财设计语言一致 + 行业最佳实践改良
- Mock 数据演示完整交互闭环(建 security → 买入 → 看持仓 → 卖出 → 详情)
- 每界面 HTML 注释标注对应 holding API 端点 + 请求/响应数据模型
- 三端响应式(transaction-trisize 模式)

**非目标(留后续):**
- 真 server API 对接(留 A-flutter,原型用 Mock)
- 收益图表/曲线/snapshot(留 C 子项目;持仓详情只展示 realized/unrealized 数字)
- RecordSplit UI / ListHoldingTransactions 完整交易历史(A 内增量,后置)
- Dart stub 重生成(留 A-flutter handoff)
- 资产配置饼图/sparkline(方向 A 已排除,留 C)

## 设计语言(御财 + 行业改良)

### 基础:复用御财 OD 设计系统
沿用 [accounts-responsive/mobile.html](../../../design-output/accounts-responsive/mobile.html) 的 CSS 变量与组件类:
- **配色**:`--accent:#b08d57`(金色主色)/ `--bg:#f7f6f2`(米白)/ `--surface:#fff` / `--fg:#1a1916` / `--muted:#7a7770`
- **字体**:`--font-display:Georgia,'Noto Serif SC'`(衬线展示)/ `--font-body:'PingFang SC'` / `--font-mono:'SF Mono'`(tabular-nums 等宽数字)
- **圆角**:`--radius:10px` / `--radius-lg:14px`
- **组件**:summary card(deco 圆装饰)/ chips 筛选 / group 分组 / tabbar + FAB

### 行业最佳实践改良(授权范围)
在御财基础上,借鉴优秀金融产品做专业化提升:
- **盈亏色规约**:沿用御财资产语义 —— **盈利 = `--income:#2d8a6e`(绿)/ 亏损 = `--expense:#c4544d`(红)**,与 account 余额增减一致(而非中国股市红涨绿跌),保持 app 内"正向=绿"统一。
- **数字排版**(借鉴 Ghostfolio/MoneyWiz):所有金额/数量 `font-variant-numeric:tabular-nums` 右对齐;盈亏附加 `%` 色阶;大数字用 `--font-mono` 等宽。
- **持仓表**(借鉴 Ghostfolio):列头可排序 + 固定表头 + 盈亏列色块背景(浅绿/浅红底)增强扫读。
- **下单流程**(借鉴 Robinhood/雪球):字段分组(Security / 资金 / 数量价格)+ 实时金额预览 + 余额联动 fail-fast 预览。
- **StatCard**(借鉴 Mint/MoneyWiz):大数字 + 趋势指示符(▲▼)+ 分解明细(总市值/总成本/总盈亏/收益率)。

## 1. 持仓列表 holdings_page(holding 入口)

**布局**(top→bottom):
1. **StatCard 概览**(顶部):4 格 —— 总市值 / 总成本 / 总盈亏(绿红)/ 收益率%;大数字 tabular-nums + 数字滚动动画(count-up on load);盈亏带 ▲▼ 趋势符。
2. **chips 筛选**:type 横滑 chips(全部 / stock / fund / etf / bond / gold / option),每个带持仓数 `cnt`;active 深色填充(仿御财 chip)。
3. **持仓表/列表**:每行 = symbol(等宽加粗)+ 名称 + 持有量 + 成本价 + 现价 + 市值 + 盈亏(色块)+ 盈亏%;列头点击排序(市值/盈亏%/收益率,▲▼ 指示)。
4. **FAB / 顶部 +**:触发交易 Sheet(buy)或 Security 管理。
5. **空态**:引导卡片("先创建 security" → Security 管理;"买入第一笔" → 交易 Sheet)。

**三端差异**:
- **desktop**:宽屏多列表格(全列可见)+ 顶部 StatCard 横排 4 格 + 左侧可折叠 type 导航(替代 chips)。
- **tablet**:紧凑表格 + StatCard 2×2 网格 + chips。
- **mobile**:卡片行(symbol + 名称 + 市值大字 + 盈亏色块右贴)+ StatCard 纵向 + chips 横滑。

**API 标注**:`ListHoldings(tenant_id, type_filter?)` → `[{security_id, symbol, name, type, quantity, avg_cost_cents, current_price_cents, market_value_cents, unrealized_pnl_cents, pnl_pct}]`;聚合统计(总市值/成本/盈亏/收益率)**首批前端从 ListHoldings 聚合计算**(server summary 端点后置增量)。

## 2. 交易 Sheet(buy/sell)

**触发**:持仓列表/详情的 buy/sell 按钮 + 全局 FAB。

**三端形态**:
- **desktop/tablet**:右侧或 bottom **sheet 滑入**(translateY/translateX 动画),不遮挡列表。
- **mobile**:**全屏 step wizard**(4 步,顶部进度条):① 选 security(搜索)→ ② 选资金账户(from-account picker)→ ③ 数量/价格/费用 → ④ 确认摘要(展示金额 + 余额变化)→ 提交。

**字段**(分组,借鉴 Robinhood):
- **Security 组**:搜索选择(symbol/name,下拉建议)+ 显示当前价。
- **资金组**:**from-account picker**(A-server 双写 UI 核心)—— 选 asset 类型账户(储蓄/投资),下拉显示账户名 + 余额 + 币种;**币种需与 security 一致**(跨币种 disabled + 提示,呼应 A-server 已知 gap)。
- **数量价格组**:数量 + 价格 + 费用 + 日期(默认今天)+ 备注。
- **实时预览**:金额 = price × qty(buy 含 fee 显示总流出);buy 显示"资金账户余额 ¥X → 扣后 ¥Y",**不足红字 fail-fast 预览**(呼应 server validateTradeFromAccount)。

**交互**:顶部 segmented control 切换 buy/sell;sell 时 from-account picker 语义 = 资金入账账户(不查余额,提示"现金入账")。

**API 标注**:
- `BuyHolding(account_id=持仓账户, security_id, from_account_id, quantity, price_cents, fee_cents, trade_date, notes)` → 双写 credit from(现金−)+ debit holding(投资+)。
- `SellHolding(...同上...)` → 双写 debit from(现金+)+ credit holding(投资−)。
- **`from_account_id` 必填**(A-server 刚加,空则 InvalidArgument)。

## 3. Security 管理

**布局**:
- **列表**:security 表(symbol 等宽 / name / type / exchange / currency / 现价 / 更新时间)+ 搜索框(symbol/name 实时过滤)。
- **创建**:表单(symbol / name / type 下拉 / exchange / currency)→ 创建后回到列表。
- **价格更新**:行内编辑现价(点击现价 → 输入 → 保存);**首批手动**,UI 预留"自动 sync"开关(disabled,B 子项目启用)。

**三端**:desktop/tablet 表格;mobile 卡片列表 + 创建走 sheet。

**API 标注**:
- `CreateSecurity(symbol, name, security_type, exchange, currency_code)` → `{security_id, ...}`。
- `ListSecurities(tenant_id, type_filter?)` / `SearchSecurities(query)`。
- `UpdateSecurityPrice(security_id, price_cents)`。

## 4. 持仓详情(简化)

**布局**(top→bottom):
1. **头部摘要**:symbol(大字衬线)+ 名称 + 类型 chip + 当前价(实时刷新按钮,loading 态)。
2. **持仓卡**:持有量 / 成本价 / 市值 / 盈亏(色块)+ 盈亏%。
3. **收益分解**(数字,无图表):realized(已实现,卖出)/ unrealized(未实现,浮动)—— 两行 tabular-nums,呼应 server `ApplySell` 返回的 realizedPnL。**收益曲线留 C**。
4. **交易记录流**(简化列表):该持仓的 buy/sell/dividend 流(日期 / 类型 / 数量 / 价格 / 金额),首批简化(完整 ListHoldingTransactions 后置增量)。
5. **操作**:buy / sell / dividend 按钮(触发对应 Sheet)。

**API 标注**:`ListHoldings(security_id filter)` 单持仓;`ListHoldingTransactions(holding_id)`(后置增量,首批 mock)。

## API 标注(首批 8 端点,对齐 spec §4.3)

每端点在对应界面 HTML 注释标注:**请求字段 + 响应字段 + 双写联动**:

| 端点 | 用途 | 双写联动 |
|---|---|---|
| `CreateSecurity` | 建 security(Security 管理) | 无(仅 security) |
| `ListSecurities` / `SearchSecurities` | 列表/搜索(Security 管理 + 交易 Sheet 选择) | 无 |
| `UpdateSecurityPrice` | 手动改价(Security 管理) | 无(首批;B 自动) |
| `BuyHolding` | 买入(交易 Sheet) | credit from(现金−)+ debit holding(投资+) |
| `SellHolding` | 卖出(交易 Sheet) | debit from(现金+)+ credit holding(投资−) |
| `RecordDividend` | 分红(详情操作) | dividend 单独 Sheet(首批 UI);双写待 income account 设计 |
| `ListHoldings` | 持仓列表/详情 | 读(聚合统计) |

**handoff 标注**(为 A-flutter):
- `from_account_id` 已加 proto(Go stub 已生),**Dart stub 需 `buf generate` 重生成**(A-flutter 前置)。
- 跨币种 gap(security vs account 币种)A-server 未校验 —— A-flutter picker 里做客户端预校验(disabled 跨币种),作为防线。

## 三端适配(transaction-trisize 模式)

对齐 [yucai-transaction-trisize](open-design 项目)模式:
- **desktop**(≥1024px):多列宽屏,持仓表全列 + StatCard 横排 + 侧栏 type 导航 + Sheet 右侧滑入。
- **tablet**(768–1023px):紧凑表格 + StatCard 2×2 + chips + Sheet bottom。
- **mobile**(<768px):卡片行 + StatCard 纵向 + chips 横滑 + 交易全屏 step wizard。

每界面产 3 个 HTML(desktop/tablet/mobile)或响应式单文件(由 open-design 生成时定;优先三端独立以贴合 trisize 先例)。

## 交互/动画(对齐御财惯例 + 行业增强)

- 排序/筛选过渡(transform + opacity,150ms)。
- Sheet 滑入(ease-out)/ 滑出(ease-in)。
- StatCard 数字滚动(count-up on load)。
- 价格刷新按钮 loading 态 + last-updated 时间戳。
- mobile step wizard 进度条 + 步间滑动过渡。
- FAB 提交成功反馈(toast/checkmark)。

## Mock 数据策略

内置 JS const(仿 accounts-responsive 的 `ACCOUNTS`):
- `SECURITIES`:`[{security_id, symbol:'AAPL'/'600000', name, type, exchange, currency:'USD'/'CNY', price_cents}]`(跨币种样本,演示 picker 币种约束)。
- `HOLDINGS`:`[{security_id, quantity, avg_cost_cents, current_price_cents, ...}]`(含盈/亏样本)。
- `TRADES`:交易记录样本。
- `ACCOUNTS`(资金账户):asset 类(储蓄 CNY / 投资 USD),供 from-account picker。

数据完全前端,无网络调用;A-flutter 阶段替换为真 API。

## 交付物

- **open-design 项目** `yucai-holding-prototype`:4 界面 × 3 端 HTML/JSX(含 Mock 数据 + API 标注注释)。
- **本 spec 文档**(A-od 设计源)。
- 导出到本地 `design-output/holding/`(三端 HTML)。

## 范围边界(本 A-od 不做)

- 真 API 对接 / Flutter 移植(留 A-flutter)。
- 收益图表/曲线/snapshot 表(留 C)。
- RecordSplit UI / 完整 ListHoldingTransactions 交易历史(A 内增量,后置)。
- Dart stub 重生成(A-flutter handoff)。
- 资产配置饼图 / sparkline(方向 A 已排除)。

## 参考

- 总体设计 §8 OD UI:[2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md)
- 御财 OD 设计语言:[accounts-responsive/mobile.html](../../../design-output/accounts-responsive/mobile.html) + open-design 项目 yucai-account / yucai-transaction-trisize / yucai-debt-prototype / yucai-receivables-prototype
- holding API(A-server 已实现):[holding.proto](../../../yucai/proto/holding/v1/holding.proto)(含 from_account_id)
- 行业产品:Ghostfolio(持仓表)/ MoneyWiz(资产概览)/ 雪球(下单 + 盈亏)/ Robinhood(step wizard 下单)
- 工作流约束:[[od-prototype-to-flutter]](OD 原型作设计源直接产 Flutter,lucide icon,不手改 HTML 中间步骤)
