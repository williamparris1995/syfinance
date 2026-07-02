/* ========================================================================
   御财 · 预算管理 — mock 数据 + helpers(Path B fallback 原型)
   ----------------------------------------------------------------------------
   对照 spec §5 / proto budget/v1/budget.proto:
     · BudgetDTO: name / month(yyyy-MM) / total_amount_cents / currency_code
                  / total_actual_cents / usage_pct(D-budget read-time computed)
     · BudgetItemDTO: account_id / planned_amount_cents / actual_amount_cents / notes
     · BudgetDetailDTO: budget + items + total_actual + total_remaining + usage_pct
   3 个 budget(2026-07),覆盖 超支 / 正常 / 远低于预算 三种状态;另含 1 个 2026-06
   budget 演示月份切换。
   ----------------------------------------------------------------------------
   API 标注(对照 proto BudgetService RPC):
     ✅ ListBudgets(active_only?)                              列表
     ✅ CreateBudget(name, month, currency_code, items[])      新建
     ✅ GetBudget(id) → BudgetDetailDTO                        详情(含 items)
     ✅ GetBudgetByMonth(month) → BudgetDetailDTO              按月直查
     ✅ DeleteBudget(id)                                       删除
     ✅ AddBudgetItem(budget_id, account_id, planned, notes)   加条目
     ✅ RemoveBudgetItem(budget_id, item_id)                   删条目
     ✅ ComputeBudgetActuals(budget_id)                        read-time actuals 计算
     ✅ CloneBudgetToMonth(source_id, target_month, name)      复制到下月
   注:budget 无 UpdateBudget RPC —— 编辑走 Add/RemoveBudgetItem 逐条改。
   ======================================================================== */

window.EXPENSE_ACCOUNTS = [
  { id: 'ea1', name: '餐饮',   type: 'expense', icon: 'utensils' },
  { id: 'ea2', name: '交通',   type: 'expense', icon: 'car' },
  { id: 'ea3', name: '购物',   type: 'expense', icon: 'shopping-bag' },
  { id: 'ea4', name: '日用',   type: 'expense', icon: 'package' },
  { id: 'ea5', name: '房租',   type: 'expense', icon: 'home' },
  { id: 'ea6', name: '水电',   type: 'expense', icon: 'zap' },
  { id: 'ea7', name: '通讯',   type: 'expense', icon: 'phone' },
  { id: 'ea8', name: '保险',   type: 'expense', icon: 'shield' },
  { id: 'ea9', name: '电影',   type: 'expense', icon: 'film' },
  { id: 'ea10',name: '游戏',   type: 'expense', icon: 'gamepad-2' },
  { id: 'ea11',name: '聚餐',   type: 'expense', icon: 'wine' },
];

window.accountById = function (id) {
  return window.EXPENSE_ACCOUNTS.find(function (x) { return x.id === id; }) || null;
};

/* —— 4 个预算(2026-07 × 3 + 2026-06 × 1,超支/正常混合)——
   字段对齐 proto BudgetDTO + items[BudgetItemDTO]。
   total_actual / usage_pct 为 read-time computed(mock 直接给值,真由
   ComputeBudgetActuals RPC 在 server 端按当月 transactions 聚合回填)。 */
