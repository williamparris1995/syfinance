import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/account/domain/value_objects.dart';

void main() {
  test('AccountCategory 有 10 个值 + label/description/accountType', () {
    expect(AccountCategory.values.length, 10);
    expect(AccountCategory.savings.label, '储蓄');
    expect(AccountCategory.creditCard.label, '信用卡');
    expect(AccountCategory.otherLiability.label, '其他负债');
    expect(AccountCategory.creditCard.accountType, AccountType.liability);
    expect(AccountCategory.investment.accountType, AccountType.asset);
    expect(AccountCategory.savings.description, contains('活期'));
    // v6:储值卡(第 10 类)—— 资产语义 + 中文三件套。
    expect(AccountCategory.storedValue.label, '储值卡');
    expect(AccountCategory.storedValue.description, contains('储值'));
    expect(AccountCategory.storedValue.accountType, AccountType.asset);
  });

  test('所有 category 都能派生 asset 或 liability', () {
    for (final c in AccountCategory.values) {
      expect(c.accountType, isIn([AccountType.asset, AccountType.liability]));
    }
  });

  test('负债类 category: creditCard/loan/otherLiability → liability', () {
    expect(AccountCategory.creditCard.accountType, AccountType.liability);
    expect(AccountCategory.loan.accountType, AccountType.liability);
    expect(AccountCategory.otherLiability.accountType, AccountType.liability);
  });

  test('资产类 category: savings/investment/fixedDeposit/goldFx/realEstate/otherAsset → asset', () {
    expect(AccountCategory.savings.accountType, AccountType.asset);
    expect(AccountCategory.investment.accountType, AccountType.asset);
    expect(AccountCategory.fixedDeposit.accountType, AccountType.asset);
    expect(AccountCategory.goldFx.accountType, AccountType.asset);
    expect(AccountCategory.realEstate.accountType, AccountType.asset);
    expect(AccountCategory.otherAsset.accountType, AccountType.asset);
  });

  test('AccountCategory.example 10 类非空 + 含示例文本', () {
    expect(AccountCategory.values.length, 10);
    expect(AccountCategory.savings.example, '招行储蓄卡、工行活期');
    expect(AccountCategory.creditCard.example, '招行 Visa、中信万事达');
    expect(AccountCategory.investment.example, '华泰证券、蚂蚁财富');
    expect(AccountCategory.fixedDeposit.example, '招行大额存单');
    expect(AccountCategory.goldFx.example, '实物黄金、美元 USD');
    expect(AccountCategory.realEstate.example, '朝阳区房产');
    expect(AccountCategory.loan.example, '招行房贷');
    expect(AccountCategory.otherAsset.example, '公积金账户');
    expect(AccountCategory.otherLiability.example, '亲友借款');
    expect(AccountCategory.storedValue.example, '星巴克储值卡、山姆礼品卡');
    for (final c in AccountCategory.values) {
      expect(c.example.isNotEmpty, true, reason: '$c.example 非空');
    }
  });
}
