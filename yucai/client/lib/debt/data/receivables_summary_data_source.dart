// ReceivablesSummaryDataSource(receivables 对齐,Task 8)—— debt 模块
// 调 GetReceivablesSummary RPC 的薄壳,产出 ReceivablesSummary 给 Task 9-11
// presentation / bloc 消费。
//
// 构造方式对齐 GoalViewDataSource(holding-D)/ DebtRemoteDataSource:接收
// GrpcClient + AuthRetryCaller,构造体里建 DebtServiceClient(channel +
// authInterceptor),每个 RPC 经 _retry.call 包裹(401 触发透明刷新 + 单次
// 重试)。DI 未单独注册裸 DebtServiceClient,本 DS 自建(与 DebtRemoteDataSource
// 同款,二者共享 client 类但各自持有一份,无单例耦合)。
//
// 只暴露 fetch():调 GetReceivablesSummary(空 Request)→ response.summary →
// receivablesSummaryDtoToEntity。无分页/无 filter(服务端按 tenant 算全量)。
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/debt/data/receivables_summary_mapper.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;
import 'package:yucai_client/proto/debt/v1/debt.pbgrpc.dart' as grpc;

@LazySingleton()
class ReceivablesSummaryDataSource {
  ReceivablesSummaryDataSource(this._grpcClient, this._retry) {
    _client = grpc.DebtServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.DebtServiceClient _client;

  /// 取当前 tenant 的应收债权汇总(服务端按 tenant 全量算,无 filter)。
  Future<ReceivablesSummary> fetch() async {
    return _retry.call(() async {
      final resp =
          await _client.getReceivablesSummary(pb.GetReceivablesSummaryRequest());
      return receivablesSummaryDtoToEntity(resp.summary);
    });
  }
}
