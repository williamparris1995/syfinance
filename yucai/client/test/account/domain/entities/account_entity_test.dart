// Account entity — isSystem 字段(F49 FR-3 地基):缺省 false、copyWith
// 覆盖/保留、相等性区分。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';

Account _account({bool isSystem = false}) => Account(
      id: 'a1',
      name: '现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      isSystem: isSystem,
    );

void main() {
  test('isSystem 缺省 false(真实账户/独立账单模式不置位)', () {
    expect(_account().isSystem, isFalse);
  });

  test('copyWith 覆盖 isSystem', () {
    final carrier = _account().copyWith(isSystem: true);
    expect(carrier.isSystem, isTrue);
    expect(carrier.id, 'a1'); // 其余字段不动
  });

  test('copyWith 省略 isSystem 时保留原值', () {
    expect(_account().copyWith(name: '改名').isSystem, isFalse);
    expect(_account(isSystem: true).copyWith(name: '改名').isSystem, isTrue);
  });

  test('相等性区分 isSystem(仅标记不同即不等)', () {
    expect(_account(), equals(_account()));
    expect(_account(), isNot(equals(_account(isSystem: true))));
  });
}
