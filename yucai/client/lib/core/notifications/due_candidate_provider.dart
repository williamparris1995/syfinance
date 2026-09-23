/// 读侧候选流(2026-09 到期常显提醒,design ADR-1):
/// watch 触发 → 防抖 500ms → 双源候选 → 挂失过滤(与写侧 scanner 共享
/// [filterActiveCandidates] 同一口径)→ 映射视图 → 广播;管道尾寄宿
/// InboxSyncer.diff 同步收件箱台账。首页提醒条 / 托盘待还行 / 收件箱
/// 待处理区三消费方共此一流(NFR-1 候选零新源)。
library;

import 'dart:async';

import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_syncer.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

/// 读侧候选视图(三消费方共用的展示契约;由 [DueScheduleEntry] 活跃
/// 候选映射而来,携带强类型路由目标供条目直达,spec FR-3/ADR-2)。
class DueCandidateView {
  const DueCandidateView({
    required this.entryKey,
    required this.title,
    required this.amountCents,
    required this.dueDate,
    required this.tier,
    required this.daysLeft,
    required this.target,
  });

  /// 候选唯一键(复写侧 entryId:期次裸 id / cc:acc:yyyy-MM)。
  final String entryKey;

  /// 卡名 / counterparty。
  final String title;

  /// 应还金额(分)。
  final int amountCents;

  /// 到期日(日粒度)。
  final DateTime dueDate;

  /// 紧迫档([DueReminderPolicy.tierFor] 同口径,勿另写一套)。
  final DueTier tier;

  /// 到期日差(负 = 逾期天数;[DueReminderPolicy.daysBetween] 同口径)。
  final int daysLeft;

  /// 直达路由目标(sealed,两源各自构造)。
  final DueTarget target;
}

/// 读侧候选流提供者(design ADR-1):任一 [changeTriggers] 发射 →
/// 防抖 500ms(照 TrayController 既有防抖范式)→ 拉源候选 →
/// [filterActiveCandidates] 共享口径过滤(窗口 + 挂失)→ 映射视图 →
/// 广播;启动时先发一次初始值。管道尾寄宿 [syncer](可空:未接线则
/// 只广播不入箱)。与写侧 scanner 共享 source/dismissal/config,分叉仅
/// 在去重/发送(ADR-1);时钟可注入(照 CreditCardDueSource 先例)。
class DueCandidateProvider {
  DueCandidateProvider({
    this.changeTriggers = const [],
    required this.source,
    required this.dismissalStore,
    required this.configProvider,
    this.syncer,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// 变更触发面(bootstrap 注入 drift watch 流;空 = 仅启动初始值)。
  final List<Stream<void>> changeTriggers;

  /// 双源候选(与写侧 scanner 共享同一实例,NFR-1 候选零新源)。
  final DueScheduleSource source;

  /// 「不再提醒」挂失存储(与 scanner 同一真相)。
  final ReminderDismissalStore dismissalStore;

  /// 每轮刷新重读配置(设置页改提前天数即时生效,不必重建接线)。
  final DueReminderConfig Function() configProvider;

  /// 收件箱同步器(管道尾寄宿;null = 未接线,只广播)。
  final InboxSyncer? syncer;

  final DateTime Function() _now;

  final StreamController<List<DueCandidateView>> _controller =
      StreamController.broadcast();

  List<DueCandidateView> _latest = const [];
  Timer? _debounce;
  final List<StreamSubscription<void>> _subs = [];
  bool _started = false;

  /// 候选广播流(broadcast:banner / 托盘 / 收件箱三消费方共订阅)。
  Stream<List<DueCandidateView>> get stream => _controller.stream;

  /// 最近一次刷新的候选集(消费方免订阅即可同步取值)。
  List<DueCandidateView> get latest => _latest;

  /// 启动:接 watch 订阅 + 立即发一次初始值(消费方首帧有数)。
  Future<void> start() async {
    if (_started) return; // 幂等:重复 start 不双订阅
    _started = true;
    // onError 吞错(照 TrayController 评审 R1):drift watch 吐错若不接管
    // → 未捕获 zone 异常 + 订阅静默死亡;该流失效由后续触发/重启兜底。
    for (final trigger in changeTriggers) {
      _subs.add(trigger.listen(
        (_) => _scheduleRefresh(),
        onError: (Object _) {},
      ));
    }
    await _refresh();
  }

  /// 停止:撤订阅与防抖、关广播流。
  Future<void> dispose() async {
    _debounce?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _started = false;
    await _controller.close();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _refresh);
  }

  Future<void> _refresh() async {
    try {
      final policy = DueReminderPolicy(configProvider());
      final raw = await source.unpaidDueCandidates();
      final dismissed = await dismissalStore.dismissedEntryIds();
      final active = filterActiveCandidates(raw, dismissed,
          policy: policy, today: _now());
      final views = [
        for (final c in active)
          DueCandidateView(
            entryKey: c.entry.id,
            title: c.entry.debtName,
            amountCents: c.entry.totalCents,
            dueDate: c.entry.paymentDate,
            tier: c.tier,
            daysLeft: c.daysLeft,
            target: c.entry.target,
          ),
      ];
      _latest = views;
      _controller.add(views);
      // 管道尾寄宿收件箱 diff(ADR-1);收件箱是附属,失败只降级不影响候选流。
      final syncer = this.syncer;
      if (syncer != null) {
        try {
          await syncer.diff(views);
        } catch (_) {}
      }
    } catch (_) {
      // 源/挂失查询失败:保持旧 latest(fail-safe,下次触发自然重试)。
    }
  }
}
