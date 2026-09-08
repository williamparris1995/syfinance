/// F18-T3(spec FR-5,design ADR-5):冲突面板的 per-module **摘要纯函数** ——
/// module + payload JSON bytes → 2-3 关键字段摘要行(`List<String>`,「名称:xxx」
/// 「金额:¥xx.xx」「日期:xx」形态),双栏对照(服务端版本/我的版本)共用。
///
/// 键知识单一事实源 = core/localdb/envelope_codec 的 per-module 行形态
/// (PascalCase 键 / cents 金额 / RFC3339 Z 时间戳);此处只**消费**键不重复
/// 定义映射 —— 上游行形态变化由 formatter 测试的最小 JSON 钉住。
///
/// 容错:坏 payload(null / 空 bytes / 非 JSON / 非 Map / 无已知键)→
/// 「(无法解析)」单行兜底,F17 时代无 payload 的最小冲突面同样收敛于此,
/// 面板不炸。
///
/// 同文件附带两个纯展示辅助(面板共用,测试可注入 now 定断言):
/// - [ConflictFieldFormatter.moduleLabel]:模块 → 中文徽章名;
/// - [ConflictFieldFormatter.relativeTime]:createdAt → 「x 分钟前」。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;

/// 冲突条目摘要 formatter(全静态纯函数,无状态无依赖)。
class ConflictFieldFormatter {
  ConflictFieldFormatter._();

  /// 坏 payload 的兜底单行。
  static const String unparseable = '(无法解析)';

  /// module + payload bytes → 摘要行(2-3 条;全缺 → [unparseable])。
  static List<String> summarize(String module, Uint8List? payload) {
    final row = _decode(payload);
    if (row == null) return const [unparseable];
    final lines = <String>[];
    for (final spec in _specsFor(module)) {
      final value = spec.value(row);
      if (value != null) lines.add('${spec.label}:$value');
    }
    return lines.isEmpty ? const [unparseable] : lines;
  }

  /// 模块 → 中文徽章名(面板条目卡的模块标签)。
  static String moduleLabel(String module) => switch (module) {
        SyncModule.account => '账户',
        SyncModule.transaction => '交易',
        SyncModule.debt => '债务',
        SyncModule.budget => '预算',
        SyncModule.goal => '目标',
        SyncModule.holding => '持仓',
        SyncModule.holdingLedger => '持仓台账',
        SyncModule.tag => '标签',
        SyncModule.template => '模板',
        _ => module, // 值域外防御:回退原串(server 新模块先到时的降级展示)。
      };

  /// createdAt → 相对时间(面板最新序条目的新近感)。[now] 缺省当前时刻
  /// (测试注入定点断言);null → 空串(调用方跳过渲染)。
  static String relativeTime(DateTime? createdAt, {DateTime? now}) {
    if (createdAt == null) return '';
    final base = now ?? DateTime.now();
    final diff = base.difference(createdAt);
    if (diff < const Duration(minutes: 1)) return '刚刚';
    if (diff < const Duration(hours: 1)) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff < const Duration(days: 1)) return '${diff.inHours} 小时前';
    if (diff < const Duration(days: 7)) return '${diff.inDays} 天前';
    // 一周外:本地日期串(yyyy-MM-dd)。
    final iso = createdAt.toLocal().toIso8601String();
    return iso.length >= 10 ? iso.substring(0, 10) : iso;
  }

  // ───────────────── 内部:解码与 per-module 字段选取 ─────────────────

  /// payload bytes → Map;null/空/非 JSON/非 Map → null(容错,不抛)。
  static Map<String, dynamic>? _decode(Uint8List? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// per-module 字段选取表(键名照 envelope_codec 各 rowToEnvelope 形态)。
  static List<_FieldSpec> _specsFor(String module) => switch (module) {
        SyncModule.account => const [
            _TextSpec('名称', 'Name'),
            _MoneySpec('金额', 'CurrentBalanceCents'),
            _DateSpec('日期', 'OpeningDate'),
          ],
        SyncModule.transaction => const [
            _TextSpec('描述', 'Description'),
            // 金额 = 分录借方合计(复式平衡下借方即交易额;分录缺键时
            // 整行跳过,不拼 0)。
            _EntriesAmountSpec('金额', 'Entries'),
            _DateSpec('日期', 'TransactionDate'),
          ],
        SyncModule.debt => const [
            _TextSpec('对方', 'Counterparty'),
            _MoneySpec('金额', 'TotalPrincipalCents'),
            _DateSpec('日期', 'DueDate'),
          ],
        SyncModule.budget => const [
            _TextSpec('名称', 'Name'),
            _MoneySpec('金额', 'TotalAmountCents'),
            _RawSpec('月份', 'Month'),
          ],
        SyncModule.goal => const [
            _TextSpec('名称', 'Name'),
            _MoneySpec('金额', 'TargetAmountCents'),
            _DateSpec('日期', 'Deadline'),
          ],
        SyncModule.holding => const [
            // 持仓头行无名称键(单行形态:账户/证券/数量/成本)。
            _RawSpec('数量', 'Quantity'),
            _MoneySpec('成本', 'AvgCostCents'),
            _DateSpec('日期', 'CreatedAt'),
          ],
        SyncModule.holdingLedger => const [
            _TradeTypeSpec('类型', 'TradeType'),
            _MoneySpec('金额', 'AmountCents'),
            _DateSpec('日期', 'TradeDate'),
          ],
        SyncModule.tag => const [
            _TextSpec('名称', 'Name'),
            _DateSpec('日期', 'UpdatedAt'),
          ],
        SyncModule.template => const [
            _TextSpec('名称', 'Name'),
            _MoneySpec('金额', 'AmountCents'),
            _DateSpec('日期', 'NextDate'),
          ],
        // 未知模块防御:稳定通用键(ID/Name)兜底 —— server 新模块先到时
        // 面板降级展示而非空白。
        _ => const [_RawSpec('ID', 'ID'), _TextSpec('名称', 'Name')],
      };
}

