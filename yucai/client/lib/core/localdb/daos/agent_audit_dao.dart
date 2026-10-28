import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/agent_audit_table.dart';

part 'agent_audit_dao.g.dart';

/// F71(spec FR-1/FR-3 查询面,design ADR-2/ADR-3)agent_audit DAO:
/// append-only 写入 + 倒序分页读(对话框「加载更多」式,20/页家法)。
/// 消费方:`AgentAuditSinkImpl`(写,assistant/data)+ 审计对话框(T2,
/// watchPage/count)。**不参与 sync/备份**(表头注排除面)。
@DriftAccessor(tables: [AgentAudits])
class AgentAuditDao extends DatabaseAccessor<AppDatabase>
    with _$AgentAuditDaoMixin {
  AgentAuditDao(super.db);

  /// 追加一行审计留痕(自增 id 由库分配;返回新行 id)。
  Future<int> insertEvent(AgentAuditsCompanion entry) =>
      into(agentAudits).insert(entry);

  /// 总条数(入口行 badge;空态判定)。
  Future<int> count() => agentAudits.count().getSingle();

  /// 时间倒序一页(createdMillis DESC,id DESC 同毫秒次锚;
  /// [limit] 页大小,[offset] 偏移 —— 首页 0,「加载更多」累加)。
  Stream<List<AgentAudit>> watchPage({int limit = 20, int offset = 0}) {
    final query = select(agentAudits)
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdMillis),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit, offset: offset);
    return query.watch();
  }
}
