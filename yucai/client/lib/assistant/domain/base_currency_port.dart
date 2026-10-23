/// F64 助手地基 —— 展示本位币微 port(评审 fixlist M1,AccountCloser 家法)。
///
/// assistant 只消费自己的 domain port,不 import currency/data 的
/// [CurrencySettings](跨模块不 import 生产方 data 层);组合根(core/di
/// 适配件)委托既有 CurrencySettings.getBaseCurrency() —— 与 home 净资产
/// 大卡同源,networth_snapshot 工具经它取本位币(NFR-1)。
library;

/// 展示/折算本位币来源 port(只读,ISO 4217 code)。
abstract class BaseCurrencySource {
  /// 当前本位币 code(缺省语义由适配的实现方保证,如 "CNY")。
  Future<String> getBaseCurrency();
}