/// 一个摘要字段的渲染规则:标签 + 取值(null = 缺失,调用方跳过该行)。
abstract class _FieldSpec {
  const _FieldSpec(this.label);

  /// 摘要行前缀(「名称」/「金额」/「日期」…)。
  final String label;

  /// 行值;null = 字段缺失/不可渲染。
  String? value(Map<String, dynamic> row);
}

/// 文本键直传(非空 String)。
class _TextSpec extends _FieldSpec {
  const _TextSpec(super.label, this.key);
  final String key;

  @override
  String? value(Map<String, dynamic> row) {
    final v = row[key];
    return v is String && v.isNotEmpty ? v : null;
  }
}

/// cents 金额键 → 「¥xx.xx」(负数带符号)。
class _MoneySpec extends _FieldSpec {
  const _MoneySpec(super.label, this.key);
  final String key;

  @override
  String? value(Map<String, dynamic> row) {
    final v = row[key];
    if (v is! int) return null;
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    return '$sign¥${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }
}

/// RFC3339 时间戳键 → 「yyyy-MM-dd」(摘要不载时刻)。
class _DateSpec extends _FieldSpec {
  const _DateSpec(super.label, this.key);
  final String key;

  @override
  String? value(Map<String, dynamic> row) {
    final v = row[key];
    // envelope 时间戳为 RFC3339 显式 Z;截取日期面。
    if (v is! String || v.length < 10) return null;
    return v.substring(0, 10);
  }
}

/// 原值直传(num/String,如 Quantity/Month)。
class _RawSpec extends _FieldSpec {
  const _RawSpec(super.label, this.key);
  final String key;

  @override
  String? value(Map<String, dynamic> row) {
    final v = row[key];
    return v is num || v is String ? v.toString() : null;
  }
}

/// 交易分录列表 → 借方合计金额(envelope 键 Entries/DebitCents)。
class _EntriesAmountSpec extends _FieldSpec {
  const _EntriesAmountSpec(super.label, this.key);
  final String key;

  @override
  String? value(Map<String, dynamic> row) {
    final v = row[key];
    if (v is! List || v.isEmpty) return null;
    var sum = 0;
    var seen = false;
    for (final e in v) {
      if (e is! Map) continue;
      final debit = e['DebitCents'];
      if (debit is int) {
        sum += debit;
        seen = true;
      }
    }
    if (!seen) return null;
    final abs = sum.abs();
    return '${sum < 0 ? '-' : ''}¥${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }
}

/// 台账交易类型 int 枚举 → 买入/卖出。
class _TradeTypeSpec extends _FieldSpec {
  const _TradeTypeSpec(super.label, this.key);
  final String key;

  @override
  String? value(Map<String, dynamic> row) {
    final v = row[key];
    if (v is! int) return null;
    return switch (v) {
      1 => '买入', // 对齐 drift HoldingTransactions.tradeType 值域(buy=1)。
      2 => '卖出',
      _ => v.toString(), // 值域外防御:原值降级展示。
    };
  }
}
