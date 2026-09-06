import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 御财 debt / receivable 两套页面的「内容语义」配置。
///
/// **设计意图**:list(总览/统计条/卡片/筛选)+ detail(hero/5-stat/schedule/
/// side panel/record dialog)的 **widget 树、布局、间距、样式** 在 debt 与
/// receivable 之间完全一致(镜像);差异只在文案/数据/颜色语义(借入 vs 借出)。
/// 本类把所有「会因借入/借出而不同」的字符串、路由前缀、颜色集中起来,共享
/// widget 接收一个 [DebtViewSemantics] 实例即可同时服务两侧 ——
/// 同一组件实例,不同参数 = 结构样式真正一致。
///
/// - [DebtViewSemantics.receivable] — 别人欠我 / 应收(收款 / 借出 / 债权)
/// - [DebtViewSemantics.debt]       — 我欠别人 / 应付(还款 / 借款 / 债务)
///
/// 颜色语义差异(关键):
///  - **delta / trend**:两侧「剩余减少 = 好 = 绿」同向(还清/收回都在减少剩余),
///    故 trend 配色一致,仅文案「减少/增加」同词。
///  - **累计利息**:receivable = 利息收入 = 绿(收益);debt = 累计还息 = 红(成本)。
///    由 [DebtViewSemantics.interestIncomeColor] 区分。
///  - **待收/待还本金**:receivable 中性;debt 待还本金 = 红(负债压力)。
///    由 [DebtViewSemantics.pendingPrincipalColor] 区分。
///
/// 颜色经 [DebtAmountSemantic] 语义描述符表达(F4-P2:const 语义配置不再持有
/// 静态 Color,消费点 resolve(context) 解析,暗色跟随主题)。

/// debt / receivable 金额强调色语义(F4-P2 context 化载体)。
enum DebtAmountSemantic {
  /// 正向(收益)= context.yucai.positive。
  positive,

  /// 负向(成本 / 负债压力)= context.yucai.negative。
  negative,

  /// 中性(不强调)= null,消费方回落默认 fg。
  neutral;

  /// 解析为具体颜色;neutral → null(调用方回落 context.yucai.fg)。
  Color? resolve(BuildContext context) => switch (this) {
        DebtAmountSemantic.positive => context.yucai.positive,
        DebtAmountSemantic.negative => context.yucai.negative,
        DebtAmountSemantic.neutral => null,
      };
}

class DebtViewSemantics {
  const DebtViewSemantics({
    required this.isReceivable,
    required this.directionLabel,
    required this.listRoutePrefix,
    required this.newRoute,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySub,
    required this.emptyBtn,
    required this.overviewTitle,
    required this.overviewIcon,
    required this.overviewHeading,
    required this.principalLabel,
    required this.remainingLabel,
    required this.remainingShortLabel,
    required this.breakdownInterestLabel,
    required this.progressLabel,
    required this.collectedMetaLabel,
    required this.pendingMetaLabel,
    required this.nextPaymentWord,
    required this.viewPlanLabel,
    required this.pendingPillLabel,
    required this.statCountLabel,
    required this.statCollectedLabel,
    required this.statPendingInterestLabel,
    required this.statOverdueLabel,
    required this.collectedSubEmpty,
    required this.sectionListTitle,
    required this.cardRemainingLabel,
    required this.cardMetaLentLabel,
    required this.cardProgressLabel,
    required this.cardCollectedMetaLabel,
    required this.footNextWord,
    required this.footPendingStateLabel,
    required this.footCtaLabel,
    required this.footCtaIcon,
    required this.editMenuItem,
    required this.deleteMenuItem,
    required this.detailTopCrumb,
    required this.detailHeroKicker,
    required this.detailHeroRemainingLabel,
    required this.detailHeroPaidCountLabel,
    required this.detailHeroPaidProgCollected,
    required this.detailHeroPaidProgRemaining,
    required this.statPrincipalLabel,
    required this.statPaidTotalLabel,
    required this.statPendingTotalLabel,
    required this.statInterestLabel,
    required this.statOverdueTotalLabel,
    required this.statPaidBreakdownPattern,
    required this.statPendingBreakdownPattern,
    required this.interestIncomeColor,
    required this.pendingPrincipalColor,
    required this.scheduleTitle,
    required this.scheduleTitleIcon,
    required this.tableCol1Header,
    required this.tableCol2Header,
    required this.tableCol3Header,
    required this.statusPaidLabel,
    required this.statusPendingLabel,
    required this.statusOverdueLabel,
    required this.sumPaidLabel,
    required this.sumPendingLabel,
    required this.scheduleActionLabel,
    required this.schedulePaidLabel,
    required this.sideCollectionCardTitle,
    required this.sideCollectionIcon,
    required this.sideCollectionToLabel,
    required this.sideReceivableAccountLabel,
    required this.sideRegisterBtnLabel,
    required this.sideRegisterToast,
    required this.sideCounterpartyLabel,
    required this.sideLentDateLabel,
    required this.dialogTitle,
    required this.dialogAmountLabel,
    required this.dialogAccountLabel,
    required this.dialogSubmitLabel,
    required this.recordSuccessToast,
  });

