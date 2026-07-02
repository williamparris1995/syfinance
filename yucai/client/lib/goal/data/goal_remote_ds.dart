import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/proto/goal/v1/goal.pb.dart' as pb;
import 'package:yucai_client/proto/goal/v1/goal.pbgrpc.dart' as grpc;
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;

/// Wraps the generated GoalServiceClient. Throws GrpcError on failure (caught
/// and mapped by the repo layer). Mirrors BudgetRemoteDataSource /
/// HoldingRemoteDataSource / DebtRemoteDataSource: every RPC is wrapped in
/// AuthRetryCaller so a 401 triggers a transparent refresh + single retry.
///
/// 8 RPCs + CloneGoal: createGoal / updateGoal / updateGoalProgress
/// (recordContribution) / completeGoal / deleteGoal / getGoal / listGoals /
/// syncGoalProgress / cloneGoal。前端仅消费前 8 + CloneGoal;syncGoalProgress /
/// syncInvestmentGoals 为 server scheduler 内部用,DS 不暴露。
///
/// Mapper notes(参照 holding mapper + budget ds 模式):
/// - Int64 → int via `.toInt()`(targetAmountCents / currentAmountCents)。
/// - proto GoalType ↔ domain GoalType 显式按 NAME switch(proto 有
///   GOAL_TYPE_UNSPECIFIED=0 占位,domain 无 —— 直接按 int 强转会 off-by-one;
///   UNSPECIFIED 折叠为 savings 默认值)。
/// - GoalDTO.deadline 为 proto Timestamp → DateTime?(hasDeadline guard)。
///   但 CreateGoalRequest / UpdateGoalRequest / CloneGoalRequest 的 deadline
///   是 string(server 端解析),DS 直接透传 String?。
/// - linkedAccountIds / linkedDebtIds 为 proto repeated string(field 17 / 18)
///   → List<String>;createGoal / updateGoal 反向 List<String> → repeated。
/// - notes 空串(`''`)→ null(proto unset scalar string 默认 '' 但 UI 层需区分
///   "无备注")。
@LazySingleton()
class GoalRemoteDataSource {
  GoalRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.GoalServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.GoalServiceClient _client;

  // —— 查询 ——
  Future<List<GoalView>> listGoals({GoalType? type, bool? completed}) async {
    return _retry.call(() async {
      final res = await _client.listGoals(pb.ListGoalsRequest(
        page: common.PageRequest(pageSize: 100),
        goalType: type != null ? goalTypeToProto(type) : null,
        completed: completed,
      ));
      return res.goals.map(goalDtoToView).toList();
    });
  }

  Future<GoalView> getGoal(String id) async {
    return _retry.call(() async {
      final res = await _client.getGoal(pb.GetGoalRequest(id: id));
      return goalDtoToView(res.goal);
    });
  }

  // —— 写入 ——
  Future<GoalView> createGoal({
    required String name,
    required GoalType type,
    required int targetAmountCents,
    String currencyCode = 'CNY',
    String? deadline,
    List<String> linkedAccountIds = const [],
    List<String> linkedDebtIds = const [],
    String? notes,
  }) async {
    return _retry.call(() async {
      final res = await _client.createGoal(pb.CreateGoalRequest(
        name: name,
        goalType: goalTypeToProto(type),
        targetAmountCents: Int64(targetAmountCents),
        currencyCode: currencyCode,
        deadline: deadline ?? '',
        linkedAccountIds: linkedAccountIds,
        linkedDebtIds: linkedDebtIds,
        notes: notes ?? '',
      ));
      return goalDtoToView(res.goal);
    });
  }

