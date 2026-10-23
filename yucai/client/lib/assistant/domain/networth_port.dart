/// F64 助手地基 —— 净资产快照 port(ADR-2,AccountCloser 家法)。
///
/// assistant 只 import holding/domain 实体(跨模块 import domain 合法),
/// 不 import holding/data;DI 组合根将本 port 适配到
/// NetWorthLocalDataSource.getNetWorth(),networth_snapshot 工具经它取数
/// —— 与 home 净资产大卡同源,保证逐分一致(NFR-1)。
library;

import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';

/// 最新净资产快照数据源 port(只读)。
abstract class NetWorthSnapshotSource {
  /// 拉取最新净资产视图(资产/负债/净资产 cents + 本位币)。
  ///
  /// [baseCurrency] 为展示/折算本位币 ISO 4217 code(经
  /// CurrencySettings.getBaseCurrency(),与 home 大卡同源)。
  Future<NetWorthView> fetch({required String baseCurrency});
}
