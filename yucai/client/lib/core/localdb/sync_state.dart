/// F10 T2(spec FR-3/FR-4,design ADR-2/ADR-4):离线写缓冲的同步状态与
/// 墓碑模块名常量 —— 表定义、DAO、8 个 local DS 与 repo 路由共用的一处
/// 真相,避免裸字符串散落。
library;

import 'package:drift/drift.dart' show Value;

/// 8 头表 `sync_state` 列值域(ADR-2)。
class SyncState {
  SyncState._();

  /// 已同步:guest 写入行(无上行语义)/ 绑定镜像行 / 上行成功回写。
  static const synced = 'synced';

  /// 待上行:绑定态离线或降级写(spec FR-1b),回网由 T3 收集器上行。
  static const pending = 'pending';
}

/// 墓碑表 `module` 取值(ADR-4):与 [MirrorModule](binding/data) 枚举名
/// 逐字一致 —— core 层不 import binding(依赖方向),以常量对齐,T3 收集
/// 器按此过滤。
///
/// F17-T2 增 [holdingLedger]:第 9 个 entityType(append-only 持仓台账行,
/// ADR-4 台账查证裁决=实施)。**它不是 MirrorModule 成员**(前 8 常量的
/// 逐字一致契约只覆盖 8 头表模块):台账行的镜像刷新随 holding 模块整体
/// 走(mirror `_refreshHoldings` 含 holdings+transactions+securities),
/// 协调器按模块刷新时把它映射回 holding;墓碑面不适用(台账无本地删除
/// 路径,见 collector 注释)。
class SyncModule {
  SyncModule._();

  static const account = 'account';
  static const transaction = 'transaction';
  static const debt = 'debt';
  static const budget = 'budget';
  static const goal = 'goal';
  static const holding = 'holding';
  static const tag = 'tag';
  static const template = 'template';

  /// 持仓台账行(F17-T2):非 MirrorModule 成员(见类 doc)。
  static const holdingLedger = 'holding_ledger';
}

/// local DS 写路径的 syncState 取值:markPending=true(boundOfflineLocal /
/// 降级分支显式传入)→ pending;false(guest 分支缺省)→ synced。
/// 显式写值而非 Value.absent(),让列默认只服务旧库迁移回填一路。
Value<String> syncStateValue(bool markPending) =>
    Value(markPending ? SyncState.pending : SyncState.synced);

/// F19-T1(2026-09-11):markXSynced 家族 OR 守卫的分片上限 —— SQLite 解析器
/// 对深嵌套 OR 表达式栈溢出(实测 200 对 (id,version) 即 parser stack
/// overflow),50 对/句留足余量。分片循环净效果等价(同守卫同条件逐句执行,
/// 影响行数求和)。绑定合并链 200 条/批回写(F19 ADR-3)由此支撑;协调器
/// 大离线批次同样受益。
const int syncWritebackChunkSize = 50;

/// 顺序切片迭代(不重不漏;[size] ≤0 防御按 1)。
Iterable<List<T>> chunked<T>(Iterable<T> items, int size) sync* {
  final s = size <= 0 ? 1 : size;
  var buf = <T>[];
  for (final item in items) {
    buf.add(item);
    if (buf.length >= s) {
      yield buf;
      buf = <T>[];
    }
  }
  if (buf.isNotEmpty) yield buf;
}