  Future<GoalView> updateGoal({
    required String id,
    String? name,
    int? targetAmountCents,
    String? deadline,
    List<String>? linkedAccountIds,
    List<String>? linkedDebtIds,
    String? notes,
    int? version,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateGoal(pb.UpdateGoalRequest(
        id: id,
        name: name ?? '',
        targetAmountCents:
            targetAmountCents != null ? Int64(targetAmountCents) : Int64.ZERO,
        deadline: deadline ?? '',
        notes: notes ?? '',
        version: version != null ? Int64(version) : Int64.ZERO,
        linkedAccountIds: linkedAccountIds ?? const [],
        linkedDebtIds: linkedDebtIds ?? const [],
      ));
      return goalDtoToView(res.goal);
    });
  }

  Future<void> deleteGoal(String id) async {
    return _retry.call(() async {
      await _client.deleteGoal(pb.DeleteGoalRequest(id: id));
    });
  }

  Future<void> completeGoal(String id) async {
    return _retry.call(() async {
      await _client.completeGoal(pb.CompleteGoalRequest(id: id));
    });
  }

  Future<GoalView> recordContribution({
    required String id,
    required int amountCents,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateGoalProgress(
          pb.UpdateProgressRequest(id: id, amountCents: Int64(amountCents)));
      return goalDtoToView(res.goal);
    });
  }

  Future<GoalView> cloneGoal({
    required String sourceId,
    int? targetAmountCents,
    String? deadline,
    String? name,
  }) async {
    return _retry.call(() async {
      final res = await _client.cloneGoal(pb.CloneGoalRequest(
        sourceGoalId: sourceId,
        targetAmountCents: targetAmountCents != null
            ? Int64(targetAmountCents)
            : Int64.ZERO,
        deadline: deadline ?? '',
        name: name ?? '',
      ));
      return goalDtoToView(res.goal);
    });
  }
}

/// proto GoalDTO → GoalView。
///
/// Int64 → int via `.toInt()`;repeated string → List<String>;deadline
/// Timestamp → DateTime?(hasDeadline guard,空 Timestamp 不映射);notes 空串
/// → null;goalType 按 NAME 映射(UNSPECIFIED 折叠为 savings)。
GoalView goalDtoToView(pb.GoalDTO dto) => GoalView(
      id: dto.id,
      name: dto.name,
      type: protoToGoalType(dto.goalType),
      targetAmountCents: dto.targetAmountCents.toInt(),
      currentAmountCents: dto.currentAmountCents.toInt(),
      currencyCode: dto.currencyCode,
      deadline: dto.hasDeadline() ? dto.deadline.toDateTime() : null,
      linkedAccountIds: List<String>.from(dto.linkedAccountIds),
      linkedDebtIds: List<String>.from(dto.linkedDebtIds),
      notes: dto.notes.isEmpty ? null : dto.notes,
      isCompleted: dto.isCompleted,
    );

/// proto GoalType → domain GoalType(显式按 NAME switch,绝不按 int 强转)。
///
/// proto GOAL_TYPE_UNSPECIFIED=0 占位 → domain 无占位,折叠为 savings(最常见
/// 默认值)。off-by-one 注意:直接按 index 会让 SAVINGS=1 错位成 debtPayoff=1。
GoalType protoToGoalType(pb.GoalType t) {
  switch (t) {
    case pb.GoalType.GOAL_TYPE_SAVINGS:
      return GoalType.savings;
    case pb.GoalType.GOAL_TYPE_DEBT_PAYOFF:
      return GoalType.debtPayoff;
    case pb.GoalType.GOAL_TYPE_INVESTMENT:
      return GoalType.investment;
    case pb.GoalType.GOAL_TYPE_UNSPECIFIED:
    default:
      // UNSPECIFIED 折叠为 savings(常见默认目标类型)。
      return GoalType.savings;
  }
}

/// domain GoalType → proto GoalType(显式按 NAME switch)。
pb.GoalType goalTypeToProto(GoalType t) {
  switch (t) {
    case GoalType.savings:
      return pb.GoalType.GOAL_TYPE_SAVINGS;
    case GoalType.debtPayoff:
      return pb.GoalType.GOAL_TYPE_DEBT_PAYOFF;
    case GoalType.investment:
      return pb.GoalType.GOAL_TYPE_INVESTMENT;
  }
}
