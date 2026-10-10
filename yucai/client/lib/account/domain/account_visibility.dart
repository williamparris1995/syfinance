import 'package:yucai_client/account/domain/entities/account_entity.dart';

/// F49 FR-3 展示层统一过滤入口：isSystem=true 的账务载体户（卡贷并入
/// 模式自动建户）退出用户视野（账户列表/各类账户选择器）。只服务渲染；
/// 净资产、负债总额、报表聚合等金额计算一律取全量、不过滤（spec FR-3）。
abstract final class AccountVisibility {
  static List<Account> userVisible(Iterable<Account> xs) =>
      xs.where((a) => !a.isSystem).toList();
}
