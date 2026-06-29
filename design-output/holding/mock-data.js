/* ========================================================================
   御财 YuCai · 持仓模块（Holding）· mock 数据
   暴露：window.SECURITIES / window.HOLDINGS / window.ACCOUNTS
         window.RATES (USD→CNY = 7.25)
   以及前端聚合 helper（占比/统计/多币种汇总，首批前端从 ListHoldings 计算）
   ======================================================================== */

/* 汇率（基准币 CNY） */
window.RATES = { USD: 7.25, CNY: 1, HKD: 0.92 };
window.BASE_CURRENCY = 'CNY';

/* 证券字典（覆盖 5 种 type：stock/fund/etf/bond/gold） */
window.SECURITIES = {
  s1: { id: 's1', symbol: 'AAPL',   name: 'Apple Inc.',  type: 'stock', currency: 'USD', market: 'NASDAQ' },
  s2: { id: 's2', symbol: '600000', name: '浦发银行',     type: 'stock', currency: 'CNY', market: 'SH' },
  s3: { id: 's3', symbol: '510300', name: '沪深300ETF',   type: 'etf',   currency: 'CNY', market: 'SH' },
  s4: { id: 's4', symbol: '163406', name: '兴全合润混合', type: 'fund',  currency: 'CNY', market: 'SH' },
  s5: { id: 's5', symbol: '019547', name: '24国债09',     type: 'bond',  currency: 'CNY', market: 'SH' },
  s6: { id: 's6', symbol: 'AU9999', name: '黄金延期',     type: 'gold',  currency: 'CNY', market: 'SH' },
};

/* 账户（含 income 类分红收入账户 a3，演示 dividend 入账） */
window.ACCOUNTS = {
  a1: { id: 'a1', name: '美股账户',     broker: '盈透证券 IBKR', currency: 'USD' },
  a2: { id: 'a2', name: 'A股账户',      broker: '华泰证券',       currency: 'CNY' },
  a3: { id: 'a3', name: '分红收入账户', broker: '招商银行',       currency: 'CNY', kind: 'income' },
};

/* 持仓（5 种 type 各 ≥1，跨 USD/CNY，盈亏混合）
   s1 AAPL     (stock·USD)：50 股，成本 $170，现价 $185  → +$750   ≈ +¥5437.5
   s2 600000   (stock·CNY)：1000 股，成本 ¥12.00，现价 ¥10.85 → -¥1150.0
   s3 510300   (etf·CNY)：  2000 份，成本 ¥3.80，现价 ¥4.12   → +¥640.0
   s4 163406   (fund·CNY)： 5000 份，成本 ¥2.50，现价 ¥2.68   → +¥900.0
   s5 019547   (bond·CNY)：  100 张，成本 ¥100.00，现价 ¥101.20 → +¥120.0
   s6 AU9999   (gold·CNY)： 100 克，成本 ¥520.00，现价 ¥545.00 → +¥2500.0
*/
window.HOLDINGS = [
  {
    id: 'h1', security_id: 's1', account_id: 'a1',
    quantity: 50, cost_price: 170, current_price: 185, currency: 'USD',
    /* 盈利：30 点上行走势 */
    sparkline: 'M0,22 L3,20 L7,21 L10,18 L14,19 L17,16 L21,17 L24,14 L28,15 L31,13 L34,14 L38,11 L41,12 L45,10 L48,9 L52,11 L55,8 L59,9 L62,7 L66,8 L69,6 L72,7 L76,5 L79,6 L83,4 L86,5 L90,3 L93,4 L97,3 L100,2',
  },
  {
    id: 'h2', security_id: 's2', account_id: 'a2',
    quantity: 1000, cost_price: 12.00, current_price: 10.85, currency: 'CNY',
    /* 亏损：30 点下行走势 */
    sparkline: 'M0,5 L3,6 L7,5 L10,7 L14,6 L17,8 L21,7 L24,9 L28,8 L31,10 L34,9 L38,11 L41,10 L45,12 L48,11 L52,13 L55,12 L59,14 L62,13 L66,15 L69,14 L72,16 L76,17 L79,16 L83,18 L86,19 L90,20 L93,19 L97,21 L100,23',
  },
  {
    id: 'h3', security_id: 's3', account_id: 'a2',
    quantity: 2000, cost_price: 3.80, current_price: 4.12, currency: 'CNY',
    /* 盈利：30 点上行走势（较平缓） */
    sparkline: 'M0,20 L3,19 L7,20 L10,18 L14,19 L17,17 L21,18 L24,16 L28,17 L31,15 L34,16 L38,14 L41,15 L45,13 L48,12 L52,14 L55,11 L59,12 L62,10 L66,11 L69,9 L72,10 L76,8 L79,9 L83,7 L86,8 L90,7 L93,5 L97,6 L100,5',
  },
  {
    id: 'h4', security_id: 's4', account_id: 'a2',
    quantity: 5000, cost_price: 2.50, current_price: 2.68, currency: 'CNY',
    /* 盈利：30 点上行走势（震荡向上） */
    sparkline: 'M0,19 L3,20 L7,18 L10,19 L14,17 L17,18 L21,16 L24,17 L28,15 L31,16 L34,14 L38,15 L41,13 L45,14 L48,12 L52,13 L55,11 L59,12 L62,10 L66,11 L69,9 L72,10 L76,8 L79,9 L83,7 L86,8 L90,6 L93,7 L97,5 L100,5',
  },
  {
    id: 'h5', security_id: 's5', account_id: 'a2',
    quantity: 100, cost_price: 100.00, current_price: 101.20, currency: 'CNY',
    /* 盈利：30 点缓上行（债券低波动） */
    sparkline: 'M0,17 L3,17 L7,18 L10,17 L14,16 L17,17 L21,16 L24,17 L28,15 L31,16 L34,15 L38,16 L41,14 L45,15 L48,14 L52,15 L55,13 L59,14 L62,13 L66,14 L69,12 L72,13 L76,12 L79,11 L83,12 L86,10 L90,11 L93,10 L97,9 L100,9',
  },
  {
    id: 'h6', security_id: 's6', account_id: 'a2',
    quantity: 100, cost_price: 520.00, current_price: 545.00, currency: 'CNY',
    /* 盈利：30 点上行走势 */
    sparkline: 'M0,21 L3,20 L7,19 L10,20 L14,18 L17,17 L21,18 L24,16 L28,15 L31,16 L34,14 L38,13 L41,14 L45,12 L48,11 L52,12 L55,10 L59,9 L62,10 L66,8 L69,7 L72,8 L76,6 L79,5 L83,6 L86,4 L90,5 L93,3 L97,4 L100,2',
  },
];