window.BUDGETS = [
  /* === 2026-07 === */
  { id: 'b1', name: '日常开销预算', month: '2026-07', currency_code: 'CNY',
    total_amount_cents: 800000, total_actual_cents: 836000, usage_pct: 104.5,
    note: '本月已超支,餐饮 + 购物 两项破预算',
    items: [
      { id: 'i1',  account_id: 'ea1', account_name: '餐饮', planned_amount_cents: 380000, actual_amount_cents: 412000, notes: '外卖为主' },
      { id: 'i2',  account_id: 'ea2', account_name: '交通', planned_amount_cents: 120000, actual_amount_cents: 98000,  notes: '' },
      { id: 'i3',  account_id: 'ea3', account_name: '购物', planned_amount_cents: 150000, actual_amount_cents: 186000, notes: '618 囤货' },
      { id: 'i4',  account_id: 'ea4', account_name: '日用', planned_amount_cents: 150000, actual_amount_cents: 140000, notes: '' },
    ] },

  { id: 'b2', name: '固定支出预算', month: '2026-07', currency_code: 'CNY',
    total_amount_cents: 1500000, total_actual_cents: 1320000, usage_pct: 88.0,
    note: '房租 + 水电 + 通讯 + 保险,基本可控',
    items: [
      { id: 'i5',  account_id: 'ea5', account_name: '房租', planned_amount_cents: 800000, actual_amount_cents: 800000, notes: '押一付三' },
      { id: 'i6',  account_id: 'ea6', account_name: '水电', planned_amount_cents: 100000, actual_amount_cents: 86000,  notes: '夏空调' },
      { id: 'i7',  account_id: 'ea7', account_name: '通讯', planned_amount_cents: 60000,  actual_amount_cents: 58000,  notes: '' },
      { id: 'i8',  account_id: 'ea8', account_name: '保险', planned_amount_cents: 540000, actual_amount_cents: 376000, notes: '年缴分摊' },
    ] },

  { id: 'b3', name: '娱乐预算',     month: '2026-07', currency_code: 'CNY',
    total_amount_cents: 300000, total_actual_cents: 142000, usage_pct: 47.3,
    note: '本月控制良好,剩余可滚存',
    items: [
      { id: 'i9',  account_id: 'ea9',  account_name: '电影', planned_amount_cents: 120000, actual_amount_cents: 58000, notes: '' },
      { id: 'i10', account_id: 'ea10', account_name: '游戏', planned_amount_cents: 100000, actual_amount_cents: 44000, notes: 'Steam 夏促' },
      { id: 'i11', account_id: 'ea11', account_name: '聚餐', planned_amount_cents: 80000,  actual_amount_cents: 40000, notes: '' },
    ] },

  /* === 2026-06(演示月份切换)=== */
  { id: 'b4', name: '六月日常开销', month: '2026-06', currency_code: 'CNY',
    total_amount_cents: 700000, total_actual_cents: 742000, usage_pct: 106.0,
    note: '上月略超,本月下调',
    items: [
      { id: 'i12', account_id: 'ea1', account_name: '餐饮', planned_amount_cents: 320000, actual_amount_cents: 358000, notes: '' },
      { id: 'i13', account_id: 'ea2', account_name: '交通', planned_amount_cents: 100000, actual_amount_cents: 92000,  notes: '' },
      { id: 'i14', account_id: 'ea3', account_name: '购物', planned_amount_cents: 180000, actual_amount_cents: 212000, notes: '' },
      { id: 'i15', account_id: 'ea4', account_name: '日用', planned_amount_cents: 100000, actual_amount_cents: 80000,  notes: '' },
    ] },
];

/* 模板(FormPage「从模板」快捷) */
window.BUDGET_TEMPLATES = [
  { key: 'copy-prev', name: '从上月复制', icon: 'copy',      desc: '复制上月预算结构(走 CloneBudgetToMonth RPC)' },
  { key: 'daily',     name: '日常模板',   icon: 'wallet',    desc: '餐饮 / 交通 / 购物 / 日用 四项' },
  { key: 'fixed',     name: '固定支出',   icon: 'home',      desc: '房租 / 水电 / 通讯 / 保险' },
];

/* —— helpers —— */
window.fmtCNY = function (cents) {
  var v = Math.abs(cents) / 100;
  return '¥' + v.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};