  /// true = receivable(应收/收款);false = debt(应付/还款)。
  final bool isReceivable;
  /// 方向字(用于注释/调试):'receivable' / 'debt'。
  final String directionLabel;
  /// 列表/详情跳转前缀:'/receivables' / '/debts'。
  final String listRoutePrefix;
  /// 新建路由:'/receivables/new' / '/debts/new'。
  final String newRoute;

  // ── 空态 ──
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySub;
  final String emptyBtn;

  // ── 总览卡(ov-top + ov-grid 3-col + ov-foot) ──
  final String overviewTitle;       // 债权总览 / 债务总览
  final IconData overviewIcon;      // handshake / landmark
  /// ov-top 右侧 meta 前缀字:「截至 ... · N 笔在追/在途」的「在追/在途」。
  final String overviewHeading;
  final String principalLabel;       // 总借出本金 / 总借款本金
  final String remainingLabel;       // 剩余应收（本金） / 剩余待还（本金）
  /// 卡片/概览里短形态的剩余标签(用于卡 col2 / 移动端),无括号。
  final String remainingShortLabel;  // 剩余应收 / 剩余本金
  /// ov cell2 breakdown 前缀:「含待收利息 / 含待还利息」。
  final String breakdownInterestLabel;
  /// cell3 进度标题:本金收回进度 / 本金还清进度。
  final String progressLabel;
  /// cell3 meta:已收 / 已还。
  final String collectedMetaLabel;
  /// cell3 meta:待收 / 待还。
  final String pendingMetaLabel;
  /// ov-foot「下次收款/下次还款」词。
  final String nextPaymentWord;
  /// ov-foot CTA:查看收款计划 / 查看还款计划。
  final String viewPlanLabel;
  /// ov-foot 待收/待还 pill。
  final String pendingPillLabel;

  // ── L2 stat strip(4 卡) ──
  final String statCountLabel;            // 债权笔数 / 债务笔数
  final String statCollectedLabel;        // 已收本息 / 累计已还本息
  final String statPendingInterestLabel;  // 待收利息 / 待还利息
  final String statOverdueLabel;          // 逾期应收 / 逾期应付
  /// stat strip 已收 sub「X% 已收回 / 已还」的空态占位。
  final String collectedSubEmpty;

  // ── 区头 + 列表卡 ──
  final String sectionListTitle;    // 债权明细 / 债务清单
  final String cardRemainingLabel;  // 剩余应收 / 剩余本金
  /// 卡 col1 meta「借出 ¥X / 借款 ¥X」前缀。
  final String cardMetaLentLabel;
  /// 卡 progress 标题:收回进度 / 还清进度。
  final String cardProgressLabel;
  /// 卡 col3 已收/已还 meta。
  final String cardCollectedMetaLabel;
  /// 卡 foot callout「下次收款 / 下次还款」。
  final String footNextWord;
  /// 卡 foot callout 待收/待还状态文案。
  final String footPendingStateLabel;  // 待收款 / 待还款
  /// 卡 foot CTA:收款 / 立即记账(receivable 详情侧 CTA = 收款;debt = 立即记账)。
  final String footCtaLabel;
  final IconData footCtaIcon;        // handCoins / penLine
  /// 更多菜单:编辑债权/债务。
  final String editMenuItem;
  /// 更多菜单:删除债权/债务。
  final String deleteMenuItem;

