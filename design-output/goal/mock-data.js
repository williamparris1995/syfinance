/* ========================================================================
   御财 · 目标管理 — mock 数据 + helpers（Path B fallback 原型）
   ----------------------------------------------------------------------------
   对照 spec §5.3 / server goal domain(entity.go):
     · GoalType: savings(1) / debt_payoff(2) / investment(3)
     · 字段: TargetAmountCents / CurrentAmountCents / Deadline / LinkedAccountID / IsCompleted
   3 type × 各 2-3 个 goal,覆盖 完成 / 进行中 / 落后 三种状态。
   ----------------------------------------------------------------------------
   API 标注(对照 spec §5.2 RPC):
     ✅ ListGoals / GetGoal / CreateGoal / UpdateGoal / DeleteGoal
     ✅ CloneGoal(DuplicateGoal)
     ⏳ RecordContribution / MarkGoalCompleted      — Phase 1
     ⏳ GetGoalProgressHistory(from,to)             — Phase 2 趋势曲线
   ======================================================================== */

window.GOAL_TYPES = {
  savings:     { key: 'savings',     label: '储蓄目标', icon: 'piggy-bank', color: 'var(--gold)',     chipCls: 't-savings',     desc: '为某笔支出攒钱(应急/买房/教育金)' },
  debt_payoff: { key: 'debt_payoff', label: '债务清偿', icon: 'credit-card', color: 'var(--down)',    chipCls: 't-debt',        desc: '还清某笔债务(信用卡/车贷/学贷)' },
  investment:  { key: 'investment',  label: '投资目标', icon: 'trending-up', color: 'var(--up)',       chipCls: 't-investment',  desc: '资产达到目标市值(AAPL 养老金等)' },
};

/* —— 关联实体(savings/debt_payoff/investment 各自的 backing)—— */
window.ACCOUNTS = [
  { id: 'a1', name: '招行活期',   type: 'checking',  balance_cents: 4820050, currency: 'CNY', number: '6225****1234' },
  { id: 'a2', name: '支付宝储蓄', type: 'savings',   balance_cents: 3201500, currency: 'CNY', number: '余额宝' },
  { id: 'a3', name: '工商定存',   type: 'deposit',   balance_cents: 10000000, currency: 'CNY', number: '3年期' },
  { id: 'a4', name: '美股账户',   type: 'investment', balance_cents: 6706250, currency: 'USD', number: 'IBKR · ¥折算' },
];
window.DEBTS = [
  { id: 'd1', name: '招行信用卡',   subtype: 'credit_card', remaining_principal_cents: 1820000, original_principal_cents: 2800000, currency: 'CNY', apr: 18.0 },
  { id: 'd2', name: '车贷',         subtype: 'auto_loan',   remaining_principal_cents: 0,        original_principal_cents: 12000000, currency: 'CNY', apr: 4.8 },
  { id: 'd3', name: '学贷',         subtype: 'student_loan',remaining_principal_cents: 6500000, original_principal_cents: 8000000, currency: 'CNY', apr: 3.2 },
];
window.HOLDINGS = [
  { id: 'h1', symbol: 'AAPL', name: 'Apple Inc.',      market_value_cents: 13400000, cost_cents: 11000000, currency: 'USD', today_pct: 1.8 },
  { id: 'h2', symbol: '0700', name: '腾讯控股',         market_value_cents: 5000000,  cost_cents: 4200000,  currency: 'HKD', today_pct: 0.9 },
];

/* —— 8 个目标(3 type 混合,完成/进行中/落后)——
   字段对齐 server domain: target_cents / current_cents / deadline / linked (account|debt|holding)
   status 派生:pct>=100 completed / else in_progress / 月供节奏推算落后 → behind
   注:current_cents 为 mock 快照,A-flutter 接真 Phase 1 server 按 backing 实时推进。 */