window.fmtCNYShort = function (cents) {
  var v = cents / 100;
  if (Math.abs(v) >= 10000) return '¥' + (v / 10000).toLocaleString('zh-CN', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '万';
  return window.fmtCNY(cents);
};
window.fmtPct = function (p) { return p.toFixed(1) + '%'; };

/* 进度环 conic-gradient(同 goal 原型;超支满格用红,正常按 pct) */
window.ringGradient = function (pct, statusColor) {
  var p = Math.max(0, Math.min(100, pct));
  return 'conic-gradient(' + statusColor + ' 0 ' + p + '%, var(--border) ' + p + '% 100%)';
};

/* —— budgetView:派生 over / remaining / item 占比 —— */
window.budgetView = function (budgetId) {
  var b = window.BUDGETS.find(function (x) { return x.id === budgetId; });
  if (!b) return null;
  var over = b.total_actual_cents > b.total_amount_cents;
  var remaining = b.total_amount_cents - b.total_actual_cents;
  var pctCapped = Math.min(100, b.usage_pct);

  /* per-item 派生:usagePct / remaining / over / share(占 total_actual) */
  var items = (b.items || []).map(function (it) {
    var planned = it.planned_amount_cents;
    var actual = it.actual_amount_cents;
    var itOver = actual > planned;
    var itPct = planned > 0 ? (actual / planned) * 100 : 0;
    var itPctCapped = Math.min(100, itPct);
    var itRemain = planned - actual;
    var share = b.total_actual_cents > 0 ? (actual / b.total_actual_cents) * 100 : 0;
    var acc = window.accountById(it.account_id);
    return {
      it: it,
      acc: acc,
      over: itOver,
      pct: itPct,
      pctCapped: itPctCapped,
      remain: itRemain,
      share: share,
    };
  });

  return {
    b: b,
    over: over,
    remaining: remaining,
    pctCapped: pctCapped,
    status: over ? 'over' : 'normal',
    items: items,
  };
};

/* —— 概览统计(ListPage 顶部 stat-strip,前端从 ListBudgets 聚合)—— */
window.budgetStats = function (month) {
  var list = window.BUDGETS.filter(function (b) { return b.month === month; });
  var total = list.length, overN = 0, normalN = 0;
  var totalAmt = 0, totalAct = 0;
  list.forEach(function (b) {
    totalAmt += b.total_amount_cents;
    totalAct += b.total_actual_cents;
    if (b.total_actual_cents > b.total_amount_cents) overN++; else normalN++;
  });
  return {
    month: month,
    total: total,
    over: overN,
    normal: normalN,
    totalAmount: totalAmt,
    totalActual: totalAct,
    avgUsage: totalAmt > 0 ? (totalAct / totalAmt) * 100 : 0,
  };
};

/* —— 内联 lucide SVG icon helper(与 holding/goal 原型同风格 stroke-width 1.6)—— */
window.ICONS = {
  'wallet':        '<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 1 0-4h3"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',
  'target':        '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
  'pie-chart':     '<path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/>',
  'plus':          '<path d="M5 12h14"/><path d="M12 5v14"/>',
  'pencil':        '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/>',
  'trash-2':       '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/>',
  'copy':          '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
  'check':         '<path d="M20 6 9 17l-5-5"/>',
  'check-circle':  '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="m9 11 3 3L22 4"/>',
  'alert-triangle':'<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" x2="12" y1="9" y2="13"/><line x1="12" x2="12.01" y1="17" y2="17"/>',
  'trending-up':   '<path d="M22 7l-8.5 8.5-5-5L2 17"/><path d="M16 7h6v6"/>',
  'calendar':      '<rect width="18" height="18" x="3" y="4" rx="2"/><line x1="16" x2="16" y1="2" y2="6"/><line x1="8" x2="8" y1="2" y2="6"/><line x1="3" x2="21" y1="10" y2="10"/>',
  'clock':         '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  'percent':       '<line x1="19" x2="5" y1="5" y2="19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>',
  'chevron-right': '<path d="m9 18 6-6-6-6"/>',
  'chevron-left':  '<path d="m15 18-6-6 6-6"/>',
  'chevron-down':  '<path d="m6 9 6 6 6-6"/>',
  'arrow-left':    '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
  'x':             '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  'search':        '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  'refresh-cw':    '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M3 21v-5h5"/>',
  'info':          '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
  'coins':         '<circle cx="8" cy="8" r="6"/><path d="M18.09 10.37A6 6 0 1 1 10.34 18"/><path d="M7 6h1v4"/><path d="m16.71 13.88.7.71-2.82 2.82"/>',
  'banknote':      '<rect width="20" height="12" x="2" y="6" rx="2"/><circle cx="12" cy="12" r="2"/><path d="M6 12h.01M18 12h.01"/>',
  'more-horizontal':'<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
  'link':          '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
  'utensils':      '<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2"/><path d="M7 2v20"/><path d="M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
  'car':           '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>',
  'shopping-bag':  '<path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/>',
  'package':       '<path d="m7.5 4.27 9 5.15"/><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>',
  'home':          '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
  'zap':           '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>',
  'phone':         '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.36 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.34 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/>',
  'shield':        '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>',
  'film':          '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M7 3v18"/><path d="M3 7.5h4"/><path d="M3 12h18"/><path d="M3 16.5h4"/><path d="M17 3v18"/><path d="M17 7.5h4"/><path d="M17 16.5h4"/>',
  'gamepad-2':     '<line x1="6" x2="10" y1="11" y2="11"/><line x1="8" x2="8" y1="9" y2="13"/><line x1="15" x2="15.01" y1="12" y2="12"/><line x1="18" x2="18.01" y1="10" y2="10"/><path d="M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258A4 4 0 0 0 17.32 5z"/>',
  'wine':          '<path d="M8 22h12"/><path d="M16 14v8"/><path d="M12 14v8"/><path d="M3 3h18v5a6 6 0 0 1-6 6 6 6 0 0 1-6-6V3z"/><path d="M9 7v2a3 3 0 0 0 6 0V7"/>',
};
window.icon = function (name, cls) {
  var path = window.ICONS[name] || '';
  return '<svg class="icon ' + (cls || '') + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + path + '</svg>';
};
