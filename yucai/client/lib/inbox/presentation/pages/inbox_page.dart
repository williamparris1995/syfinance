/// 收件箱页 / 提醒中心(2026-09 到期常显提醒 T4,spec FR-5/FR-7,
/// design ADR-6):两区列表 —— 待处理置顶(state=0,createdAt 升序,最旧
/// 待办优先)/ 历史沉底(handledAt 降序,最新定态优先);条目三态 tag
/// (语义令牌着色);「新增小圆点」= 待处理 && createdAt > lastSeen(仅
/// 待处理区,历史是档案不打点);页面首帧渲染后写 lastSeen(先读后写:
/// 本次打开仍见点,下次打开消失)。状态真相驱动(spec FR-6):本页只读
/// 展示,定态由读侧 syncer 落库,无任何手工标态动线。
///
/// presentation-only:数据经 InboxStore / DueCandidateProvider(design HLD
/// 「inbox 页只依赖 core store + 语义令牌」,不 import 任何 feature 模块);
/// store/provider 可注入(测试),缺省 guarded getIt 解析(照
/// SyncStatusBadge/OfflineBadge 惯例:生产恒注册或可由 AppDatabase 构造,
/// 无 DI 图的测试挂载静默降级为空态)。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';
import 'package:yucai_client/core/theme/app_design.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    this.store,
    this.candidateProvider,
    this.clock,
  });

  /// 台账存储(缺省 guarded getIt:已注册用共享实例,否则由 AppDatabase
  /// 构造 —— InboxStore 是无状态 CRUD 包装,多实例同库无害)。
  final InboxStore? store;

  /// 候选流(缺省 guarded getIt;null = 无 live 刷新,仅首载)。
  final DueCandidateProvider? candidateProvider;

  /// 时钟注入(到期措辞与 lastSeen 写入时刻的测试确定性)。
  final DateTime Function()? clock;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  InboxStore? _store;
  StreamSubscription<List<DueCandidateView>>? _sub;
  late final Future<void> _initialLoad;

  bool _loading = true;
  List<InboxEntry> _pending = const [];
  List<InboxEntry> _history = const [];

  /// 小圆点基准快照:仅首载读取。会话内不重读(本次打开点不消失,
  /// spec FR-5 小圆点 scenario),writeLastSeen 只影响下次打开。
  DateTime? _lastSeen;
  bool _seenMarked = false;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? _resolveStore();
    _subscribe();
    _initialLoad = _reload(refreshSeen: true);
    // lastSeen 写入排在首帧渲染后,且先 await 首载(读先于写,点可见性
    // 基准 _lastSeen 已定格)—— brief 交付物 5 的时序契约。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initialLoad;
      final store = _store;
      if (!mounted || store == null || _seenMarked) return;
      _seenMarked = true;
      await store.writeLastSeen(_now());
    });
  }

  InboxStore? _resolveStore() {
    if (getIt.isRegistered<InboxStore>()) return getIt<InboxStore>();
    if (getIt.isRegistered<AppDatabase>()) return InboxStore(getIt<AppDatabase>());
    return null; // 无 DI 图的测试挂载:静默降级(渲染空态)
  }

  void _subscribe() {
    final provider = widget.candidateProvider ??
        (getIt.isRegistered<DueCandidateProvider>()
            ? getIt<DueCandidateProvider>()
            : null);
    if (provider == null) return;
    _sub = provider.stream.listen((_) => _reload(refreshSeen: false));
  }

  /// 重读台账。流事件触发的重读不刷 _lastSeen(会话内点保持);且先排空
  /// 事件环两轮 —— 广播事件先于管道尾 syncer.diff 的落库链送达(provider
  /// _refresh 内 add 后才 await diff),drift 同步 ffi 的写链在微任务环
  /// 内完成,排两轮后再读即见最新台账。
  Future<void> _reload({required bool refreshSeen}) async {
    final store = _store;
    if (store == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!refreshSeen) {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
    final seen = refreshSeen ? await store.readLastSeen() : _lastSeen;
    final rows = await store.all();
    if (!mounted) return;
    setState(() {
      if (refreshSeen) _lastSeen = seen;
      // store.all() 按 createdAt 升序 → 待处理区序即所得(最旧优先);
      // 历史区重排 handledAt 降序(最新定态优先;handledAt 定态必有,
      // createdAt 兜底防御)。
      _pending = rows
          .where((r) => r.state == InboxEntryState.pending.index)
          .toList();
      _history = rows
          .where((r) => r.state != InboxEntryState.pending.index)
          .toList()
        ..sort((a, b) =>
            (b.handledAt ?? b.createdAt).compareTo(a.handledAt ?? a.createdAt));
      _loading = false;
    });
  }

  bool _isNew(InboxEntry row) =>
      _lastSeen == null || row.createdAt > _lastSeen!.millisecondsSinceEpoch;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// 行点击直达(decodeTarget 强类型分派,ADR-2)。
  void _openTarget(InboxEntry row) {
    final target = decodeTarget(row.targetKind, row.targetId);
    switch (target) {
      case AccountTarget(:final accountId):
        // 直达裁决(偏离简报默认「直开还款对话框」,简报预授权):
        // 跳该账户详情页 /accounts/:id 而非 showCreditCardRepayDialog。
        // 理由:design HLD 明言「inbox 页只依赖 core store + 语义令牌」,
        // 唤对话框需 import account 模块(实体 + 仓储取数 + 对话框组件)
        // 并在本页复制 accounts_page 的取数习惯;还款入口在详情页同样
        // 可达,复用既有路由与取数零新依赖(AGENTS 复用第一)。
        context.go('/accounts/$accountId');
      case DebtTarget(:final debtId):
        context.go('/debts/$debtId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.yucai;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('提醒中心',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: t.fg,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              const SizedBox(height: 4),
              Text('到期提醒台账 · 待办置顶,历史沉底',
                  style: TextStyle(fontSize: 12.5, color: t.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_pending.isEmpty && _history.isEmpty) return _emptyState(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      children: [
        if (_pending.isNotEmpty) ..._section(context, '待处理', _pending),
        if (_history.isNotEmpty) ..._section(context, '历史', _history),
      ],
    );
  }

  List<Widget> _section(BuildContext context, String title, List<InboxEntry> rows) {
    final t = context.yucai;
    return [
      Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xs, right: AppSpacing.xs, bottom: AppSpacing.sm),
        child: Text('$title(${rows.length})',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.muted,
                letterSpacing: 0.4)),
      ),
      for (final row in rows) _entryRow(context, row),
      const SizedBox(height: AppSpacing.md),
    ];
  }

  Widget _entryRow(BuildContext context, InboxEntry row) {
    final t = context.yucai;
    final pending = row.state == InboxEntryState.pending.index;
    final rowWidget = Material(
      color: t.surface,
      borderRadius: AppRadius.smBorder,
      child: InkWell(
        onTap: () => _openTarget(row),
        borderRadius: AppRadius.smBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
          child: Row(
            children: [
              _leading(row, pending),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: t.fg),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '¥${DueReminderPolicy.formatYuan(row.amountCents)}',
                style: TextStyle(
                    fontSize: 13.5,
                    color: t.fg,
                    fontFeatures: AppTypography.tabularFigures),
              ),
              const SizedBox(width: 10),
              _dueText(context, row),
              const SizedBox(width: 10),
              _stateTag(context, row),
            ],
          ),
        ),
      ),
    );
    // 已处理/已挂失:行整体降不透明度(档案感,非可行动)。
    return pending
        ? rowWidget
        : Opacity(opacity: 0.6, child: rowWidget);
  }

  /// 行首:待处理区按新增打点(8px 圆,home_page 资产分解圆点同款);
  /// 其余占位等宽对齐。历史区永不打点(spec 一致性缝 #1)。
  Widget _leading(InboxEntry row, bool pending) {
    final t = context.yucai;
    if (pending && _isNew(row)) {
      return Container(
        key: ValueKey('inboxDot-${row.entryKey}'),
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
      );
    }
    return const SizedBox(width: 8);
  }

  /// 到期措辞:「X 天后到期 / 今日到期 / 逾期 N 天」——差值经
  /// [DueReminderPolicy.daysBetween] 同口径(dueDate 存 yyyy-MM-dd 文本,
  /// 解析为本地日),措辞与 due_banner/policy.compose 保持一字不差;
  /// 逾期用 negative 语义色,其余 muted。
  Widget _dueText(BuildContext context, InboxEntry row) {
    final t = context.yucai;
    final days =
        DueReminderPolicy.daysBetween(_now(), DateTime.parse(row.dueDate));
    final String label;
    if (days < 0) {
      label = '逾期 ${-days} 天';
    } else if (days == 0) {
      label = '今日到期';
    } else {
      label = '$days 天后到期';
    }
    return Text(
      label,
      style: TextStyle(
          fontSize: 12.5,
          color: days < 0 ? t.negative : t.muted,
          fontFeatures: AppTypography.tabularFigures),
    );
  }

  /// 三态 tag:待处理=accent / 已处理=positive / 已挂失=muted;chip 底 =
  /// 同色 12% 透明 + 999 圆角 + (8,3) padding(照 OfflineBadge chip 范式)。
  Widget _stateTag(BuildContext context, InboxEntry row) {
    final t = context.yucai;
    final (label, color) = switch (InboxEntryState.values[row.state]) {
      InboxEntryState.pending => ('待处理', t.accent),
      InboxEntryState.handled => ('已处理', t.positive),
      InboxEntryState.dismissed => ('已挂失', t.muted),
    };
    return Container(
      key: ValueKey('inboxTag-${row.entryKey}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 10.5, color: color)),
    );
  }

  Widget _emptyState(BuildContext context) {
    final t = context.yucai;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: t.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                Icon(LucideIcons.bellOff, size: 26, color: t.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('暂无到期提醒',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('有到期事项会出现在这里,处理完成后自动归档',
              style: TextStyle(color: t.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