window.GOALS = [
  /* === savings === */
  { id: 'g1', name: '紧急备用金', type: 'savings',
    target_cents: 6000000, current_cents: 4500000,
    deadline: '2027-06-30', monthly_contribution_cents: 200000,
    linked_account_id: 'a1', note: '6 个月生活费,应急专用',
    created_at: '2025-01-15', icon: 'piggy-bank' },
  { id: 'g2', name: '买房首付', type: 'savings',
    target_cents: 50000000, current_cents: 32000000,
    deadline: '2028-12-31', monthly_contribution_cents: 800000,
    linked_account_id: 'a2', note: '首套房 30% 首付',
    created_at: '2024-06-01', icon: 'home' },
  { id: 'g3', name: '婚礼基金', type: 'savings',
    target_cents: 10000000, current_cents: 10000000,
    deadline: '2026-06-30', monthly_contribution_cents: 0,
    linked_account_id: 'a3', note: '2026 春婚礼,已达成',
    created_at: '2025-03-01', icon: 'heart', completed_at: '2026-06-20' },

  /* === debt_payoff === */
  { id: 'g4', name: '信用卡清偿', type: 'debt_payoff',
    target_cents: 2800000, current_cents: 1820000,
    deadline: '2027-03-31', monthly_contribution_cents: 90000,
    linked_debt_id: 'd1', note: '招行信用卡,18% APR 优先还',
    created_at: '2025-09-01', icon: 'credit-card' },
  { id: 'g5', name: '车贷清零', type: 'debt_payoff',
    target_cents: 12000000, current_cents: 12000000,
    deadline: '2026-05-31', monthly_contribution_cents: 0,
    linked_debt_id: 'd2', note: '2024 车贷,已结清',
    created_at: '2023-06-01', icon: 'car', completed_at: '2026-05-15' },
  { id: 'g6', name: '学贷提前还', type: 'debt_payoff',
    target_cents: 8000000, current_cents: 6500000,
    deadline: '2028-01-31', monthly_contribution_cents: 50000,
    linked_debt_id: 'd3', note: '学贷提前结清省利息',
    created_at: '2025-02-01', icon: 'graduation-cap' },

  /* === investment === */
  { id: 'g7', name: '美股养老', type: 'investment',
    target_cents: 20000000, current_cents: 13400000,
    deadline: '2030-12-31', monthly_contribution_cents: 300000,
    backing_holding_id: 'h1', note: 'AAPL 长线养老金账户',
    created_at: '2024-01-01', icon: 'trending-up' },
  { id: 'g8', name: '港股打新', type: 'investment',
    target_cents: 5000000, current_cents: 5000000,
    deadline: '2026-08-31', monthly_contribution_cents: 0,
    backing_holding_id: 'h2', note: '腾讯底仓,已达目标',
    created_at: '2025-04-01', icon: 'gem', completed_at: '2026-07-10' },
];

/* 手动贡献记录(DetailPage 演示) */
window.CONTRIBUTIONS = {
  g1: [
    { id: 'c1', date: '2026-06-29', amount_cents: 200000, note: '6 月工资结余', source: 'manual' },
    { id: 'c2', date: '2026-05-31', amount_cents: 200000, note: '5 月工资结余', source: 'manual' },
    { id: 'c3', date: '2026-04-30', amount_cents: 200000, note: '4 月工资结余', source: 'manual' },
    { id: 'c4', date: '2026-03-31', amount_cents: 150000, note: '奖金', source: 'manual' },
  ],
};

