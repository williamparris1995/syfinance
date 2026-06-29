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
window.TRADES = [];        // 补于 Task 5
window.PRICE_HISTORY = {}; // 补于 Task 5
window.GOALS = [];         // 补于 Task 7

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
  };
  return '<svg ' + p + '>' + (map[name] || '') + '</svg>';
};
