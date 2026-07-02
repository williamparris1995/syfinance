import 'package:dartz/dartz.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';

/// 目标仓储抽象(对齐 goal.proto GoalService,8 个核心 RPC + CloneGoal)。
///
/// 签名以 proto 真契约为准:
/// - listGoals 的 type 过滤对应 proto ListGoalsRequest.goalType;completed
///   过滤对应 proto ListGoalsRequest.completed(bool)。两个皆可空 → 不过滤。
/// - createGoal 的 deadline 为 String(proto CreateGoalRequest.deadline 是
///   string,server 端解析),linkedAccountIds / linkedDebtIds 为 repeated string。
/// - recordContribution 对应 proto UpdateProgress(id + amountCents)。
/// - cloneGoal 接受可选 targetAmountCents / deadline / name,覆盖源目标同名字段。
/// - completeGoal / deleteGoal 返回 void(proto 返回 google.protobuf.Empty)。
abstract class GoalRepository {
  Future<Either<Failure, List<GoalView>>> listGoals({GoalType? type, bool? completed});
  Future<Either<Failure, GoalView>> getGoal(String id);
  Future<Either<Failure, GoalView>> createGoal({
    required String name,
    required GoalType type,
    required int targetAmountCents,
    String currencyCode = 'CNY',
    String? deadline,
    List<String> linkedAccountIds = const [],
    List<String> linkedDebtIds = const [],
    String? notes,
  });
  Future<Either<Failure, GoalView>> updateGoal({
    required String id,
    String? name,
    int? targetAmountCents,
    String? deadline,
    List<String>? linkedAccountIds,
    List<String>? linkedDebtIds,
    String? notes,
    int? version,
  });
  Future<Either<Failure, void>> deleteGoal(String id);
  Future<Either<Failure, void>> completeGoal(String id);
  Future<Either<Failure, GoalView>> recordContribution({
    required String id,
    required int amountCents,
  });
  Future<Either<Failure, GoalView>> cloneGoal({
    required String sourceId,
    int? targetAmountCents,
    String? deadline,
    String? name,
  });
}
