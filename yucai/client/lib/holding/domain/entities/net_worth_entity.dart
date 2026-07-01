// NetWorthView entity(holding-D,Task 11)—— home 仪表盘净资产大卡的只读视图。
//
// 字段对齐 networth.proto GetNetWorthResponse(total_assets_cents /
// total_liabilities_cents / net_worth_cents / currency)。cents 字段为 int
// (proto Int64 经 mapper `.toInt()`,对齐 holding_mapper Int64→int 模式)。
//
// [currency] 为 server 折算后的本位币 ISO 4217 code(空 → "CNY"),由调用方
// (home _NetWorthCard)经 currencySymbol(code) 转显示符号(CNY→¥,USD→$ 等),
// 取代旧版硬编码 ¥。
//
// 复用方:home_page _NetWorthCard 仅展示 totalAssets / totalLiabilities / netWorth
// + 本位币符号;后续若需扩展(资产分解细分)可直接读此 entity。
import 'package:equatable/equatable.dart';

/// 净资产只读视图(账户余额 + 持仓市值 − 负债余额,折算到本位币)。
class NetWorthView extends Equatable {
  const NetWorthView({
    required this.totalAssetsCents,
    required this.totalLiabilitiesCents,
    required this.netWorthCents,
    required this.currency,
  });

  final int totalAssetsCents;
  final int totalLiabilitiesCents;
  final int netWorthCents;

  /// ISO 4217 本位币 code(server 折算目标;空 → "CNY")。
  final String currency;

  @override
  List<Object?> get props => [
        totalAssetsCents,
        totalLiabilitiesCents,
        netWorthCents,
        currency,
      ];
}
