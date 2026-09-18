/// 摊还方法(对齐 proto AmortizationMethod)。
enum AmortizationMethod {
  equalPrincipalInterest, // 等额本息
  equalPrincipal, // 等额本金
  lumpSum, // 一次性
  interestFirst, // 先息后本:每期付息,到期一次还本
}

enum PaymentStatus { paid, pending, overdue }

/// 债务方向(对齐 proto DebtType,客户端独立枚举;data 层 mapper 负责转换)。
/// borrowedIn = 借入(负债,默认值,匹配服务端旧行为);
/// borrowedOut = 借出(债权 / 应收)。
enum DebtType { borrowedIn, borrowedOut }

/// borrowedIn 子类型 const(英文 key + 中文 label)。判断用 const,禁裸字符串。
/// 9 类顺序即原型 v3 的 debt_form subtype 选择区顺序(prototype v3 为 UI 事实源)。
abstract final class DebtSubtypes {
  static const mortgage = 'mortgage';
  static const autoLoan = 'auto_loan';
  static const creditLoan = 'credit_loan';
  static const cashInstallment = 'cash_installment';
  static const consumptionLoan = 'consumption_loan';
  static const businessLoan = 'business_loan';
  static const creditCard = 'credit_card';
  static const family = 'family';
  static const other = 'other';
  static const all = [
    mortgage,
    autoLoan,
    creditLoan,
    cashInstallment,
    consumptionLoan,
    businessLoan,
    creditCard,
    family,
    other,
  ];
  static const labels = {
    mortgage: '房贷',
    autoLoan: '车贷',
    creditLoan: '信用贷款',
    cashInstallment: '现金分期',
    consumptionLoan: '消费贷',
    businessLoan: '经营贷',
    creditCard: '信用卡',
    family: '亲友借款',
    other: '其他',
  };
}

/// 账户类别 × 债务 subtype 兼容白名单(F33 ADR-2,与 [DebtSubtypes] 同文件构成
/// 单一事实源 NFR-1)。design contract 见 design.md LLD ①。
///
/// **跨模块 import 裁决(port 模式,不新增跨模块 import)**:本类位于 debt
/// domain,而 debt domain 现状对 account 模块**零 import 先例**(仅 presentation/
/// pages 与 data/debt_local_ds.dart 有 account import;domain 层无)。按项目
/// 强约束「跨模块 port 模式:消费模块不 import 生产模块」(CLAUDE.md Mandatory
/// #4 / 跨模块 port 模式条),这里**不 import** `AccountCategory`,category 以
/// String 参数传入 —— 取值即 `AccountCategory`.name('loan'/'creditCard'/
/// 'otherLiability'…),已持有 account 依赖的调用方(presentation)用
/// `account.category.name` 适配即可。镜像点收敛在下方 `_cat*` 私有常量 +
/// 测试钉契约:account 域枚举若改名,由 value_objects_test 单测门拦,不会静默漂移。
abstract final class DebtSubtypeAffinity {
  // port 适配点:== AccountCategory.{loan,creditCard,otherLiability}.name。
  static const _catLoan = 'loan';
  static const _catCreditCard = 'creditCard';
  static const _catOtherLiability = 'otherLiability';

  /// 账户类别 name → 兼容 subtype 集(白名单:不在表内/不在集内即冲突;
  /// 资产类账户无兼容 subtype,挂任何债务 subtype 均提示不一致)。
  static const Map<String, Set<String>> compatible = {
    _catLoan: {
      DebtSubtypes.mortgage,
      DebtSubtypes.autoLoan,
      DebtSubtypes.creditLoan,
      DebtSubtypes.cashInstallment,
      DebtSubtypes.consumptionLoan,
      DebtSubtypes.businessLoan,
    },
    _catCreditCard: {DebtSubtypes.creditCard},
    _catOtherLiability: {DebtSubtypes.family},
  };

  /// 创建模式自动归位默认值(design.md LLD ②);无兼容值的类别(含 null)
  /// 返回 null = 不联动。注意 loan 默认 credit_loan 而非白名单首项 mortgage。
  static String? defaultSubtypeFor(String? category) => switch (category) {
        _catLoan => DebtSubtypes.creditLoan,
        _catCreditCard => DebtSubtypes.creditCard,
        _catOtherLiability => DebtSubtypes.family,
        _ => null,
      };

  /// 提示判定(设计契约):
  /// - category null → false(未选账户不提示);
  /// - subtypeKey == other → 恒 false(other 兜底类永不提示,判定处特判);
  /// - 其余查 [compatible] 白名单:不在集内 → true。
  static bool isConflict(String? category, String subtypeKey) {
    if (category == null) return false;
    if (subtypeKey == DebtSubtypes.other) return false;
    return !(compatible[category]?.contains(subtypeKey) ?? false);
  }
}

/// borrowedOut 子类型 const。
abstract final class ReceivableSubtypes {
  static const personal = 'personal';
  static const business = 'business';
  static const family = 'family';
  static const other = 'other';
  static const all = [personal, business, family, other];
  static const labels = {
    personal: '私人',
    business: '商业',
    family: '亲友',
    other: '其他',
  };
}
