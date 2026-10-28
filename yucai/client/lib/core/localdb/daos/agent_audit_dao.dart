import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/agent_audit_table.dart';

part 'agent_audit_dao.g.dart';

/// F71(spec FR-1/FR-3 查询面,design ADR-2/ADR-3)agent_audit DAO:
/// append-only 写入 + 倒序分页读(对话框「加载更多」式,20/页家法)。
/// 消费方:`AgentAuditSinkImpl`(写,assistant/data)+ 审计对话框(T2,
/// watchPage/count)。**不参与 sync/备份**(表头注排除面)。
///
/// F72(spec FR-2,design ADR-1):watchPage/count 增 `keyword?` ——
/// summary LIKE '%kw%' 子串过滤(SQLite 方言,ASCII 大小写不敏感是
/// LIKE 默认语义,中文精确)。null/空白 = 全量(既有查询面零扰动)。
@DriftAccessor(tables: [AgentAudits])
class AgentAuditDao extends DatabaseAccessor<AppDatabase>
    with _$AgentAuditDaoMixin {
  AgentAuditDao(super.db);

  /// 追加一行审计留痕(自增 id 由库分配;返回新行 id)。
  Future<int> insertEvent(AgentAuditsCompanion entry) =>
      into(agentAudits).insert(entry);

  /// 总条数(入口行 badge;空态判定)。
  ///
  /// [keyword] 非 null 且非空白时按 summary LIKE 过滤计数(与
  /// [watchPage] 同口径);空串/纯空白等同未传。
  Future<int> count({String? keyword}) async {
    final kw = _normalize(keyword);
    if (kw == null) {
      return agentAudits.count().getSingle();
    }
    final countExpr = agentAudits.id.count();
    final query = selectOnly(agentAudits)
      ..addColumns([countExpr])
      ..where(_summaryContains(kw));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// 时间倒序一页(createdMillis DESC,id DESC 同毫秒次锚;
  /// [limit] 页大小,[offset] 偏移 —— 首页 0,「加载更多」累加)。
  ///
  /// [keyword] 非 null 且非空白时只回 summary LIKE 命中行(offset 相对
  /// matched 集);null/空白 = 全量。
  Stream<List<AgentAudit>> watchPage(
      {int limit = 20, int offset = 0, String? keyword}) {
    final kw = _normalize(keyword);
    final query = select(agentAudits)
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdMillis),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit, offset: offset);
    if (kw != null) {
      query.where((t) => _summaryContains(kw));
    }
    return query.watch();
  }

  /// keyword 归一:trim;null/空串 → null(= 不过滤)。
  static String? _normalize(String? keyword) {
    if (keyword == null) return null;
    final trimmed = keyword.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// summary LIKE '%kw%'(F72 ADR-1):%/_/\ 在 kw 内按字面转义
  /// (LIKE ESCAPE '\' 方言),再裹 % 通配做子串匹配。
  Expression<bool> _summaryContains(String keyword) {
    final escaped = keyword
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return agentAudits.summary.like('%$escaped%', escapeChar: r'\');
  }
}
