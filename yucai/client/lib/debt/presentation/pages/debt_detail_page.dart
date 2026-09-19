import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/widgets/debt_detail_widgets.dart';
import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/debt/data/contract_attachment_store.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';

/// 债务详情页 —— 还款语义。
///
/// **结构样式与 [ReceivableDetailPage] 完全一致(镜像)** —— 共享 [DebtDetailHero] /
/// [DebtDetailStatsRow] / [DebtDetailSchedule] / [DebtDetailSidePanel] /
/// [DebtRecordDialog],差异只在内容(文案/数据/颜色)由 [DebtViewSemantics.debt] 注入:
/// 剩余本金 / 还款计划 / 立即记账 / 已还 / 待还 / 债权方 / 借款日期 等。
///
/// debt 专属附录:信用卡债务(subtype==creditCard)追加 信用卡 StatRow
/// (账单日/还款日/额度/利用率,颜色 绿<30/黄<70/红>=70)。receivables 无;不破坏主结构镜像。
///
/// 还款 = RecordPayment 还款语义(我付别人 → from 我的资产账户)。schedule entry
/// 已还 = 绿✓;待还 = 中性;逾期 = 红。
class DebtDetailPage extends StatefulWidget {
  const DebtDetailPage({super.key, required this.id});

  final String id;

  @override
  State<DebtDetailPage> createState() => _DebtDetailPageState();
}

class _DebtDetailPageState extends State<DebtDetailPage> with RouteAware {
  List<Account> _accounts = const [];
  // 全量账户缓存(供信用卡 StatRow 查 credit_card 账户,credit_card 属 liability
  // 不在 _accounts 的 asset 过滤集)。
  List<Account> _allAccounts = const [];
  bool _recordPending = false;
  // 合同文件附件(本地 v1):进页读取,编辑页替换后返回经 didPopNext 重读。
  ContractAttachment? _attachment;

  Future<void> _loadAttachment() async {
    // 测试 harness 可能不注册 GetIt;缺注册 = 无附件,吞错保持页面可用。
    try {
      final a = await getIt<ContractAttachmentStore>().forDebt(widget.id);
      if (mounted) setState(() => _attachment = a);
    } catch (_) {}
  }

  Future<void> _openAttachment() async {
    final a = _attachment;
    if (a == null) return;
    final path = await getIt<ContractAttachmentStore>().absolutePath(a);
    if (!await File(path).exists()) {
      if (mounted) {
        AppToast.show(context, '合同文件不存在(本设备未上传该附件)',
            type: ToastType.warning);
      }
      return;
    }
    try {
      await launchUrl(Uri.file(path));
    } catch (_) {
      if (mounted) {
        AppToast.show(context, '无法打开文件', type: ToastType.warning);
      }
    }
  }

  static const _sem = DebtViewSemantics.debt;

  @override
  void initState() {
    super.initState();
    context.read<DebtBloc>().add(LoadDebtRequested(widget.id));
    _loadAccounts();
    _loadAttachment();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅 debts 分支观察者:编辑/记账表单 pop 回本页时 didPopNext 重拉。
    // 缺此订阅时,bloc 状态已被列表态(DebtsLoaded,更新成功路径的
    // LoadDebtsRequested)覆盖,详情停在旧快照 —— 用户看到「保存了但没变」
    //(F33 验收缺陷根因)。
    debtsRouteObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    // 从编辑/记账表单返回:重拉详情 + 兑现 :56 附件重读注释。
    context.read<DebtBloc>().add(LoadDebtRequested(widget.id));
    _loadAttachment();
  }

