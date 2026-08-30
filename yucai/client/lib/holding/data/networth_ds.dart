// NetWorthDataSource(holding-D,Task 11)—— home 仪表盘调 networth gRPC 的薄壳。
//
// 跨模块 client:holding import networth proto
// (networth/v1/service.pbgrpc.dart NetWorthServiceClient)。仅暴露 getNetWorth():
// 调 NetWorthService.GetNetWorth(base_currency),返 NetWorthView
// (totalAssets/liabilities/netWorth cents + 折算后的 currency code)。
//
// 构造方式对齐 HoldingRemoteDataSource / GoalViewDataSource:接收 GrpcClient +
// AuthRetryCaller,在构造体里建 NetWorthServiceClient(channel + authInterceptor),
// 每个 RPC 经 _retry.call 包裹(401 触发透明刷新 + 单次重试)。DI 未单独注册裸
// NetWorthServiceClient,本 DS 自建(与 HoldingRemoteDataSource 同款)。
//
// baseCurrency 由调用方(home _NetWorthCard)从 CurrencySettings.getBaseCurrency()
// 取得后传入(空串/CNY → server 不折算,直接按原币汇总;USD 等 → server 解析
// CNY→base 交叉汇率折算)。mapper Int64 cents → int 对齐 holding_mapper 模式。
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart'
    show NetWorthLocalDataSource;

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/proto/networth/v1/service.pb.dart' as pb;
import 'package:yucai_client/proto/networth/v1/service.pbgrpc.dart' as grpc;

@LazySingleton()
class NetWorthDataSource {
  NetWorthDataSource(this._grpcClient, this._retry, this._local, this._tracker) {
    _client = grpc.NetWorthServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  final NetWorthLocalDataSource _local;
  final SessionModeTracker _tracker;
  late final grpc.NetWorthServiceClient _client;

  /// 取本位币折算后的总资产 / 总负债 / 净资产(cents)。
  ///
  /// [baseCurrency] 为 ISO 4217 code(来自 CurrencySettings.getBaseCurrency());
  /// 空串/CNY → server 不折算;USD 等 → server 解析 CNY→base 交叉汇率折算。
  Future<NetWorthView> getNetWorth({required String baseCurrency}) async {
    if (_tracker.isGuest) return _local.getNetWorth(baseCurrency: baseCurrency);
    try {
      return await _retry.call(() async {
        final resp = await _client.getNetWorth(pb.GetNetWorthRequest(
          baseCurrency: baseCurrency,
        ));
        return _toView(resp);
      });
    } on GrpcError catch (e) {
      // β 兜底(R7 收官补丁):绑定 + server 不可达 → 本地三源计算。
      // 与 performance 同语义(离线降级不报错);unavailable/deadline-exceeded
      // 视为网络类,其余原样抛。
      if (e.code == StatusCode.unavailable ||
          e.code == StatusCode.deadlineExceeded) {
        return _local.getNetWorth(baseCurrency: baseCurrency);
      }
      rethrow;
    }
  }

  static NetWorthView _toView(pb.GetNetWorthResponse resp) {
    return NetWorthView(
      // Int64 → int(proto cents → domain int,对齐 holding_mapper Int64→int)。
      totalAssetsCents: resp.totalAssetsCents.toInt(),
      totalLiabilitiesCents: resp.totalLiabilitiesCents.toInt(),
      netWorthCents: resp.netWorthCents.toInt(),
      // currency 为折算后本位币 code(空 → server 默认 CNY;调用方经
      // currencySymbol(code) 转显示符号)。
      currency: resp.currency.isEmpty ? 'CNY' : resp.currency,
    );
  }
}