/* 占位（Task 2 列表页未使用，补于 Task 5/7）
   · TRADES：成交明细（Task 5 交易明细表回填）
   · PRICE_HISTORY：行情历史 K 线（Task 5 行情详情回填）
   · GOALS：止盈止损 / 目标价（Task 7 持仓详情策略回填）
*/
/* ========================================================================
   TRADES — 成交明细（Task 5 持仓详情回填）
   覆盖 buy/sell/dividend/split 四类，关联 holding h1(AAPL) 全生命周期
   · balance_after = 该笔后持有量
   · cashflow 原币：buy/sell 影响现金流(负=流出/正=流入)，dividend 入账 income 账户，split 无现金流
   ======================================================================== */
window.TRADES = [
  /* —— h1 AAPL(USD) 完整生命周期：建仓 → 加仓 → 分红 → 卖出部分 —— */
  { id: 't1',  holding_id: 'h1', security_id: 's1', account_id: 'a1',
    date: '2025-09-15', type: 'buy',      quantity:  30, price: 162.50, fee: 5.00, amount: -4880.00, balance_after:  30,
    note: '建仓 30 股' },
  { id: 't2',  holding_id: 'h1', security_id: 's1', account_id: 'a1',
    date: '2025-11-02', type: 'buy',      quantity:  20, price: 168.00, fee: 5.00, amount: -3365.00, balance_after:  50,
    note: '加仓 20 股' },
  { id: 't3',  holding_id: 'h1', security_id: 's1', account_id: 'a3',
    date: '2025-12-20', type: 'dividend', quantity:  50, price:  0.24, fee: 0,    amount:   12.00, balance_after:  50,
    note: 'Q4 现金股息 $0.24/股 → 分红收入账户' },
  { id: 't4',  holding_id: 'h1', security_id: 's1', account_id: 'a1',
    date: '2026-01-12', type: 'sell',     quantity:  10, price: 178.50, fee: 5.00, amount:  1780.00, balance_after:  40,
    note: '止盈卖出 10 股' },
  { id: 't5',  holding_id: 'h1', security_id: 's1', account_id: 'a3',
    date: '2026-03-15', type: 'dividend', quantity:  40, price:  0.25, fee: 0,    amount:   10.00, balance_after:  40,
    note: 'Q1 现金股息 $0.25/股' },
  { id: 't6',  holding_id: 'h1', security_id: 's1', account_id: 'a1',
    date: '2026-04-08', type: 'buy',      quantity:  10, price: 172.00, fee: 5.00, amount: -1725.00, balance_after:  50,
    note: '回调加仓 10 股' },

  /* —— s2 浦发(CNY) 演示 split 类型 + 亏损样本 —— */
  { id: 't7',  holding_id: 'h2', security_id: 's2', account_id: 'a2',
    date: '2024-08-10', type: 'buy',      quantity: 500, price: 10.50, fee: 5.00, amount: -5255.00, balance_after: 500,
    note: '建仓 500 股' },
  { id: 't8',  holding_id: 'h2', security_id: 's2', account_id: 'a2',
    date: '2024-12-01', type: 'split',    quantity: 500, price: 0,     fee: 0,    amount:    0.00,  balance_after: 1000,
    note: '1 拆 2（成本价同步减半：¥10.50 → ¥5.25）' },
  { id: 't9',  holding_id: 'h2', security_id: 's2', account_id: 'a3',
    date: '2025-06-30', type: 'dividend', quantity: 1000, price: 0.35, fee: 0,    amount:  350.00, balance_after: 1000,
    note: '中期分红 ¥0.35/股' },
  { id: 't10', holding_id: 'h2', security_id: 's2', account_id: 'a2',
    date: '2025-10-20', type: 'buy',      quantity: 200, price: 13.20, fee: 5.00, amount: -2645.00, balance_after: 1200,
    note: '加仓 200 股' },
  { id: 't11', holding_id: 'h2', security_id: 's2', account_id: 'a2',
    date: '2026-02-14', type: 'sell',     quantity: 200, price: 11.80, fee: 5.00, amount: 2355.00, balance_after: 1000,
    note: '止损卖出 200 股' },

  /* —— s6 黄金(CNY) 演示 buy 累积 —— */
  { id: 't12', holding_id: 'h6', security_id: 's6', account_id: 'a2',
    date: '2025-05-20', type: 'buy',      quantity:  50, price: 510.00, fee: 0,   amount: -25500.00, balance_after:  50,
    note: '建仓 50 克' },
  { id: 't13', holding_id: 'h6', security_id: 's6', account_id: 'a2',
    date: '2025-11-11', type: 'buy',      quantity:  50, price: 530.00, fee: 0,   amount: -26500.00, balance_after: 100,
    note: '加仓 50 克' },
];