  @override
  void dispose() {
    debtsRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final repo = getIt<AccountRepository>();
    final result = await repo.list();
    if (!mounted) return;
    result.fold(
      (_) => null,
      (accounts) => setState(() {
        _allAccounts = accounts;
        _accounts = accounts
            .where((a) =>
                a.accountType == AccountType.asset &&
                a.status == AccountStatus.active)
            .toList();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold();
  }

  Widget _scaffold() {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      appBar: AppBar(
        backgroundColor: context.yucai.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: context.yucai.muted,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        titleSpacing: 28,
        title: BlocBuilder<DebtBloc, DebtState>(
          builder: (context, state) {
            final debt = state is DebtDetailLoaded ? state.detail.debt : null;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () => context.go(_sem.listRoutePrefix),
                child: Text(_sem.detailTopCrumb,
                    style:
                        TextStyle(fontSize: 13, color: context.yucai.muted)),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight,
                  size: 14, color: context.yucai.muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(debt?.counterparty ?? '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.yucai.fg)),
              ),
            ]);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlocBuilder<DebtBloc, DebtState>(
                  builder: (context, state) {
                    final debt = state is DebtDetailLoaded
                        ? state.detail.debt
                        : null;
                    return IconButton(
                      tooltip: '编辑',
                      icon: Icon(LucideIcons.pencil,
                          size: 17, color: context.yucai.muted),
                      style: IconButton.styleFrom(
                        backgroundColor: context.yucai.surface,
                        side: BorderSide(color: context.yucai.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(38, 38),
                      ),
                      onPressed: debt != null
                          ? () => context.push(
                              '${_sem.listRoutePrefix}/${debt.id}/edit')
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '更多',
                  icon: Icon(LucideIcons.moreHorizontal,
                      size: 17, color: context.yucai.muted),
                  style: IconButton.styleFrom(
                    backgroundColor: context.yucai.surface,
                    side: BorderSide(color: context.yucai.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(38, 38),
                  ),
                  onPressed: () => AppToast.show(context, '更多菜单待接入',
                      type: ToastType.warning),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocListener<DebtBloc, DebtState>(
        listenWhen: (p, c) =>
            _recordPending && (c is DebtDetailLoaded || c is DebtError),
        listener: (context, state) {
          if (state is DebtDetailLoaded) {
            setState(() => _recordPending = false);
            _loadAccounts();
            // 跨页广播:还款/标记已还/改日影响账户余额与统计。
            try {
              GetIt.instance<DataRefreshNotifier>().bump();
            } catch (_) {}
            AppToast.show(context, _sem.recordSuccessToast,
                type: ToastType.success);
          } else if (state is DebtError) {
            setState(() => _recordPending = false);
            AppToast.show(context, state.message, type: ToastType.error);
          }
        },
        child: BlocBuilder<DebtBloc, DebtState>(
          builder: (context, state) {
            if (state is DebtLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is DebtError) {
              return Center(child: Text(state.message));
            }
            if (state is DebtDetailLoaded) {
              return _body(state.detail);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _body(DebtDetail detail) {
    final cstate = context.watch<CurrencyBloc>().state;
    final preferred = cstate.preferred;
    final w = MediaQuery.of(context).size.width;
    final isMobile = w <= 720;
    final showSide = w > 1080;
    final debt = detail.debt;
    final paidCount = detail.schedule.where((e) => e.paid).length;
    final total = detail.schedule.length;

    final hero = DebtDetailHero(
      sem: _sem,
      debt: debt,
      preferred: preferred,
      paidCount: paidCount,
      total: total,
      badgeLabel: _badgeLabel(debt),
      avatarColor: _avatarColorFor(debt),
      accountName: _lookupAccountName(debt.accountId),
    );
    // F4-P2:buildDebtDetailStats 语义色经 context.yucai 解析,补 context 形参。
    final stats = DebtDetailStatsRow(
        stats: buildDebtDetailStats(context, detail, preferred, _sem));
    final schedule = DebtDetailSchedule(
      sem: _sem,
      schedule: detail.schedule,
      debt: debt,
      preferred: preferred,
      isMobile: isMobile,
      // debt 无 collection 账户:行内确认不启用 → 一律 dialog fallback(从账户转出)。
      collectionAccountId: debt.collectionAccountId,
      onConfirmInline: (e) => _confirmInline(e, preferred),
      onOpenDialog: _openRecordPayment,
      onEditDate: (e) => _editPaymentDate(e),
      onMarkPaid: (e) => _markEntryPaid(e),
      onMarkPaidBatch: (entries) => _markEntryPaidBatch(entries),
    );
    final side = DebtDetailSidePanel(
      sem: _sem,
      debt: debt,
      preferred: preferred,
      // debt 无固定「还款至」账户字段 → 未设置;负债账户 = debt.accountId。
      collectionName: _lookupAccountName(debt.collectionAccountId),
      collectionTail: _lookupAccountTail(debt.collectionAccountId),
      receivableName: _lookupAccountName(debt.accountId),
      attachmentName: _attachment?.originalName,
      onOpenAttachment: _attachment == null ? null : _openAttachment,
    );

    // debt 专属附录:信用卡 StatRow(only subtype==creditCard)。
    final creditCardRow = (debt.subtype == DebtSubtypes.creditCard)
        ? _CreditCardStats(debt: debt, allAccounts: _allAccounts)
        : const SizedBox.shrink();

    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 60)
          : const EdgeInsets.fromLTRB(28, 0, 28, 70),
      children: [
        if (showSide) ...[
          hero,
          const SizedBox(height: 12),
          stats,
          if (creditCardRow is! SizedBox) ...[
            const SizedBox(height: 12),
            creditCardRow,
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: schedule),
              const SizedBox(width: 18),
              SizedBox(width: 320, child: side),
            ],
          ),
        ] else ...[
          hero,
          const SizedBox(height: 12),
          stats,
          if (creditCardRow is! SizedBox) ...[
            const SizedBox(height: 12),
            creditCardRow,
          ],
          const SizedBox(height: 12),
          schedule,
          const SizedBox(height: 18),
          side,
        ],
      ],
    );
  }

  // ───────────────────────── 记账 (RecordPayment) ─────────────────────────

  void _confirmInline(PaymentEntry e, String preferred) {
    final debt =
        (context.read<DebtBloc>().state as DebtDetailLoaded).detail.debt;
    final from = debt.collectionAccountId!;
    setState(() => _recordPending = true);
    context.read<DebtBloc>().add(RecordPaymentRequested(
          debtId: widget.id,
          scheduleEntryId: e.id,
          fromAccountId: from,
        ));
    AppToast.show(context, '${_sem.recordSuccessToast} ${sharedFmtSymbol(e.totalCents, preferred)}',
        type: ToastType.success);
  }

  /// 批量标记已还:一次确认 → 逐个派发(每个内部自带刷新,最后一致)。
  Future<void> _markEntryPaidBatch(List<PaymentEntry> entries) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('批量标记已还(${entries.length} 期)'),
        content: const Text('所选期次将直接标记为已还，不创建还款交易、'
            '不改动任何账户余额。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('标记已还')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final bloc = context.read<DebtBloc>();
    for (final e in entries) {
      bloc.add(MarkEntryPaidRequested(debtId: widget.id, entryId: e.id));
    }
  }

  /// 标记已还(历史还款,不记账):确认对话框 → MarkEntryPaidRequested。
  Future<void> _markEntryPaid(PaymentEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('标记为已还'),
        content: const Text('该期次将直接标记为已还，不创建还款交易、'
            '不改动任何账户余额。适用于账本建立前就已还清的期次。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('标记已还')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<DebtBloc>().add(MarkEntryPaidRequested(
      debtId: widget.id,
      entryId: e.id,
    ));
  }

  /// 单期改日(Google-Calendar 式):日期选择器 → SetPaymentDateRequested。
  /// 已还期次在组件层不可点;服务端/本地再兜底校验冻结与撞日。
  Future<void> _editPaymentDate(PaymentEntry e) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: e.paymentDate.isAfter(now) ? e.paymentDate : now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '修改还款日期',
    );
    if (picked == null || !mounted) return;
    context.read<DebtBloc>().add(SetPaymentDateRequested(
      debtId: widget.id,
      entryId: e.id,
      // F38:归一化 UTC 零点(日期字段全链一致)。
      paymentDate: DateTime.utc(picked.year, picked.month, picked.day),
    ));
  }

  void _openRecordPayment(PaymentEntry e) {
    final preferred = context.read<CurrencyBloc>().state.preferred;
    showDialog<void>(
      context: context,
      builder: (dctx) => DebtRecordDialog(
        sem: _sem,
        entry: e,
        accounts: _accounts,
        preferred: preferred,
        onSubmit: (fromAccountId) {
          Navigator.pop(dctx);
          setState(() => _recordPending = true);
          context.read<DebtBloc>().add(RecordPaymentRequested(
                debtId: widget.id,
                scheduleEntryId: e.id,
                fromAccountId: fromAccountId,
              ));
        },
      ),
    );
  }

  // ───────────────────────── 账户 / 类型 lookup ─────────────────────────

  String? _lookupAccountName(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in _allAccounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  String? _lookupAccountTail(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in _allAccounts) {
      if (a.id == id && a.cardNumberTail.isNotEmpty) return a.cardNumberTail;
    }
    return null;
  }

  String _badgeLabel(Debt debt) {
    if (debt.subtype.isNotEmpty) {
      final lbl = DebtSubtypes.labels[debt.subtype];
      if (lbl != null) return lbl;
    }
    return _inferBadge(debt.counterparty);
  }

  String _inferBadge(String counterparty) {
    final s = counterparty.toLowerCase();
    if (counterparty.contains('房') || s.contains('mortgage')) return '房贷';
    if (counterparty.contains('车') || s.contains('car')) return '车贷';
    if (counterparty.contains('信用卡') || s.contains('credit')) return '信用卡';
    if (counterparty.contains('亲友') ||
        counterparty.contains('借') ||
        s.contains('friend')) {
      return '亲友借款';
    }
    return '借款';
  }

  Color _avatarColorFor(Debt debt) {
    if (debt.subtype.isNotEmpty) return context.yucai.accentDeep;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('房') || s.contains('mortgage')) {
      return context.yucai.accentDeep;
    }
    if (debt.counterparty.contains('车') || s.contains('car')) {
      return context.yucai.muted;
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return context.yucai.negative;
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('借') ||
        s.contains('friend')) {
      return context.yucai.positive;
    }
    return context.yucai.muted;
  }
}

// ───────────────────────── 信用卡 StatRow(debt 专属附录) ─────────────────────────

/// 信用卡债务额外 StatRow:账单日 / 还款日 / 额度 / 利用率(绿<30/黄<70/红>=70)。
/// receivables 无对应物 —— 5-stat 下方的 debt 专属附录,不参与主结构镜像。
class _CreditCardStats extends StatelessWidget {
  const _CreditCardStats({required this.debt, required this.allAccounts});
  final Debt debt;
  final List<Account> allAccounts;

  @override
  Widget build(BuildContext context) {
    final acct = allAccounts.firstWhere(
      (a) => a.id == debt.accountId,
      orElse: () => _emptyAccount(debt.accountId),
    );
    final billingDay = acct.creditBillingDay;
    final repaymentDay = acct.creditRepaymentDay;
    final limit = acct.creditLimitCents;
    final balance = acct.currentBalanceCents;
    final util = limit > 0 ? (balance / limit).clamp(0.0, 1.0) : null;
    final utilPct = util == null ? null : (util * 100).toStringAsFixed(1);
    final utilColor = _utilizationColor(context, util);
    final preferred = _preferredOf(context);
    final stats = <DebtStatCardData>[
      DebtStatCardData(
        label: '账单日',
        icon: LucideIcons.calendarDays,
        value: billingDay != null ? '每月 $billingDay 日' : '—',
        sub: billingDay != null ? '出账日' : '未设置',
      ),
      DebtStatCardData(
        label: '还款日',
        icon: LucideIcons.calendarClock,
        value: repaymentDay != null ? '每月 $repaymentDay 日' : '—',
        sub: repaymentDay != null ? '到期还款' : '未设置',
      ),
      DebtStatCardData(
        label: '信用额度',
        icon: LucideIcons.creditCard,
        value: limit > 0 ? sharedFmtSymbol(limit, preferred) : '—',
        sub: limit > 0
            ? '尾号 ${acct.cardNumberTail.isEmpty ? "—" : acct.cardNumberTail}'
            : '未设置额度',
      ),
      DebtStatCardData(
        label: '利用率',
        icon: LucideIcons.gauge,
        value: utilPct != null ? '$utilPct%' : '—',
        sub: _utilizationLabel(util),
        valueColor: utilColor,
      ),
    ];
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900;
    return GridView.count(
      key: const ValueKey('creditCardStatsRow'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 2 : 4,
      mainAxisSpacing: 13,
      crossAxisSpacing: 13,
      mainAxisExtent: 140,
      children: [for (final s in stats) _CcStatCard(data: s)],
    );
  }

  String _preferredOf(BuildContext context) {
    final bloc = context.read<CurrencyBloc>();
    return bloc.state.preferred;
  }

  /// 利用率三档语义色:健康绿 / 适中 accent / 偏高红(F4-P2:context 化,
  /// 暗色跟随主题)。
  Color? _utilizationColor(BuildContext context, double? util) {
    if (util == null) return null;
    if (util < 0.30) return context.yucai.positive;
    if (util < 0.70) return context.yucai.accent;
    return context.yucai.negative;
  }

  String _utilizationLabel(double? util) {
    if (util == null) return '未设额度';
    if (util < 0.30) return '使用健康';
    if (util < 0.70) return '使用适中';
    return '使用偏高';
  }

  Account _emptyAccount(String id) => Account(
        id: id,
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.creditCard,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: Ownership.personal,
        status: AccountStatus.active,
      );
}

/// 信用卡 StatRow 单卡(复用 DebtStatCardData;valueColorOverride 支持利用率语义色)。
class _CcStatCard extends StatelessWidget {
  const _CcStatCard({required this.data});
  final DebtStatCardData data;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 13, color: context.yucai.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(data.label,
                    style: TextStyle(
                        fontSize: 11.5, color: context.yucai.muted)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.01,
                color: data.valueColor ?? context.yucai.fg,
                fontFeatures: AppTypography.tabularFigures,
              )),
          const SizedBox(height: 4),
          Text(data.sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: context.yucai.muted,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}
