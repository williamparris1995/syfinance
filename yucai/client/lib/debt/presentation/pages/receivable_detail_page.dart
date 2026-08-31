import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/debt_detail_widgets.dart';
import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';

/// 债权详情页 —— 收款语义。
///
/// **结构样式与 [DebtDetailPage] 完全一致(镜像)** —— 共享 [DebtDetailHero] /
/// [DebtDetailStatsRow] / [DebtDetailSchedule] / [DebtDetailSidePanel] /
/// [DebtRecordDialog],差异只在内容(文案/数据/颜色)由 [DebtViewSemantics.receivable]
/// 注入:剩余应收 / 收款计划 / 确认收款 / 已收 / 待收 / 债务人 / 借出日期 等。
///
/// 确认收款 = RecordPayment 收款语义(别人还我 → to 我的收款账户)。schedule entry
/// 已收 = 绿✓;待收 = 中性;逾期 = 红。
class ReceivableDetailPage extends StatefulWidget {
  const ReceivableDetailPage({super.key, required this.id});

  final String id;

  @override
  State<ReceivableDetailPage> createState() => _ReceivableDetailPageState();
}

class _ReceivableDetailPageState extends State<ReceivableDetailPage> {
  List<Account> _accounts = const [];
  bool _recordPending = false;

  static const _sem = DebtViewSemantics.receivable;

  @override
  void initState() {
    super.initState();
    context.read<DebtBloc>().add(LoadDebtRequested(widget.id));
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final repo = getIt<AccountRepository>();
    final result = await repo.list();
    if (!mounted) return;
    result.fold(
      (_) => null,
      (accounts) => setState(() {
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.muted,
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
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight,
                  size: 14, color: AppColors.muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(debt?.counterparty ?? '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.fg)),
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
                      icon: const Icon(LucideIcons.pencil,
                          size: 17, color: AppColors.muted),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
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
                  icon: const Icon(LucideIcons.moreHorizontal,
                      size: 17, color: AppColors.muted),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
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
    final stats = DebtDetailStatsRow(
        stats: buildDebtDetailStats(detail, preferred, _sem));
    final schedule = DebtDetailSchedule(
      sem: _sem,
      schedule: detail.schedule,
      debt: debt,
      preferred: preferred,
      isMobile: isMobile,
      collectionAccountId: debt.collectionAccountId,
      onConfirmInline: (e) => _confirmInline(e, preferred),
      onOpenDialog: _openRecordPayment,
    );
    final side = DebtDetailSidePanel(
      sem: _sem,
      debt: debt,
      preferred: preferred,
      collectionName: _lookupAccountName(debt.collectionAccountId),
      collectionTail: _lookupAccountTail(debt.collectionAccountId),
      receivableName: _lookupAccountName(debt.accountId),
    );

    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 60)
          : const EdgeInsets.fromLTRB(28, 0, 28, 70),
      children: [
        if (showSide) ...[
          hero,
          const SizedBox(height: 12),
          stats,
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
          const SizedBox(height: 12),
          schedule,
          const SizedBox(height: 18),
          side,
        ],
      ],
    );
  }

  // ───────────────────────── 确认收款 ─────────────────────────

  void _confirmInline(PaymentEntry e, String preferred) {
    final debt =
        (context.read<DebtBloc>().state as DebtDetailLoaded).detail.debt;
    final collection = debt.collectionAccountId!;
    setState(() => _recordPending = true);
    context.read<DebtBloc>().add(RecordPaymentRequested(
          debtId: widget.id,
          scheduleEntryId: e.id,
          fromAccountId: collection,
        ));
    AppToast.show(context, '已确认收款 ${sharedFmtSymbol(e.totalCents, preferred)}',
        type: ToastType.success);
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
        onSubmit: (toAccountId) {
          Navigator.pop(dctx);
          setState(() => _recordPending = true);
          context.read<DebtBloc>().add(RecordPaymentRequested(
                debtId: widget.id,
                scheduleEntryId: e.id,
                fromAccountId: toAccountId,
              ));
        },
      ),
    );
  }

  // ───────────────────────── 账户 / 类型 lookup ─────────────────────────

  String? _lookupAccountName(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in _accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  String? _lookupAccountTail(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in _accounts) {
      if (a.id == id && a.cardNumberTail.isNotEmpty) return a.cardNumberTail;
    }
    return null;
  }

  String _badgeLabel(Debt debt) {
    if (debt.subtype.isNotEmpty) {
      // 资产侧 receivable 用 ReceivableSubtypes label(若 subtype 是 receivable key)。
      // subtype 不可识别时回退推断。
      const labels = ReceivableSubtypes.labels;
      final lbl = labels[debt.subtype];
      if (lbl != null) return lbl;
    }
    return _inferBadge(debt.counterparty);
  }

  String _inferBadge(String counterparty) {
    final s = counterparty.toLowerCase();
    if (counterparty.contains('公司') ||
        counterparty.contains('企业') ||
        counterparty.contains('商') ||
        s.contains('biz') ||
        s.contains('business')) {
      return '商业借款';
    }
    if (counterparty.contains('亲友') ||
        counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return '亲友借款';
    }
    if (counterparty.contains('信用卡') || s.contains('credit')) {
      return '信用卡';
    }
    return '私人借款';
  }

  Color _avatarColorFor(Debt debt) {
    if (debt.subtype.isNotEmpty) return AppColors.accentHover;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('公司') ||
        debt.counterparty.contains('企业') ||
        debt.counterparty.contains('商') ||
        s.contains('biz') ||
        s.contains('business')) {
      return const Color(0xFF3A6695);
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return AppColors.positive;
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return AppColors.negative;
    }
    return AppColors.muted;
  }
}
