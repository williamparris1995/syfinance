import 'dart:async';

import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// F12 T1(spec FR-2,design ADR-2):待同步计数聚合器 —— 把 8 个头表的
/// `watchPending*` 流与墓碑表 watch 流合并为单一 `Stream<int>`(sum)。
///
/// **手写 merge 的理由**(design ADR-2 授权 TDD 定):项目无 rxdart 依赖,
/// SDK 亦无 StreamGroup(仅 dart:async 外的第三方/实验 API);本聚合语义
/// 极简(每源缓存最新值,任一源发射即重算总和),StreamController + N 订阅
/// 十几行即可承载,为此引入新依赖不值。
///
/// **墓碑计入的理由**(spec Grill 定案):用户视角「有 N 条变更待同步」,
/// 删除也是待同步变更(离线删除经墓碑上行,与 pending 头行同批)。
///
/// 发射语义:任一源**每次**发射都重算并 sink(部分源未首发射前按 0 计,
/// 即启动窗口可能先见部分和,随后收敛 —— drift watch 流订阅即发当前值,
/// 该窗口极短;去抖不需要,drift 流本就按事务发射,spec FR-2 已钉)。
///
/// 生命周期:构造即订阅全部源;[dispose] 统一 cancel + 关闭控制器(幂等)。
/// 归属:由 SyncCoordinatorBloc 自建并持有(见 bloc 内接线注释),bloc
/// close 时随之 dispose —— 不走 DI 单例注册,避免「lazySingleton 无人
/// dispose 的悬挂流」(bloc 是唯一消费者,生命周期本就该同宿主)。
class PendingCountWatcher {
  /// 核心构造:注入任意计数源(测试用 fake 流手控;生产走 [forDatabase])。
  PendingCountWatcher(Iterable<Stream<int>> sources) {
    var i = 0;
    for (final source in sources) {
      final index = i++;
      _subs.add(source.listen(
        (count) {
          _latest[index] = count;
          _publish();
        },
        // 计数流异常不向上扩散:drift watch 流仅在库损坏等极端场景出错,
        // 计数是纯展示信号,不应拖垮同步协调器。
        onError: (_, __) {},
      ));
    }
  }

  /// 生产构造:8 个头表 `watchPending*` + 墓碑表 watch,映射为各源计数。
  factory PendingCountWatcher.forDatabase(db.AppDatabase database) =>
      PendingCountWatcher([
        database.accountDao.watchPendingAccounts().map((rows) => rows.length),
        database.transactionDao
            .watchPendingTransactions()
            .map((rows) => rows.length),
        database.debtDao.watchPendingDebts().map((rows) => rows.length),
        database.budgetDao.watchPendingBudgets().map((rows) => rows.length),
        database.goalDao.watchPendingGoals().map((rows) => rows.length),
        database.holdingDao.watchPendingHoldings().map((rows) => rows.length),
        database.tagDao.watchPendingTags().map((rows) => rows.length),
        database.templateDao.watchPendingTemplates().map((rows) => rows.length),
        // 墓碑也是待同步变更(F10 T2;计数口径与 PendingCollector 一致)。
        database.syncTombstoneDao
            .watchAllTombstones()
            .map((rows) => rows.length),
      ]);

  final _controller = StreamController<int>();
  final _subs = <StreamSubscription<int>>[];
  final _latest = <int, int>{};
  bool _disposed = false;

  /// 聚合计数流(sum;任一源发射重算)。单订阅流(唯一消费者是 bloc)。
  Stream<int> get stream => _controller.stream;

  /// 重算并发射当前总和。
  void _publish() {
    if (_disposed) return;
    var sum = 0;
    for (final count in _latest.values) {
      sum += count;
    }
    _controller.add(sum);
  }

  /// 统一退订 + 关闭控制器(幂等;由宿主 bloc close 调用)。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _controller.close();
  }
}
