/// F70 写域契约 —— 写执行器 port + 执行结果(ADR-1/ADR-3)。
///
/// 写工具只提案;实际落库唯一入口 = [WriteExecutor.execute],由 bloc 的
/// 用户确认回调触发(T2 impl:TransactionRepository 同管道 + 幂等集 +
/// 审计 + appendToolOutcome)。port 在 domain:data 依赖注入,测试可 fake。
library;

import 'write_action.dart';

/// 写执行器 port(仅确认回调可达 —— 构造私有化/回调注入在 T2 impl 与
/// 绕过负测钉死;本 port 即「确认门在代码层」的接缝)。
abstract class WriteExecutor {
  /// 执行一次已确认的写操作。
  ///
  /// [idempotencyKey] = 确认实例 uuid(ADR-3):同一键重复触发(重试/竞态)
  /// 不重复落库 → [AlreadyExecuted];首执行成功 → [WriteExecuted];
  /// 失败(实体竞态消失/校验不过等)→ [WriteFailed](reason 单行英文,
  /// 幂等键不消耗)。
  Future<WriteOutcome> execute(WriteAction action, String idempotencyKey);
}

/// 执行结果三态(sealed;消费方穷尽分支)。
sealed class WriteOutcome {
  const WriteOutcome();
}

/// 首次执行成功([entityId] = 落库交易 id)。
class WriteExecuted extends WriteOutcome {
  const WriteExecuted(this.entityId);

  final String entityId;

  @override
  String toString() => 'WriteExecuted(entityId=$entityId)';
}

/// 幂等键已消耗过(同确认重复触发;[entityId] = 首次执行结果)。
class AlreadyExecuted extends WriteOutcome {
  const AlreadyExecuted(this.entityId);

  final String entityId;

  @override
  String toString() => 'AlreadyExecuted(entityId=$entityId)';
}

/// 执行失败(确认卡转 error + 重试;幂等键不消耗)。
class WriteFailed extends WriteOutcome {
  const WriteFailed(this.reason);

  /// 英文单行自解释原因(执行器保证;不携敏感 payload)。
  final String reason;

  @override
  String toString() => 'WriteFailed(reason=$reason)';
}