/* ========================================================================
   PRICE_HISTORY — 行情历史（Task 5 持仓详情回填）
   键 = security_id，值 = { D: 日线近30点, M: 月线近12点, Y: 年线近5点 }
   每段 points: [{t:'YYYY-MM-DD' or label, v: 价格}]，对齐当前价(current_price)
   收益曲线前端按区间聚合(日/月/年)+从 TRADES 推算成本基线
   ======================================================================== */
window.PRICE_HISTORY = {
  /* s1 AAPL(USD) — 当前价 $185，整体上行 */
  s1: {
    D: _series([162.5,164.1,163.8,165.2,166.0,167.4,168.0,167.2,169.5,170.8,171.6,172.4,170.9,171.8,173.2,174.5,173.6,175.0,176.4,178.0,178.5,177.2,179.0,180.5,181.2,182.0,183.4,184.1,184.6,185.0], '2026-05-31'),
    M: _seriesMonthly([162.5,165.0,168.0,170.5,172.4,175.0,177.8,179.0,181.2,183.0,184.1,185.0], '2025-07'),
    Y: [
      { t: '2022', v: 130.0 }, { t: '2023', v: 145.0 },
      { t: '2024', v: 158.5 }, { t: '2025', v: 175.0 },
      { t: '2026', v: 185.0 },
    ],
  },
  /* s2 浦发(CNY) — 当前价 ¥10.85，下行 */
  s2: {
    D: _series([13.20,13.05,12.90,12.85,12.70,12.60,12.45,12.30,12.20,12.10,12.00,11.92,11.85,11.70,11.62,11.50,11.42,11.30,11.22,11.10,11.05,10.98,10.92,10.88,10.85,10.80,10.84,10.86,10.85,10.85], '2026-05-31'),
    M: _seriesMonthly([13.20,12.95,12.70,12.45,12.20,12.00,11.80,11.62,11.42,11.20,11.00,10.85], '2025-07'),
    Y: [
      { t: '2022', v: 9.80 }, { t: '2023', v: 11.20 },
      { t: '2024', v: 12.60 }, { t: '2025', v: 13.20 },
      { t: '2026', v: 10.85 },
    ],
  },
  /* s3 510300 ETF(CNY) — 当前 ¥4.12，缓涨 */
  s3: {
    D: _series([3.80,3.82,3.85,3.84,3.88,3.90,3.92,3.91,3.95,3.98,3.97,4.00,4.02,4.01,4.04,4.06,4.05,4.08,4.10,4.09,4.11,4.12,4.10,4.13,4.12,4.14,4.13,4.15,4.14,4.12], '2026-05-31'),
    M: _seriesMonthly([3.80,3.85,3.90,3.95,3.98,4.00,4.04,4.06,4.08,4.10,4.11,4.12], '2025-07'),
    Y: [{ t: '2022', v: 3.60 },{ t: '2023', v: 3.70 },{ t: '2024', v: 3.75 },{ t: '2025', v: 3.85 },{ t: '2026', v: 4.12 }],
  },
  /* s4 兴全合润(CNY) — 当前 ¥2.68 */
  s4: {
    D: _series([2.50,2.52,2.51,2.54,2.55,2.57,2.56,2.58,2.60,2.59,2.61,2.62,2.64,2.63,2.65,2.66,2.65,2.67,2.68,2.67,2.68,2.69,2.68,2.69,2.70,2.68,2.69,2.68,2.67,2.68], '2026-05-31'),
    M: _seriesMonthly([2.50,2.55,2.58,2.60,2.62,2.64,2.65,2.66,2.67,2.68,2.67,2.68], '2025-07'),
    Y: [{ t: '2022', v: 2.30 },{ t: '2023', v: 2.40 },{ t: '2024', v: 2.45 },{ t: '2025', v: 2.55 },{ t: '2026', v: 2.68 }],
  },
  /* s5 国债(CNY) — 当前 ¥101.20，低波动 */
  s5: {
    D: _series([100.0,100.1,100.2,100.1,100.3,100.4,100.5,100.4,100.6,100.7,100.8,100.7,100.9,101.0,100.9,101.0,101.1,101.2,101.1,101.2,101.3,101.2,101.1,101.2,101.3,101.2,101.1,101.2,101.2,101.2], '2026-05-31'),
    M: _seriesMonthly([100.0,100.3,100.6,100.8,101.0,101.1,101.2,101.2,101.2,101.2,101.2,101.2], '2025-07'),
    Y: [{ t: '2022', v: 99.5 },{ t: '2023', v: 99.8 },{ t: '2024', v: 100.0 },{ t: '2025', v: 100.5 },{ t: '2026', v: 101.2 }],
  },
  /* s6 黄金(CNY) — 当前 ¥545，强上行 */
  s6: {
    D: _series([520.0,522.5,524.0,526.5,528.0,530.5,532.0,534.5,536.0,538.5,540.0,537.5,539.0,541.5,543.0,540.5,542.0,544.5,543.0,545.5,544.0,546.5,545.0,547.5,546.0,544.5,545.0,545.5,545.0,545.0], '2026-05-31'),
    M: _seriesMonthly([520.0,525.0,530.0,532.5,536.0,538.5,540.0,542.5,544.0,545.0,545.5,545.0], '2025-07'),
    Y: [{ t: '2022', v: 410.0 },{ t: '2023', v: 450.0 },{ t: '2024', v: 490.0 },{ t: '2025', v: 520.0 },{ t: '2026', v: 545.0 }],
  },
};