  // ── 详情 topbar 面包屑根标签 ──
  /// receivable「债权管理」/ debt「债务管理」。
  final String detailTopCrumb;

  // ── 详情 hero ──
  final String detailHeroKicker;            // REMAINING RECEIVABLE · 剩余应收 / REMAINING PRINCIPAL · 剩余本金
  final String detailHeroRemainingLabel;    // 剩余应收（本金）/ 剩余本金（本金）
  /// hero delta「已收回 / 已还 N/M 期」词。
  final String detailHeroPaidCountLabel;    // 已收回 / 已还
  /// hero-prog-meta 左侧:已收本金 / 已还本金。
  final String detailHeroPaidProgCollected;
  /// hero-prog-meta 右侧「收回 / 还清 X%」。
  final String detailHeroPaidProgRemaining; // 收回 / 还清

  // ── 详情 5-stat(amount-dimension) ──
  final String statPrincipalLabel;    // 借出本金 / 借款本金
  final String statPaidTotalLabel;    // 已收合计 / 已还合计
  final String statPendingTotalLabel; // 待收合计 / 待还合计
  final String statInterestLabel;     // 累计利息收入 / 累计还息
  final String statOverdueTotalLabel; // 逾期应收 / 逾期应付
  /// 「本金 X + 利息 Y」拆分 sub 模板(占位 {principal}/{interest} 替换)。
  final String statPaidBreakdownPattern;
  final String statPendingBreakdownPattern;
  /// 累计利息 value 色:receivable 正向绿(收入)/ debt 负向红(成本)。
  final DebtAmountSemantic interestIncomeColor;
  /// 待收/待还合计 value 色:receivable 中性 / debt 负向红(负债压力)。
  final DebtAmountSemantic pendingPrincipalColor;

  // ── schedule ──
  final String scheduleTitle;        // 收款计划 / 还款计划
  final IconData scheduleTitleIcon;  // calendarCheck
  final String tableCol1Header;      // 期次 / 收款日 / 期次 / 还款日
  final String tableCol2Header;      // 收回本金 / 应还本金
  final String tableCol3Header;      // 利息收入 / 利息
  final String statusPaidLabel;      // 已收 / 已还
  final String statusPendingLabel;   // 待收 / 待还
  final String statusOverdueLabel;   // 逾期
  final String sumPaidLabel;         // 已收 / 已还(sum-pill)
  final String sumPendingLabel;      // 待收 / 待还(sum-pill)
  final String scheduleActionLabel;  // 确认收款 / 立即记账
  final String schedulePaidLabel;    // 已确认 / 已结清

  // ── side panel ──
  final String sideCollectionCardTitle;   // 收款账户 / 还款账户
  final IconData sideCollectionIcon;      // shieldCheck / wallet
  final String sideCollectionToLabel;     // 收款至 / 还款至
  final String sideReceivableAccountLabel; // 应收账户 / 负债账户
  final String sideRegisterBtnLabel;       // 登记一笔收款 / 登记一笔还款
  final String sideRegisterToast;          // 请在下方收款计划逐期确认收款 / 请在下方还款计划逐期记账
  final String sideCounterpartyLabel;      // 债务人 / 债权方
  final String sideLentDateLabel;          // 借出日期 / 借款日期

  // ── RecordPayment / 确认收款 dialog ──
  final String dialogTitle;          // 确认收款 / 确认记账
  final String dialogAmountLabel;    // 收款金额 / 还款金额
  final String dialogAccountLabel;   // 收款至账户（…）/ 从账户转出（…）
  final String dialogSubmitLabel;    // 确认收款 / 确认记账
  final String recordSuccessToast;   // 已确认收款 / 还款已记账

