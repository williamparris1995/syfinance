import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';

import 'package:yucai_client/account/data/mappers/account_mapper.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/proto/account/v1/account.pb.dart' as pb;

void main() {
  test('maps proto AccountDTO to domain Account', () {
    final dto = pb.AccountDTO()
      ..id = 'a1'
      ..name = '招商银行'
      ..accountType = pb.AccountType.ACCOUNT_TYPE_ASSET
      ..currencyCode = 'CNY'
      ..initialBalanceCents = Int64(100000)
      ..currentBalanceCents = Int64(250000)
      ..ownership = pb.Ownership.OWNERSHIP_PERSONAL
      ..status = pb.AccountStatus.ACCOUNT_STATUS_ACTIVE
      ..version = Int64(3);

    final account = const AccountMapper().toDomain(dto);

    expect(account.id, 'a1');
    expect(account.name, '招商银行');
    expect(account.accountType, AccountType.asset);
    expect(account.currencyCode, 'CNY');
    expect(account.initialBalanceCents, 100000);
    expect(account.currentBalanceCents, 250000);
    expect(account.ownership, Ownership.personal);
    expect(account.status, AccountStatus.active);
    expect(account.version, 3);
  });

  test('equatable: two equal accounts match', () {
    final a = Account(
      id: 'x', name: 'n', accountType: AccountType.expense, currencyCode: 'CNY',
      initialBalanceCents: 0, currentBalanceCents: 0,
      ownership: Ownership.personal, status: AccountStatus.active,
    );
    final b = Account(
      id: 'x', name: 'n', accountType: AccountType.expense, currencyCode: 'CNY',
      initialBalanceCents: 0, currentBalanceCents: 0,
      ownership: Ownership.personal, status: AccountStatus.active,
    );
    expect(a, b);
  });
}
