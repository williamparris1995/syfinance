/// F64 助手地基 —— [BaseCurrencySource] 生产适配件(评审 fixlist M1)。
///
/// 组合根单向适配(照 NetWorthSnapshotSourceAdapter 先例):assistant 域
/// 只见自己的 domain port,本类在 core/di 把既有
/// [CurrencySettings.getBaseCurrency] 委托过去 —— 与 home 净资产大卡
/// 同源。落在组合根而非 assistant/data:适配必然 import currency/data,
/// assistant 不 import 生产方(跨模块 port 家法)。
///
/// 手工注册(照 networth_snapshot_source_adapter.dart 先例),不入
/// injectable 生成图;见 injection.dart 的 F64 工具装配段。
library;

import 'package:yucai_client/assistant/domain/base_currency_port.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';

class BaseCurrencySourceAdapter implements BaseCurrencySource {
  BaseCurrencySourceAdapter(this._settings);

  final CurrencySettings _settings;

  @override
  Future<String> getBaseCurrency() => _settings.getBaseCurrency();
}
