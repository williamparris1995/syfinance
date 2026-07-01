// GoalViewDataSource(holding-D,Task 10)—— holding 模块调 goal gRPC 的薄壳。
//
// 跨模块 client:holding import goal proto(goal.pbgrpc.dart GoalServiceClient)。
// 仅暴露 listInvestmentGoals():调 goal ListGoals(type=INVESTMENT),返
// List<GoalView>。客户端 filter linked_account 留给调用方(holding_repository
// / presentation):investment goals 数量少,首批取全部 investment 再按
// holding.accountId 客户端 filter,避免 proto/repo 加 linked_account filter。
//
// 构造方式对齐 HoldingRemoteDataSource:接收 GrpcClient + AuthRetryCaller,
// 在构造体里建 GoalServiceClient(channel + authInterceptor),每个 RPC 经
// _retry.call 包裹(401 触发透明刷新 + 单次重试)。DI 未单独注册裸
// GoalServiceClient,本 DS 自建(与 HoldingRemoteDataSource 同款)。
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/holding/data/goal_view_mapper.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/proto/goal/v1/goal.pb.dart' as goalpb;
import 'package:yucai_client/proto/goal/v1/goal.pbgrpc.dart' as goalgrpc;

@LazySingleton()
class GoalViewDataSource {
  GoalViewDataSource(this._grpcClient, this._retry) {
    _client = goalgrpc.GoalServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final goalgrpc.GoalServiceClient _client;

  /// 取所有 investment goals(server 按 type=INVESTMENT filter)。
  /// 调用方(holding_repository / presentation)按 linked_account 客户端 filter。
  Future<List<GoalView>> listInvestmentGoals() async {
    return _retry.call(() async {
      final resp = await _client.listGoals(goalpb.ListGoalsRequest(
        goalType: goalpb.GoalType.GOAL_TYPE_INVESTMENT,
      ));
      return resp.goals.map(goalDtoToView).toList();
    });
  }
}