/* ========================================================================
   GOALS — 投资目标（Task 7 投资目标关联回填）
   holding-backed goals：每个 goal 通过 backing_holding_id 关联一条持仓
   · target_cents           目标金额(人民币分)
   · current_market_value_cents  当前关联持仓市值(人民币分折算，mock 与 holdingView 同源)
   · deadline               截止日期(预计达成时间 mock 基线)
   · monthly_contribution_cents  月定投额(可选，用于预计达成推算 mock)
   · status                 超目标 over / 进行中 ontrack / 落后 behind（mock 派生用）
   注：current_market_value_cents 为 mock 快照(对齐 HOLDINGS 当前价)，
       A-flutter 接入真 ⏳D 后由后端按 backing_holding 实时市值推进。
   ======================================================================== */
window.GOALS = [
  /* —— g1 美股养老：超目标(h1 AAPL 市值 ¥67,062.50 vs 目标 ¥60,000)—— */
  { id: 'g1', name: '美股养老',
    backing_holding_id: 'h1',
    target_cents: 6000000,                 /* ¥60,000.00 */
    current_market_value_cents: 6706250,   /* ¥67,062.50 (= 50 × 185 × 7.25) */
    deadline: '2030-12-31',
    monthly_contribution_cents: 200000,    /* ¥2,000/月 */
    note: 'AAPL 长线养老金账户' },
  /* —— g2 沪深定投：进行中(h3 ETF 市值 ¥8,240 vs 目标 ¥30,000，约 27%)—— */
  { id: 'g2', name: '沪深定投',
    backing_holding_id: 'h3',
    target_cents: 3000000,                 /* ¥30,000.00 */
    current_market_value_cents: 824000,    /* ¥8,240.00 (= 2000 × 4.12) */
    deadline: '2028-06-30',
    monthly_contribution_cents: 100000,    /* ¥1,000/月 */
    note: '510300 月定投，宽基底仓' },
  /* —— g3 黄金避险：进行中偏快(h6 市值 ¥54,500 vs 目标 ¥80,000，约 68%)—— */
  { id: 'g3', name: '黄金避险',
    backing_holding_id: 'h6',
    target_cents: 8000000,                 /* ¥80,000.00 */
    current_market_value_cents: 5450000,   /* ¥54,500.00 (= 100 × 545) */
    deadline: '2029-03-31',
    monthly_contribution_cents: 150000,    /* ¥1,500/月 */
    note: 'AU9999 乱世避险仓' },
  /* —— g4 基金成长：落后(h4 市值 ¥13,400 vs 目标 ¥50,000，约 27% 且 deadline 较近)—— */
  { id: 'g4', name: '基金成长',
    backing_holding_id: 'h4',
    target_cents: 5000000,                 /* ¥50,000.00 */
    current_market_value_cents: 1340000,   /* ¥13,400.00 (= 5000 × 2.68) */
    deadline: '2027-09-30',
    monthly_contribution_cents: 80000,     /* ¥800/月（按当前节奏预计落后）*/
    note: '兴全合润主动基金' },
  /* —— g5 银行底仓：落后亏损(h2 市值 ¥10,850 vs 目标 ¥20,000，约 54% 但持仓亏损)—— */
  { id: 'g5', name: '银行底仓',
    backing_holding_id: 'h2',
    target_cents: 2000000,                 /* ¥20,000.00 */
    current_market_value_cents: 1085000,   /* ¥10,850.00 (= 1000 × 10.85) */
    deadline: '2027-06-30',
    monthly_contribution_cents: 0,         /* 暂停定投 */
    note: '浦发浮亏，观察是否止损' },
  /* —— g6 国债稳健：进行中(h5 市值 ¥10,120 vs 目标 ¥15,000，约 67%)—— */
  { id: 'g6', name: '国债稳健',
    backing_holding_id: 'h5',
    target_cents: 1500000,                 /* ¥15,000.00 */
    current_market_value_cents: 1012000,   /* ¥10,120.00 (= 100 × 101.20) */
    deadline: '2028-12-31',
    monthly_contribution_cents: 50000,     /* ¥500/月 */
    note: '24国债09 稳健配置' },
];

