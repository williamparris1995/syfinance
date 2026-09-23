/// 收件箱同步器(2026-09 到期常显提醒,design ADR-1/ADR-3):
/// 读侧候选流管道尾的 diff —— 候选进入提醒窗口即入箱(upsert 不重复),
/// 候选消失时查挂失表定态:在表 → dismissed;不在(真还清/跨月滚动/
/// 卡债删除)→ handled。只消费 InboxStore + ReminderDismissalStore,
/// 无 UI 依赖;状态流转仅经此入口(spec FR-6 真相驱动,无手工标态动线)。
library;

import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

class InboxSyncer {
  InboxSyncer({required this.store, required this.dismissalStore});

  final InboxStore store;

  /// 挂失表查询口(ADR-3:消失两因归两态的仲裁依据)。
  final ReminderDismissalStore dismissalStore;

  /// 候选集(已挂失过滤)与收件箱待处理区的 diff(design LLD 伪代码):
  /// - 候在箱无 → 入箱 upsert(state=0);箱有 → 滚动刷新字段。幂等由
  ///   store.upsertActive 内部承接(不存在插 / pending 更 / 已定态不动);
  /// - 箱有候无 → 查挂失表:在 → dismissed(2);不在 → handled(1),
  ///   均写 handledAt(ADR-3,定态不可逆)。
  Future<void> diff(List<DueCandidateView> candidates) async {
    final activeKeys = candidates.map((c) => c.entryKey).toSet();
    final inboxActive = await store.activeEntries();
    for (final c in candidates) {
      await store.upsertActive(
        entryKey: c.entryKey,
        title: c.title,
        amountCents: c.amountCents,
        dueDate: c.dueDate,
        target: c.target,
      );
    }
    final dismissedIds = await dismissalStore.dismissedEntryIds();
    for (final row in inboxActive) {
      if (activeKeys.contains(row.entryKey)) continue;
      await store.settle(
        row.entryKey,
        state: dismissedIds.contains(row.entryKey)
            ? InboxEntryState.dismissed
            : InboxEntryState.handled,
      );
    }
  }
}
