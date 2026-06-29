/* ============================================================
 * 御财 YuCai · Holding 模块共享 Mock 数据
 * 各界面 HTML <script src="mock-data.js"></script> 复用
 *
 * 用 window.X = ... 形式,便于 HTML 直接 <script> 引用(无构建步骤)
 *
 * 金额一律 cents(整数),与 Rust 后端 Money 一致
 * ============================================================ */

/* —— 证券主数据(4 个跨币种样本)——
 * 覆盖:美股(USD) / A股(CNY) / ETF(CNY) / 黄金(CNY)
 * type: stock | etf | gold | bond | fund */
window.SECURITIES = [
  {id:'s1', symbol:'AAPL',  name:'Apple Inc',    type:'stock', exchange:'NASDAQ', currency:'USD', price_cents:18500},
  {id:'s2', symbol:'600000', name:'浦发银行',     type:'stock', exchange:'SSE',    currency:'CNY', price_cents:1085},
  {id:'s3', symbol:'510300', name:'沪深300ETF',   type:'etf',   exchange:'SSE',    currency:'CNY', price_cents:412},
  {id:'s4', symbol:'GOLD',   name:'纸黄金',       type:'gold',  exchange:'SHFE',   currency:'CNY', price_cents:45200},
];

/* —— 持仓(3 个盈亏样本)——
 * 与 SECURITIES 通过 security_id 关联
 * 盈亏 = (current_price - avg_cost) * quantity
 * s1 盈利 USD(+750 USD), s2 亏损 CNY(-115000 CNY), s3 盈利 CNY(+64000 CNY) */
window.HOLDINGS = [
  {security_id:'s1', quantity:50,   avg_cost_cents:17000, current_price_cents:18500},  // 盈利 USD:  +750.00
  {security_id:'s2', quantity:1000, avg_cost_cents:1200,  current_price_cents:1085},   // 亏损 CNY:  -115000(¥-1150.00)
  {security_id:'s3', quantity:2000, avg_cost_cents:380,   current_price_cents:412},    // 盈利 CNY:  +64000(¥+640.00)
];

/* —— 账户(含 income 类账户,供持仓关联 + 分红入账演示)——
 * category: asset | liability | income | expense(与 accounts-responsive STYLES.kind 对齐)
 * type:     savings | credit | investment | fixed | gold | income | ...
 * 持仓实际归属账户:a2 美股账户(USD 持仓 s1)、a4 A股账户(CNY 持仓 s2/s3) */
window.ACCOUNTS = [
  {id:'a1', name:'招商储蓄',   type:'savings',     currency:'CNY', balance_cents:1285400, category:'asset'},
  {id:'a2', name:'美股账户',   type:'investment',  currency:'USD', balance_cents:25000,   category:'asset'},
  {id:'a3', name:'分红收入',   type:'income',      currency:'CNY', balance_cents:0,       category:'income'},
  // 持仓归属账户(holding 关联用,Task 2/6 持仓列表 + Task 5 交易写入会用):
  {id:'a4', name:'华泰 A股账户', type:'investment', currency:'CNY', balance_cents:456000, category:'asset'},
];

/* —— 交易明细(buy/sell/dividend/split 样本)—— */
// 补于 Task 5(交易页生成时,按持仓回填 buy 记录 + 演示 sell/dividend/split)
window.TRADES = [];

/* —— 价格历史(per-security 日/月 sparkline + 曲线数据)—— */
// 补于 Task 7(趋势页生成时,为每个 security 生成 30 日 / 12 月 OHLC 序列)
window.PRICE_HISTORY = {};

/* —— 持仓 backed goals(holding 抵押/挂钩的目标)—— */
// 补于 Task 7(目标页生成时,联动持仓市值演示进度)
window.GOALS = [];

/* —— 辅助查询函数(各界面共用)—— */
window.holdingBySecurity = function (sid) {
  return window.HOLDINGS.find(h => h.security_id === sid) || null;
};
window.securityById = function (sid) {
  return window.SECURITIES.find(s => s.id === sid) || null;
};
window.accountById = function (aid) {
  return window.ACCOUNTS.find(a => a.id === aid) || null;
};