/* 模板(FormPage 「从模板」快捷) */
window.GOAL_TEMPLATES = [
  { key: 'emergency', name: '应急基金',  type: 'savings',     target_cents: 6000000,  monthly: 200000, icon: 'shield',     desc: '6 个月生活费' },
  { key: 'house',     name: '买房首付',  type: 'savings',     target_cents: 50000000, monthly: 800000, icon: 'home',       desc: '首套房 30%' },
  { key: 'edu',       name: '教育金',    type: 'investment',  target_cents: 30000000, monthly: 300000, icon: 'graduation-cap', desc: '子女教育' },
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
window.fmtPct = function (p) { return (p >= 0 ? '' : '') + p.toFixed(1) + '%'; };

/* 进度环 conic-gradient 字符串(给 .progress-ring 用) */
window.ringGradient = function (pct, statusColor) {
  var p = Math.max(0, Math.min(100, pct));
  return 'conic-gradient(' + statusColor + ' 0 ' + p + '%, var(--border) ' + p + '% 100%)';
};

/* —— goalView:派生 pct / status / eta / daysLeft / linked entity —— */
window.goalView = function (goalId) {
  var g = window.GOALS.find(function (x) { return x.id === goalId; });
  if (!g) return null;
  var pct = g.target_cents > 0 ? (g.current_cents / g.target_cents) * 100 : 0;
  pct = Math.max(0, pct);

  /* completed 优先(g.completed_at 或 pct>=100) */
  var completed = !!g.completed_at || pct >= 100;

  /* 状态:completed / ontrack(月供节奏 deadline 前达成) / behind */
  var status;
  if (completed) {
    status = 'completed';
  } else {
    var remainCents = Math.max(0, g.target_cents - g.current_cents);
    var now = new Date('2026-06-30');
    var dl = new Date(g.deadline);
    var monthsLeft = Math.max(0, (dl.getFullYear() - now.getFullYear()) * 12 + (dl.getMonth() - now.getMonth()));
    var monthsNeeded = g.monthly_contribution_cents > 0 ? remainCents / g.monthly_contribution_cents : Infinity;
    status = (g.monthly_contribution_cents === 0 || monthsNeeded > monthsLeft) ? 'behind' : 'ontrack';
  }

  /* 剩余天数 */
  var daysLeft = Math.max(0, Math.ceil((new Date(g.deadline) - new Date('2026-06-30')) / 86400000));

  /* 预计达成 eta */
  var eta;
  if (completed) {
    eta = '已达成';
  } else if (g.monthly_contribution_cents > 0) {
    var remainC = g.target_cents - g.current_cents;
    var needMonths = Math.max(0, Math.ceil(remainC / g.monthly_contribution_cents));
    var base = new Date('2026-06-30');
    var etaD = new Date(base.getFullYear(), base.getMonth() + needMonths, 1);
    eta = etaD.getFullYear() + '-' + String(etaD.getMonth() + 1).padStart(2, '0');
  } else {
    eta = '需手动';
  }

  /* 关联实体 */
  var linked = null, linkedType = null, linkedLabel = '', linkedValue = '';
  if (g.linked_account_id) {
    var a = window.ACCOUNTS.find(function (x) { return x.id === g.linked_account_id; });
    linked = a; linkedType = 'account';
    linkedLabel = a ? a.name : '账户已删';
    linkedValue = a ? window.fmtCNY(a.balance_cents) : '—';
  } else if (g.linked_debt_id) {
    var d = window.DEBTS.find(function (x) { return x.id === g.linked_debt_id; });
    linked = d; linkedType = 'debt';
    linkedLabel = d ? d.name : '债务已删';
    linkedValue = d ? ('剩 ' + window.fmtCNY(d.remaining_principal_cents)) : '—';
  } else if (g.backing_holding_id) {
    var h = window.HOLDINGS.find(function (x) { return x.id === g.backing_holding_id; });
    linked = h; linkedType = 'holding';
    linkedLabel = h ? (h.symbol + ' · ' + h.name) : '持仓已删';
    linkedValue = h ? window.fmtCNY(h.market_value_cents) : '—';
  }

  return {
    g: g,
    pct: pct,
    status: status,
    completed: completed,
    eta: eta,
    daysLeft: daysLeft,
    typeMeta: window.GOAL_TYPES[g.type],
    linked: linked,
    linkedType: linkedType,
    linkedLabel: linkedLabel,
    linkedValue: linkedValue,
  };
};

/* —— 概览统计(ListPage 顶部)—— */
window.goalStats = function () {
  var total = window.GOALS.length, completed = 0, ontrack = 0, behind = 0;
  var totalCurrent = 0, totalTarget = 0;
  window.GOALS.forEach(function (g) {
    var v = window.goalView(g.id);
    totalCurrent += g.current_cents;
    totalTarget += g.target_cents;
    if (v.completed) completed++;
    else if (v.status === 'ontrack') ontrack++;
    else behind++;
  });
  return {
    total: total, completed: completed, ontrack: ontrack, behind: behind,
    totalCurrent: totalCurrent, totalTarget: totalTarget,
    pct: totalTarget > 0 ? (totalCurrent / totalTarget) * 100 : 0,
  };
};

/* —— 内联 lucide SVG icon helper(与 holding 原型同风格 stroke-width 1.6)—— */
window.ICONS = {
  'target':        '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
  'gem':           '<path d="M6 3h12l4 6-10 13L2 9Z"/><path d="M11 3 8 9l4 13 4-13-3-6"/><path d="M2 9h20"/>',
  'piggy-bank':    '<path d="M19 5c-1.5 0-2.8 1.4-3 2-3.5-1.5-7.5-1-10 1.5C4.4 9.7 4 11 4 12.5c0 1.4.4 2.7 1 3.8L4 19h3l.5-1.5c1 .3 2 .5 3 .5h.5L11 21h3l1-2c1.5-.4 2.9-1.2 4-2.3l2 .3V13l-1-1c.6-1 .9-2 .9-3 0-1.5-.6-3-1.9-4Z"/><circle cx="9" cy="11" r="1"/>',
  'credit-card':   '<rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/>',
  'trending-up':   '<path d="M22 7l-8.5 8.5-5-5L2 17"/><path d="M16 7h6v6"/>',
  'trending-down': '<path d="M22 17l-8.5-8.5-5 5L2 7"/><path d="M16 17h6v-6"/>',
  'plus':          '<path d="M5 12h14"/><path d="M12 5v14"/>',
  'pencil':        '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/>',
  'trash-2':       '<path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/>',
  'copy':          '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
  'check':         '<path d="M20 6 9 17l-5-5"/>',
  'check-circle':  '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="m9 11 3 3L22 4"/>',
  'alert-triangle':'<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" x2="12" y1="9" y2="13"/><line x1="12" x2="12.01" y1="17" y2="17"/>',
  'calendar':      '<rect width="18" height="18" x="3" y="4" rx="2"/><line x1="16" x2="16" y1="2" y2="6"/><line x1="8" x2="8" y1="2" y2="6"/><line x1="3" x2="21" y1="10" y2="10"/>',
  'clock':         '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  'wallet':        '<path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 1 0-4h3"/><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4"/>',
  'banknote':      '<rect width="20" height="12" x="2" y="6" rx="2"/><circle cx="12" cy="12" r="2"/><path d="M6 12h.01M18 12h.01"/>',
  'landmark':      '<line x1="3" x2="21" y1="22" y2="22"/><line x1="6" x2="6" y1="18" y2="11"/><line x1="10" x2="10" y1="18" y2="11"/><line x1="14" x2="14" y1="18" y2="11"/><line x1="18" x2="18" y1="18" y2="11"/><polygon points="12 2 20 7 4 7"/>',
  'flag':          '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" x2="4" y1="22" y2="15"/>',
  'percent':       '<line x1="19" x2="5" y1="5" y2="19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>',
  'chevron-right': '<path d="m9 18 6-6-6-6"/>',
  'chevron-left':  '<path d="m15 18-6-6 6-6"/>',
  'arrow-left':    '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
  'x':             '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  'link':          '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
  'unlink':        '<path d="m18.84 12.25 1.72-1.71h-.02a5.004 5.004 0 0 0-.12-7.07 5.006 5.006 0 0 0-6.95 0l-1.72 1.71"/><path d="m5.17 11.75-1.71 1.71a5.004 5.004 0 0 0 .12 7.07 5.006 5.006 0 0 0 6.95 0l1.71-1.71"/><line x1="8" x2="8" y1="2" y2="5"/><line x1="2" x2="5" y1="8" y2="8"/><line x1="16" x2="16" y1="19" y2="22"/><line x1="22" x2="19" y1="16" y2="16"/>',
  'swap':          '<path d="M16 3h5v5"/><path d="M8 3H3v5"/><path d="M21 3l-7 7"/><path d="M3 21l7-7"/><path d="M16 21h5v-5"/><path d="M8 21H3v-5"/>',
  'refresh-cw':    '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M3 21v-5h5"/>',
  'search':        '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  'home':          '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
  'heart':         '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>',
  'car':           '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>',
  'graduation-cap':'<path d="M22 10v6M2 10l10-5 10 5-10 5z"/><path d="M6 12v5c3 3 9 3 12 0v-5"/>',
  'shield':        '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>',
  'more-horizontal':'<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
  'chevron-down':  '<path d="m6 9 6 6 6-6"/>',
  'info':          '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
  'coins':         '<circle cx="8" cy="8" r="6"/><path d="M18.09 10.37A6 6 0 1 1 10.34 18"/><path d="M7 6h1v4"/><path d="m16.71 13.88.7.71-2.82 2.82"/>',
};
window.icon = function (name, cls) {
  var path = window.ICONS[name] || '';
  return '<svg class="icon ' + (cls || '') + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + path + '</svg>';
};
