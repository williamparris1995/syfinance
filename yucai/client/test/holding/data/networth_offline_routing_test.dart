// F10 FR-2:NetWorthDataSource 三态路由轻测 —— bound-offline(离线冷启动)
// 直接本地三源计算,不触碰 gRPC(路由判定对齐 8 repo;绑定在线的 β 兜底
// 保留在 DS 内,本测只钉路由分支)。
import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/config/app_config.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart'
    show NetWorthLocalDataSource;
import 'package:yucai_client/holding/data/networth_ds.dart';

void main() {
  late AppDatabase database;
  late SessionModeTracker tracker;
  late NetWorthDataSource ds;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tracker = SessionModeTracker();
    // GrpcClient 仅为构造所需(channel 懒连接);bound-offline 分支
    // 不会发起任何 RPC。
    final grpcClient = GrpcClient(
      const AppConfig(serverHost: 'localhost', serverPort: 9090, useTls: false),
      AuthInterceptor(),
    );
    ds = NetWorthDataSource(
        grpcClient, AuthRetryCaller(), NetWorthLocalDataSource(database), tracker);
  });

  tearDown(() => database.close());

  test('bound-offline(authOffline 冷启动)→ 本地三源计算,不报错', () async {
    tracker
      ..isGuest = false
      ..authOffline = true;
    // 空库:0/0/0 的净资产视图 —— 钉「读走本地且不抛」这一路由行为。
    final view = await ds.getNetWorth(baseCurrency: '');
    expect(view.totalAssetsCents, 0);
    expect(view.totalLiabilitiesCents, 0);
    expect(view.netWorthCents, 0);
  });
}
