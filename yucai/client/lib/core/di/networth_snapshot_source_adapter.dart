/// F64 助手地基 —— [NetWorthSnapshotSource] 生产适配件(T6 DI 接线,ADR-2)。
///
/// 组合根单向适配:assistant 域只见自己的 domain port,本类在 core/di
/// 把既有 [NetWorthLocalDataSource.getNetWorth] 委托过去 —— 与 home 净资产
/// 大卡同源,逐分一致由 tools_caliber_test 钉死(NFR-1)。落在组合根而
/// 非 assistant/data:适配必然 import holding/data,assistant 不 import
/// 生产方(跨模块 port 家法,消费方不 import 生产方)。
///
/// 手工注册(照 GrpcClient「Manually registered」先例),不入 injectable
/// 生成图;见 injection.dart 的 F64 工具装配段。
library;

import 'package:yucai_client/assistant/domain/networth_port.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';

class NetWorthSnapshotSourceAdapter implements NetWorthSnapshotSource {
  NetWorthSnapshotSourceAdapter(this._dataSource);

  final NetWorthLocalDataSource _dataSource;

  @override
  Future<NetWorthView> fetch({required String baseCurrency}) =>
      _dataSource.getNetWorth(baseCurrency: baseCurrency);
}