  /// 详情 hero 右侧 4-tile 的「期数」标签(已收期数 / 已还期数)。
  String get heroPaidPeriodLabel => detailHeroPaidCountLabel; // alias

  static const receivable = DebtViewSemantics(
    isReceivable: true,
    directionLabel: 'receivable',
    listRoutePrefix: '/receivables',
    newRoute: '/receivables/new',
    emptyIcon: LucideIcons.handshake,
    emptyTitle: '还没有债权',
    emptySub: '点击右下角「+」或下方按钮记录第一笔借出款项',
    emptyBtn: '创建债权',
    overviewTitle: '债权总览',
    overviewIcon: LucideIcons.handshake,
    overviewHeading: '在追',
    principalLabel: '总借出本金',
    remainingLabel: '剩余应收（本金）',
    remainingShortLabel: '剩余应收',
    breakdownInterestLabel: '含待收利息',
    progressLabel: '本金收回进度',
    collectedMetaLabel: '已收',
    pendingMetaLabel: '待收',
    nextPaymentWord: '下次收款',
    viewPlanLabel: '查看收款计划',
    pendingPillLabel: '待收',
    statCountLabel: '债权笔数',
    statCollectedLabel: '已收本息',
    statPendingInterestLabel: '待收利息',
    statOverdueLabel: '逾期应收',
    collectedSubEmpty: '暂无',
    sectionListTitle: '债权明细',
    cardRemainingLabel: '剩余应收',
    cardMetaLentLabel: '借出',
    cardProgressLabel: '收回进度',
    cardCollectedMetaLabel: '已收',
    footNextWord: '下次收款',
    footPendingStateLabel: '待收款',
    footCtaLabel: '收款',
    footCtaIcon: LucideIcons.handCoins,
    editMenuItem: '编辑债权',
    deleteMenuItem: '删除债权',
    detailTopCrumb: '债权管理',
    detailHeroKicker: '剩余应收（本金）',
    detailHeroRemainingLabel: '剩余应收（本金）',
    detailHeroPaidCountLabel: '已收回',
    detailHeroPaidProgCollected: '已收本金',
    detailHeroPaidProgRemaining: '收回',
    statPrincipalLabel: '借出本金',
    statPaidTotalLabel: '已收合计',
    statPendingTotalLabel: '待收合计',
    statInterestLabel: '累计利息收入',
    statOverdueTotalLabel: '逾期应收',
    statPaidBreakdownPattern: '本金 {p} + 利息 {i}',
    statPendingBreakdownPattern: '本金 {p} + 利息 {i}',
    interestIncomeColor: DebtAmountSemantic.positive,
    pendingPrincipalColor: DebtAmountSemantic.neutral,
    scheduleTitle: '收款计划',
    scheduleTitleIcon: LucideIcons.calendarCheck,
    tableCol1Header: '期次 / 收款日',
    tableCol2Header: '收回本金',
    tableCol3Header: '利息收入',
    statusPaidLabel: '已收',
    statusPendingLabel: '待收',
    statusOverdueLabel: '逾期',
    sumPaidLabel: '已收',
    sumPendingLabel: '待收',
    scheduleActionLabel: '确认收款',
    schedulePaidLabel: '已确认',
    sideCollectionCardTitle: '收款账户',
    sideCollectionIcon: LucideIcons.shieldCheck,
    sideCollectionToLabel: '收款至',
    sideReceivableAccountLabel: '应收账户',
    sideRegisterBtnLabel: '登记一笔收款',
    sideRegisterToast: '请在下方收款计划逐期确认收款',
    sideCounterpartyLabel: '债务人',
    sideLentDateLabel: '借出日期',
    dialogTitle: '确认收款',
    dialogAmountLabel: '收款金额',
    dialogAccountLabel: '收款至账户（别人还我入账的账户）',
    dialogSubmitLabel: '确认收款',
    recordSuccessToast: '已确认收款',
  );

