import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/debt_delete_confirm.dart';
import 'package:yucai_client/core/widgets/debt_detail_widgets.dart';
import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/core/widgets/detail_title_sync.dart';
import 'package:design_kit/design_kit.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/debt/data/contract_attachment_store.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/core/widgets/error_retry_view.dart';

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

class _ReceivableDetailPageState extends State<ReceivableDetailPage>
    with RouteAware {
  List<Account> _accounts = const [];
  bool _recordPending = false;
  // 删除流(muted 淡显钮直达):成功信号是 DebtsLoaded(bloc 删除后刷新
  // 列表态),区别于收款流的 DebtDetailLoaded。
  bool _deletePending = false;
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

  static const _sem = DebtViewSemantics.receivable;

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
    // 订阅 receivables 分支观察者(镜像 debt 详情页 F33 修复):编辑/收款
    // 表单 pop 回本页时 didPopNext 重拉,否则 bloc 状态已被列表态覆盖,
    // 详情停在旧快照。
    receivablesRouteObserver.subscribe(
        this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    // 从编辑/收款表单返回:重拉详情 + 兑现 :47 附件重读注释。
    context.read<DebtBloc>().add(LoadDebtRequested(widget.id));
    _loadAttachment();
  }

  @override
  void dispose() {
    // F58 FR-2:离开详情页清理注入标题(双保险之一;另一道 = AppShell
    // location-diff scrubber)。guarded getIt:stripped 测试 harness 未注册
    // port 时静默跳过(照 app_shell 先例)。
    scheduleDetailTitleClear();
    receivablesRouteObserver.unsubscribe(this);
    super.dispose();
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
    // F58 FR-5:详情页自带 AppBar(面包屑标题条 + 编辑/更多 actions)整条
    // 退役 —— 导航语义移交全局 _TopBar 三段面包屑(page 级可点回退);
    // 原 AppBar actions 全量迁入右下悬浮簇(见 [_dock],零功能丢失)。
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: BlocListener<DebtBloc, DebtState>(
        listenWhen: (p, c) =>
            (_recordPending && (c is DebtDetailLoaded || c is DebtError)) ||
            (_deletePending && (c is DebtsLoaded || c is DebtError)),
        listener: (context, state) {
          if (_deletePending && state is DebtsLoaded) {
            setState(() => _deletePending = false);
            AppToast.show(context, _sem.deletedToast,
                type: ToastType.success);
            context.go(_sem.listRoutePrefix);
            return;
          }
          if (state is DebtDetailLoaded) {
            setState(() => _recordPending = false);
            _loadAccounts();
            AppToast.show(context, _sem.recordSuccessToast,
                type: ToastType.success);
          } else if (state is DebtError) {
            setState(() => _recordPending = false);
            setState(() => _deletePending = false);
            AppToast.show(context, state.message, type: ToastType.error);
          }
        },
        // F58 FR-2 标题注入见 loaded 分支的 [DetailTitleSync](I-1 评审修复:
        // 组件化注入而非 BlocListener —— listener 只吃新 emission,跨分支
        // 回退(bloc 冻结无发射、scrubber 已清零)永不重放 → 标题永停
        // 「…」;组件随 builder 重跑重建,任何路径重加载即重注入)。
        child: Stack(
          children: [
            BlocBuilder<DebtBloc, DebtState>(
              builder: (context, state) {
                if (state is DebtLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is DebtError) {
                  // F63 FR-1:错误态可重试。
                  return ErrorRetryView(
                    message: state.message,
                    onRetry: () =>
                        context.read<DebtBloc>().add(LoadDebtRequested(widget.id)),
                  );
                }
                if (state is DebtDetailLoaded) {
                  return Stack(
                    children: [
                      _body(state.detail),
                      // counterparty 经帧回调幂等注入顶栏当前级;放滚动
                      // 容器外(深滚动时 ListView 子项可能离树,不可依赖)。
                      DetailTitleSync(
                          title: state.detail.debt.counterparty),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // F58 FR-3:右下角常驻竖排悬浮簇(28 边距,不随页面滚动移动;
            // 定位是页面职责 —— 组件自身不含 Positioned,照 design LLD)。
            Positioned(right: 28, bottom: 28, child: _dock()),
          ],
        ),
      ),
    );
  }

  /// F59 FR-2 悬浮簇操作映射(receivable 语义,模型 C' 全平铺三段式,经
  /// [_sem] 双态复用;镜像 debt 详情页,菜单模型退役):
  ///  - primary 收款:打开下期(首个未收期次)确认收款 dialog —— 复用
  ///    [_openRecordPayment],与收款计划行内入口同款 dialog、行为一致;
  ///    无未收期次 → 禁用(操作不缺席,仅降权);
  ///  - secondary 编辑:push `/{listRoutePrefix}/:id/edit`;
  ///  - muted 删除:降饱和淡显常驻钮(hover/焦点恢复亮度),一步直达
  ///    既有 [_confirmDelete] 二次确认弹窗 —— 原「更多」AnchoredMenu
  ///    挂载随菜单退役(F59 FR-2 零菜单零折叠)。
  /// loading/error 态(非 DebtDetailLoaded)恒渲染整簇,全部动作禁用
  /// (FR-3/ADR-4,操作锚点恒定 + 禁用语言)。
  Widget _dock() {
    return BlocBuilder<DebtBloc, DebtState>(
      builder: (context, state) {
        final detail = state is DebtDetailLoaded ? state.detail : null;
        final debt = detail?.debt;
        final schedule = detail?.schedule ?? const <PaymentEntry>[];
        final nextUnpaid = schedule.where((e) => !e.paid).toList();
        return FloatingActionDock(
          primary: DockAction(
            icon: _sem.footCtaIcon,
            tooltip: _sem.footCtaLabel,
            onTap: (debt != null && nextUnpaid.isNotEmpty)
                ? () => _openRecordPayment(nextUnpaid.first)
                : null,
          ),
          secondary: [
            DockAction(
              icon: LucideIcons.pencil,
              tooltip: '编辑',
              onTap: debt != null
                  ? () => context
                      .push('${_sem.listRoutePrefix}/${debt.id}/edit')
                  : null,
            ),
          ],
          muted: [
            DockAction(
              icon: LucideIcons.trash2,
              tooltip: _sem.deleteMenuItem,
              onTap: debt != null ? () => _confirmDelete(debt) : null,
            ),
          ],
        );
      },
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
      attachmentName: _attachment?.originalName,
      onOpenAttachment: _attachment == null ? null : _openAttachment,
    );

    return ListView(
      // F59 FR-3:底部留白 253(spec 下限 = C' 满配簇高 171 [52 主钮 +
      // 2×44 次级 + 3×10 间距 + 分隔线 1] + 底边距 28 + 净空 54,末屏关键
      // 信息(合计/末期)不被遮挡);顶部 12/14 = AppBar 64px 让位后的
      // 呼吸位(≤24)。
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 253)
          : const EdgeInsets.fromLTRB(28, 12, 28, 253),
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

  // ───────────────────── 删除(muted 淡显钮直达) ─────────────────────

  Future<void> _confirmDelete(Debt? debt) async {
    if (debt == null) return;
    final ok = await confirmDeleteDebt(context, _sem, debt.counterparty);
    if (!ok || !mounted) return;
    setState(() => _deletePending = true);
    context.read<DebtBloc>().add(DeleteDebtRequested(debt.id));
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
    if (debt.subtype.isNotEmpty) return context.yucai.accentDeep;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('公司') ||
        debt.counterparty.contains('企业') ||
        debt.counterparty.contains('商') ||
        s.contains('biz') ||
        s.contains('business')) {
      // 商业借款 avatar 蓝 → info 令牌(与 receivables_page 同裁决)。
      return context.yucai.info;
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return context.yucai.positive;
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return context.yucai.negative;
    }
    return context.yucai.muted;
  }
}