/* —— Goal 视图 helper：进度 / 预计达成(mock) / 状态 —— */
window.goalView = function (goalId) {
  var g = window.GOALS.find(function (x) { return x.id === goalId; });
  if (!g) return null;
  var pct = g.target_cents > 0 ? (g.current_market_value_cents / g.target_cents) * 100 : 0;
  pct = Math.max(0, pct);
  /* 状态：>=100 over / 月供节奏推算 deadline 前达成 ontrack / 否则 behind */
  var status;
  if (pct >= 100) {
    status = 'over';
  } else {
    /* 粗略推算：剩余目标 / 月供 → 需要月数 vs 剩余月数 */
    var remainCents = Math.max(0, g.target_cents - g.current_market_value_cents);
    var now = new Date('2026-06-29');
    var dl = new Date(g.deadline);
    var monthsLeft = Math.max(0, (dl.getFullYear() - now.getFullYear()) * 12 + (dl.getMonth() - now.getMonth()));
    var monthsNeeded = g.monthly_contribution_cents > 0 ? remainCents / g.monthly_contribution_cents : Infinity;
    status = monthsNeeded <= monthsLeft ? 'ontrack' : 'behind';
  }
  /* 预计达成时间 mock：以月供推算 eta，封顶 deadline */
  var etaIso;
  if (pct >= 100) {
    etaIso = '已达成';
  } else if (g.monthly_contribution_cents > 0) {
    var remainC = g.target_cents - g.current_market_value_cents;
    var needMonths = Math.max(0, Math.ceil(remainC / g.monthly_contribution_cents));
    var base = new Date('2026-06-29');
    var eta = new Date(base.getFullYear(), base.getMonth() + needMonths, 1);
    etaIso = eta.getFullYear() + '-' + String(eta.getMonth() + 1).padStart(2, '0');
  } else {
    etaIso = '需手动';
  }
  return {
    g: g, pct: pct, status: status, eta: etaIso,
    holding: window.HOLDINGS.find(function (h) { return h.id === g.backing_holding_id; }),
    security: g.backing_holding_id ? window.SECURITIES[(window.HOLDINGS.find(function (h) { return h.id === g.backing_holding_id; }) || {}).security_id] : null,
  };
};

/* —— 内部序列生成 helper（mock-data.js 私有，供 PRICE_HISTORY 用）—— */
function _series(vals, startDate) {
  const base = new Date(startDate);
  return vals.map(function (v, i) {
    const d = new Date(base.getFullYear(), base.getMonth(), base.getDate() + i);
    const iso = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
    return { t: iso, v: v };
  });
}
function _seriesMonthly(vals, startMonth) {
  const parts = startMonth.split('-'); const y = Number(parts[0]); const m0 = Number(parts[1]) - 1;
  return vals.map(function (v, i) {
    const d = new Date(y, m0 + i, 1);
    const iso = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0');
    return { t: iso, v: v };
  });
}