  static const debt = DebtViewSemantics(
    isReceivable: false,
    directionLabel: 'debt',
    listRoutePrefix: '/debts',
    newRoute: '/debts/new',
    emptyIcon: LucideIcons.landmark,
    emptyTitle: '还没有债务',
    emptySub: '点击右下角「+」或下方按钮创建第一笔债务记录',
    emptyBtn: '创建债务',
    overviewTitle: '债务总览',
    overviewIcon: LucideIcons.landmark,
    overviewHeading: '在途',
    principalLabel: '总借款本金',
    remainingLabel: '剩余待还（本金）',
    remainingShortLabel: '剩余本金',
    breakdownInterestLabel: '含待还利息',
    progressLabel: '本金还清进度',
    collectedMetaLabel: '已还',
    pendingMetaLabel: '待还',
    nextPaymentWord: '下次还款',
    viewPlanLabel: '查看还款计划',
    pendingPillLabel: '待还',
    statCountLabel: '债务笔数',
    statCollectedLabel: '累计已还本息',
    statPendingInterestLabel: '待还利息',
    statOverdueLabel: '逾期应付',
    collectedSubEmpty: '暂无',
    sectionListTitle: '债务清单',
    cardRemainingLabel: '剩余本金',
    cardMetaLentLabel: '借款',
    cardProgressLabel: '还清进度',
    cardCollectedMetaLabel: '已还',
    footNextWord: '下次还款',
    footPendingStateLabel: '待还款',
    footCtaLabel: '立即记账',
    footCtaIcon: LucideIcons.penLine,
    editMenuItem: '编辑债务',
    deleteMenuItem: '删除债务',
    detailTopCrumb: '债务管理',
    detailHeroKicker: '剩余本金（待还）',
    detailHeroRemainingLabel: '剩余本金（待还）',
    detailHeroPaidCountLabel: '已还',
    detailHeroPaidProgCollected: '已还本金',
    detailHeroPaidProgRemaining: '还清',
    statPrincipalLabel: '借款本金',
    statPaidTotalLabel: '已还合计',
    statPendingTotalLabel: '待还合计',
    statInterestLabel: '累计还息',
    statOverdueTotalLabel: '逾期应付',
    statPaidBreakdownPattern: '本金 {p} + 利息 {i}',
    statPendingBreakdownPattern: '本金 {p} + 利息 {i}',
    // debt:累计还息 = 成本 = 红;待还合计 = 负债压力 = 红。
    interestIncomeColor: DebtAmountSemantic.negative,
    pendingPrincipalColor: DebtAmountSemantic.negative,
    scheduleTitle: '还款计划',
    scheduleTitleIcon: LucideIcons.calendarCheck,
    tableCol1Header: '期次 / 还款日',
    tableCol2Header: '应还本金',
    tableCol3Header: '利息',
    statusPaidLabel: '已还',
    statusPendingLabel: '待还',
    statusOverdueLabel: '逾期',
    sumPaidLabel: '已还',
    sumPendingLabel: '待还',
    scheduleActionLabel: '立即记账',
    schedulePaidLabel: '已结清',
    sideCollectionCardTitle: '还款账户',
    sideCollectionIcon: LucideIcons.wallet,
    sideCollectionToLabel: '还款至',
    sideReceivableAccountLabel: '负债账户',
    sideRegisterBtnLabel: '登记一笔还款',
    sideRegisterToast: '请在下方还款计划逐期记账',
    sideCounterpartyLabel: '债权方',
    sideLentDateLabel: '借款日期',
    dialogTitle: '确认记账',
    dialogAmountLabel: '还款金额',
    dialogAccountLabel: '从账户转出（关联 from_account）',
    dialogSubmitLabel: '确认记账',
    recordSuccessToast: '还款已记账',
  );
}

/// 摊还方法中文 label(共享;两侧同词)。
String sharedAmortLabel(AmortizationMethod m) {
  switch (m) {
    case AmortizationMethod.equalPrincipalInterest:
      return '等额本息';
    case AmortizationMethod.equalPrincipal:
      return '等额本金';
    case AmortizationMethod.lumpSum:
      return '一次性归还';
  }
}

/// YYYY-MM-DD(共享)。
String sharedFmtDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
