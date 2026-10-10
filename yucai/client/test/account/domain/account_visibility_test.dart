// AccountVisibility(F49 FR-3):isSystem=true 载体户从用户视野过滤的
// domain 纯函数 —— 过滤/保留/空列表/顺序稳定。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/account_visibility.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';

Account _account(String id, {bool isSystem = false}) => Account(
      id: id,
      name: id,
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
  test('isSystem=true 被滤,false 保留', () {
    final out = AccountVisibility.userVisible([
      _account('user-1'),
      _account('carrier-1', isSystem: true),
      _account('user-2'),
      _account('carrier-2', isSystem: true),
    ]);
    expect(out.map((a) => a.id), ['user-1', 'user-2']);
  });

  test('空列表入空列表出', () {
    expect(AccountVisibility.userVisible(const []), isEmpty);
  });

  test('全部为载体户时结果为空(不抛异常)', () {
    final out = AccountVisibility.userVisible(
        [_account('c1', isSystem: true), _account('c2', isSystem: true)]);
    expect(out, isEmpty);
  });

  test('顺序稳定:保留行保持输入相对次序', () {
    final out = AccountVisibility.userVisible([
      _account('b'),
      _account('carrier', isSystem: true),
      _account('a'),
      _account('c'),
    ]);
    expect(out.map((a) => a.id), ['b', 'a', 'c']);
  });
}
