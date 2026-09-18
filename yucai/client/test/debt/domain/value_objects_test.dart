// TDD RED → GREEN:F33-T3 债务 subtype 9 类扩容 + DebtSubtypeAffinity 纯常量单测。
//
// F33 ADR-2 / NFR-1:9 类 borrowedIn subtype 分类与账户类别兼容白名单收敛在
// debt/domain/value_objects.dart 单一事实源。affinity 按跨模块 port 模式
// (debt domain 不 import account 模块)以 String 参数接 category —— 取值即
// `AccountCategory`.name('loan'/'creditCard'/'otherLiability'),下方测试
// 直接用裸字符串钉死 port 契约,不 import account(测试同样解耦)。
//
// 纯 const/纯函数,不依赖 Flutter/drift,直接单测。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/domain/value_objects.dart';

void main() {
  group('DebtSubtypes 9 类 const', () {
    test('all 按原型 v3 顺序暴露 9 个 key', () {
      expect(DebtSubtypes.all, [
        DebtSubtypes.mortgage, // 房贷
        DebtSubtypes.autoLoan, // 车贷
        DebtSubtypes.creditLoan, // 信用贷款
        DebtSubtypes.cashInstallment, // 现金分期
        DebtSubtypes.consumptionLoan, // 消费贷
        DebtSubtypes.businessLoan, // 经营贷
        DebtSubtypes.creditCard, // 信用卡
        DebtSubtypes.family, // 亲友借款
        DebtSubtypes.other, // 其他
      ]);
    });

    test('labels 完整覆盖 9 类中文映射', () {
      expect(DebtSubtypes.all.length, 9);
      for (final key in DebtSubtypes.all) {
        expect(DebtSubtypes.labels.containsKey(key), isTrue,
            reason: 'labels 缺 key=$key');
      }
      expect(DebtSubtypes.labels.length, 9);
      expect(DebtSubtypes.labels[DebtSubtypes.mortgage], '房贷');
      expect(DebtSubtypes.labels[DebtSubtypes.autoLoan], '车贷');
      expect(DebtSubtypes.labels[DebtSubtypes.creditLoan], '信用贷款');
      expect(DebtSubtypes.labels[DebtSubtypes.cashInstallment], '现金分期');
      expect(DebtSubtypes.labels[DebtSubtypes.consumptionLoan], '消费贷');
      expect(DebtSubtypes.labels[DebtSubtypes.businessLoan], '经营贷');
      expect(DebtSubtypes.labels[DebtSubtypes.creditCard], '信用卡');
      expect(DebtSubtypes.labels[DebtSubtypes.family], '亲友借款');
      expect(DebtSubtypes.labels[DebtSubtypes.other], '其他');
    });
  });

  group('DebtSubtypeAffinity.isConflict', () {
    // category 参数为 port 契约字符串(== AccountCategory.name)。
    test('loan × family → true(贷款账户不该挂亲友借款)', () {
      expect(DebtSubtypeAffinity.isConflict('loan', DebtSubtypes.family),
          isTrue);
    });

    test('loan × credit_loan → false(白名单内)', () {
      expect(DebtSubtypeAffinity.isConflict('loan', DebtSubtypes.creditLoan),
          isFalse);
    });

    test('creditCard × mortgage → true', () {
      expect(DebtSubtypeAffinity.isConflict('creditCard', DebtSubtypes.mortgage),
          isTrue);
    });

    test('otherLiability × family → false(白名单内)', () {
      expect(
          DebtSubtypeAffinity.isConflict(
              'otherLiability', DebtSubtypes.family),
          isFalse);
    });

    test('任意 × other → 恒 false(other 特判不提示)', () {
      expect(DebtSubtypeAffinity.isConflict('loan', DebtSubtypes.other),
          isFalse);
      expect(DebtSubtypeAffinity.isConflict('creditCard', DebtSubtypes.other),
          isFalse);
      expect(
          DebtSubtypeAffinity.isConflict('otherLiability', DebtSubtypes.other),
          isFalse);
      expect(DebtSubtypeAffinity.isConflict('savings', DebtSubtypes.other),
          isFalse);
    });

    test('null × 任意 → false(未选账户不提示)', () {
      expect(DebtSubtypeAffinity.isConflict(null, DebtSubtypes.family),
          isFalse);
      expect(DebtSubtypeAffinity.isConflict(null, DebtSubtypes.mortgage),
          isFalse);
    });

    test('未入表类别(savings)× 非 other → true(白名单语义:无兼容值即冲突)',
        () {
      expect(DebtSubtypeAffinity.isConflict('savings', DebtSubtypes.mortgage),
          isTrue);
    });
  });

  group('DebtSubtypeAffinity.defaultSubtypeFor', () {
    test('loan → credit_loan(创建归位默认)', () {
      expect(DebtSubtypeAffinity.defaultSubtypeFor('loan'),
          DebtSubtypes.creditLoan);
    });

    test('creditCard → credit_card', () {
      expect(DebtSubtypeAffinity.defaultSubtypeFor('creditCard'),
          DebtSubtypes.creditCard);
    });

    test('otherLiability → family', () {
      expect(DebtSubtypeAffinity.defaultSubtypeFor('otherLiability'),
          DebtSubtypes.family);
    });

    test('savings → null(无兼容值不联动);null → null', () {
      expect(DebtSubtypeAffinity.defaultSubtypeFor('savings'), isNull);
      expect(DebtSubtypeAffinity.defaultSubtypeFor(null), isNull);
    });
  });
}