/* 类型元数据 */
window.TYPE_META = {
  stock: { label: '股票', color: '#b08d57' },
  fund:  { label: '基金', color: '#8a6d3b' },
  etf:   { label: 'ETF',  color: '#2d8a6e' },
  bond:  { label: '债券', color: '#6b7a8f' },
  gold:  { label: '黄金', color: '#c9a04a' },
};

/* ---- 格式化 ---- */
window.toCNY = function (amount, currency) {
  const rate = window.RATES[currency] || 1;
  return amount * rate;
};
window.fmtCNY = function (v) {
  return '¥' + Number(v).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};
window.fmtUSD = function (v) {
  return '$' + Number(v).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};
window.fmtRaw = function (v, currency) {
  const sym = currency === 'USD' ? '$' : currency === 'HKD' ? 'HK$' : '¥';
  return sym + Number(v).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};
window.fmtPct = function (v) {
  return (v >= 0 ? '+' : '') + v.toFixed(2) + '%';
};
window.fmtSigned = function (v, currency) {
  const sign = v >= 0 ? '+' : '-';
  const abs = Math.abs(v);
  return sign + window.fmtRaw(abs, currency);
};

/* ---- 单条持仓视图 ---- */
window.holdingView = function (h) {
  const sec = window.SECURITIES[h.security_id];
  const mktVal   = h.quantity * h.current_price;   // 原币
  const cost     = h.quantity * h.cost_price;      // 原币
  const pnl      = mktVal - cost;                  // 原币
  const pnlPct   = cost > 0 ? (pnl / cost) * 100 : 0;
  const mktValCNY = window.toCNY(mktVal, h.currency);
  const costCNY   = window.toCNY(cost, h.currency);
  const pnlCNY    = window.toCNY(pnl, h.currency);
  return { h, sec, mktVal, cost, pnl, pnlPct, mktValCNY, costCNY, pnlCNY, up: pnl >= 0 };
};

/* ---- 总览统计 ---- */
window.computeSummary = function () {
  let totalMktCNY = 0, totalCostCNY = 0;
  window.HOLDINGS.forEach(function (h) {
    const v = window.holdingView(h);
    totalMktCNY  += v.mktValCNY;
    totalCostCNY += v.costCNY;
  });
  const totalPnlCNY = totalMktCNY - totalCostCNY;
  const totalPnlPct = totalCostCNY > 0 ? (totalPnlCNY / totalCostCNY) * 100 : 0;
  return { totalMktCNY, totalCostCNY, totalPnlCNY, totalPnlPct };
};

/* ---- 按 type 聚合配置占比 ---- */
window.computeAllocation = function () {
  const total = window.computeSummary().totalMktCNY;
  const byType = {};
  window.HOLDINGS.forEach(function (h) {
    const v = window.holdingView(h);
    const t = v.sec.type;
    byType[t] = (byType[t] || 0) + v.mktValCNY;
  });
  return Object.keys(window.TYPE_META).map(function (t) {
    const value = byType[t] || 0;
    return {
      type: t,
      label: window.TYPE_META[t].label,
      color: window.TYPE_META[t].color,
      value: value,
      pct: total > 0 ? (value / total) * 100 : 0,
    };
  });
};

/* ---- chips 计数 ---- */
window.computeChips = function () {
  const order = [
    { key: 'all',   label: '全部' },
    { key: 'stock', label: '股票' },
    { key: 'etf',   label: 'ETF' },
    { key: 'fund',  label: '基金' },
    { key: 'bond',  label: '债券' },
    { key: 'gold',  label: '黄金' },
  ];
  return order.map(function (t) {
    const count = t.key === 'all'
      ? window.HOLDINGS.length
      : window.HOLDINGS.filter(function (h) { return window.SECURITIES[h.security_id].type === t.key; }).length;
    return { key: t.key, label: t.label, count: count };
  });
};

/* ---- 多币种汇总（本币 + 各原币种明细）---- */
window.computeCurrencyBreakdown = function () {
  const byCur = {};
  window.HOLDINGS.forEach(function (h) {
    const v = window.holdingView(h);
    byCur[h.currency] = (byCur[h.currency] || 0) + v.mktVal;   // 原币市值合计
  });
  return Object.keys(byCur).map(function (cur) {
    return { currency: cur, value: byCur[cur], valueCNY: window.toCNY(byCur[cur], cur) };
  }).sort(function (a, b) { return b.valueCNY - a.valueCNY; });
};

