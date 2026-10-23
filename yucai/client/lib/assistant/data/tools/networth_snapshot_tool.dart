// F64-T3 —— networth_snapshot 只读工具(FR-2/ADR-6,NFR-1 口径)。
//
// 取数与 home 净资产大卡同源:baseCurrency 经 CurrencySettings
// .getBaseCurrency(),数据经 assistant/domain 的 [NetWorthSnapshotSource]
// port(DI 组合根适配 NetWorthLocalDataSource;本模块不 import holding/data,
// AccountCloser 家法,见 networth_port.dart)。
library;

import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/networth_port.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart'
    show DueReminderPolicy;
import 'package:yucai_client/currency/data/currency_settings.dart';

/// 净资产快照工具:最新资产/负债/净资产(cents + 元双口径)+ 本位币 + 取数时点。
///
/// 无参数。金额元字符串复用 core 纯函数 [DueReminderPolicy.formatYuan]
/// (两位小数 + 千分位;presentation 各页的 formatCents 为私有/带币符,
/// 不适合数据层 —— core 既有等价纯函数即此,复用第一,不自写第五份)。
class NetWorthSnapshotTool implements AssistantTool {
  NetWorthSnapshotTool(this._source, this._currencySettings);

  final NetWorthSnapshotSource _source;
  final CurrencySettings _currencySettings;

  @override
  String get name => 'networth_snapshot';

  @override
  String get description =>
      'Latest net worth snapshot: total assets, total liabilities and net '
      'worth in the user base currency, taken from the same local data the '
      'net-worth card shows. Use for questions like "how much am I worth / '
      'how much do I owe in total". No parameters. Not for per-account or '
      'per-debt breakdowns (use accounts_list / debts_list instead).';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': <String, Object>{},
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    try {
      final base = await _currencySettings.getBaseCurrency();
      final view = await _source.fetch(baseCurrency: base);
      return ToolData({
        'totalAssetsCents': view.totalAssetsCents,
        'totalLiabilitiesCents': view.totalLiabilitiesCents,
        'netWorthCents': view.netWorthCents,
        'currency': view.currency,
        'formatted': {
          'totalAssets': DueReminderPolicy.formatYuan(view.totalAssetsCents),
          'totalLiabilities':
              DueReminderPolicy.formatYuan(view.totalLiabilitiesCents),
          'netWorth': DueReminderPolicy.formatYuan(view.netWorthCents),
        },
        'asOf': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // 取数失败不冒泡:自纠语义的 ToolError(英文、零敏感数据)。
      return const ToolError(
        'failed to read the local net worth snapshot; '
        'ask the user to retry later',
      );
    }
  }
}