/* ---- 渲染一段 sparkline SVG（盈绿/亏红）---- */
window.sparkSVG = function (d, up, cls, w, h) {
  const stroke = up ? 'var(--up)' : 'var(--down)';
  const fill   = up ? 'var(--up-soft)' : 'var(--down-soft)';
  w = w || 100; h = h || 28;
  const fillPath = d + ' L100,28 L0,28 Z';
  return ''
    + '<svg class="sparkline ' + (cls || '') + '" viewBox="0 0 100 ' + h + '" width="' + w + '" height="' + h + '" preserveAspectRatio="none">'
    +   '<path d="' + fillPath + '" fill="' + fill + '" fill-opacity="0.5" stroke="none"/>'
    +   '<path d="' + d + '" fill="none" stroke="' + stroke + '" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>'
    + '</svg>';
};

/* lucide 图标内联（统一 1.6 描边、currentColor） */
window.icon = function (name, cls) {
  const c = cls ? ' ' + cls : '';
  const p = 'class="icon' + c + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"';
  const map = {
    'trending-up':   '<path d="M22 7l-8.5 8.5-5-5L2 17"/><path d="M16 7h6v6"/>',
    'trending-down': '<path d="M22 17l-8.5-8.5-5 5L2 7"/><path d="M16 17h6v-6"/>',
    'pie-chart':     '<path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/>',
    'plus':          '<path d="M12 5v14"/><path d="M5 12h14"/>',
    'search':        '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    'chevron-up':    '<path d="m18 15-6-6-6 6"/>',
    'chevron-down':  '<path d="m6 9 6 6 6-6"/>',
    'wallet':        '<path d="M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5"/><path d="M16 12h.01"/>',
    'landmark':      '<line x1="3" x2="21" y1="22" y2="22"/><line x1="6" x2="6" y1="18" y2="11"/><line x1="10" x2="10" y1="18" y2="11"/><line x1="14" x2="14" y1="18" y2="11"/><line x1="18" x2="18" y1="18" y2="11"/><polygon points="12 2 20 7 4 7"/>',
    'gem':           '<path d="M6 3h12l4 6-10 13L2 9Z"/><path d="M11 3 8 9l4 13 4-13-3-6"/><path d="M2 9h20"/>',
    'banknote':      '<rect width="20" height="12" x="2" y="6" rx="2"/><circle cx="12" cy="12" r="2"/><path d="M6 12h.01M18 12h.01"/>',
    'circle-dollar-sign': '<circle cx="12" cy="12" r="10"/><path d="M12 6v12"/><path d="M15 9.5a3 3 0 0 0-3-2.5c-1.66 0-3 .9-3 2s1.34 2 3 2 3 .9 3 2-1.34 2-3 2a3 3 0 0 1-3-2.5"/>',
    'briefcase':     '<rect width="20" height="14" x="2" y="7" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>',
    'grid':          '<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/>',
    'bell':          '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    'user':          '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
    'arrow-up-right': '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
    'arrow-down-right': '<path d="M7 7l10 10"/><path d="M17 7v10H7"/>',
    'percent':       '<line x1="19" x2="5" y1="5" y2="19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>',
    'refresh-cw':    '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M3 21v-5h5"/>',
    /* —— Task 3 交易 Sheet 新增 icon —— */
    'arrow-down-circle': '<circle cx="12" cy="12" r="10"/><path d="M12 8v8"/><path d="m9 13 3 3 3-3"/>',
    'arrow-up-circle':   '<circle cx="12" cy="12" r="10"/><path d="M12 16V8"/><path d="m9 11 3-3 3 3"/>',
    'coins':             '<circle cx="8" cy="8" r="6"/><path d="M18.09 10.37A6 6 0 1 1 10.34 18"/><path d="M7 6h1v4"/><path d="m16.71 13.88.7.71-2.82 2.82"/>',
    'git-merge':         '<circle cx="18" cy="18" r="3"/><circle cx="6" cy="6" r="3"/><path d="M6 21V9a9 9 0 0 0 9 9"/>',
    'x':                 '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    'chevron-right':     '<path d="m9 18 6-6-6-6"/>',
    'chevron-left':      '<path d="m15 18-6-6 6-6"/>',
    'check':             '<path d="M20 6 9 17l-5-5"/>',
    'alert-triangle':    '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    'arrow-right':       '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
    'calendar':          '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    'info':              '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
    /* —— Task 7 投资目标关联 新增 icon —— */
    'target':            '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
    'flag':              '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" x2="4" y1="22" y2="15"/>',
    'link':              '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
    'swap':              '<path d="M16 3l4 4-4 4"/><path d="M20 7H4"/><path d="M8 21l-4-4 4-4"/><path d="M4 17h16"/>',
    'pencil':            '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
    'check-circle':      '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="m9 11 3 3L22 4"/>',
    'x-circle':          '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>',
  };
  return '<svg ' + p + '>' + (map[name] || '') + '</svg>';
};

/* ========================================================================
   Task 5 持仓详情聚合 helpers
   ======================================================================== */

/* 取某 holding 的成交明细(按日期升序) */
window.holdingTrades = function (holdingId) {
  return window.TRADES.filter(function (t) { return t.holding_id === holdingId; })
    .sort(function (a, b) { return a.date < b.date ? -1 : a.date > b.date ? 1 : 0; });
};

/* realized/unrealized 分解（realized = 卖出+分红回笼现金；unrealized = 浮动盈亏）
   返回 { realized, unrealized, totalPnl, realizedPct } 原币 */
window.holdingPnlBreakdown = function (holdingId) {
  const h = window.HOLDINGS.find(function (x) { return x.id === holdingId; });
  if (!h) return { realized: 0, unrealized: 0, totalPnl: 0, realizedPct: 0 };
  const trades = window.holdingTrades(holdingId);
  // realized = sell/dividend 累计金额 + 卖出部分的成本回收(摊销)
  let realized = 0;
  trades.forEach(function (t) {
    if (t.type === 'sell') {
      // 已实现盈亏 = 卖出收入 - 卖出份额 × 当前成本均价(简化：用 cost_price 摊)
      realized += t.amount + Math.abs(t.quantity) * h.cost_price;
    } else if (t.type === 'dividend') {
      realized += t.amount;
    }
  });
  const mktVal = h.quantity * h.current_price;
  const cost   = h.quantity * h.cost_price;
  const unrealized = mktVal - cost;
  const totalPnl = realized + unrealized;
  const realizedPct = totalPnl !== 0 ? (realized / totalPnl) * 100 : 0;
  return { realized: realized, unrealized: unrealized, totalPnl: totalPnl, realizedPct: realizedPct };
};

/* 收益曲线 SVG path 生成（折线 + 面积填充基线）
   pts = [{t,v}], 返回 { line: 'M.. L..', area: '... Z', up: boolean, min, max, last, first } */
window.buildCurve = function (pts) {
  if (!pts || pts.length === 0) return { line: '', area: '', up: false, min: 0, max: 0, last: 0, first: 0 };
  const W = 100, H = 40, pad = 3;
  const vs = pts.map(function (p) { return p.v; });
  const min = Math.min.apply(null, vs);
  const max = Math.max.apply(null, vs);
  const span = (max - min) || 1;
  const n = pts.length;
  const xy = pts.map(function (p, i) {
    const x = (i / (n - 1)) * W;
    const y = H - pad - ((p.v - min) / span) * (H - pad * 2);
    return [x, y];
  });
  const line = xy.map(function (c, i) { return (i === 0 ? 'M' : 'L') + c[0].toFixed(2) + ',' + c[1].toFixed(2); }).join(' ');
  const area = line + ' L' + W + ',' + H + ' L0,' + H + ' Z';
  return { line: line, area: area, up: pts[n - 1].v >= pts[0].v, min: min, max: max, last: pts[n - 1].v, first: pts[0].v };
};

/* 该 holding 占总持仓市值 %（CNY 折算） */
window.holdingAllocationPct = function (holdingId) {
  const total = window.computeSummary().totalMktCNY;
  const h = window.HOLDINGS.find(function (x) { return x.id === holdingId; });
  if (!h || total === 0) return 0;
  return (window.toCNY(h.quantity * h.current_price, h.currency) / total) * 100;
};

/* conic-gradient 字符串(单持仓占比 mini 环图：本持仓 vs 其余) */
window.holdingDonut = function (holdingId) {
  const pct = window.holdingAllocationPct(holdingId);
  const sec = window.SECURITIES[(window.HOLDINGS.find(function (x) { return x.id === holdingId; }) || {}).security_id];
  const color = sec ? window.TYPE_META[sec.type].color : 'var(--gold)';
  const rest = 100 - pct;
  return 'conic-gradient(' + color + ' 0 ' + pct + '%, var(--border) ' + pct + '% 100%)';
};

/* mock：该 holding 关联的 goal 进度(市值 vs 目标额) — Task 7 真实 GOALS 接入前 mock */
window.holdingMockGoal = function (holdingId) {
  const h = window.HOLDINGS.find(function (x) { return x.id === holdingId; });
  if (!h) return null;
  const mktCNY = window.toCNY(h.quantity * h.current_price, h.currency);
  // 按 holding 派生 mock 目标额（演示用，非真数据）
  const targets = {
    h1: { name: '美股长线组合', target: 60000, eta: '2027-06' },
    h2: { name: '银行股底仓',   target: 18000, eta: '2026-12' },
    h6: { name: '黄金避险仓',   target: 40000, eta: '2028-01' },
  };
  const g = targets[holdingId];
  if (!g) return null;
  const pct = Math.min(100, (mktCNY / g.target) * 100);
  return { name: g.name, target: g.target, current: mktCNY, pct: pct, eta: g.eta };
};
