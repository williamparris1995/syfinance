// AccountLocalDataSource unit tests — mapping round-trips (enum index+1,
// parentId ''<->NULL, creditLimit 0<->NULL) and guest write semantics
// (create defaults, patch update, balance-guarded delete) on a memory db.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late AppDatabase db;
  late AccountLocalDataSource ds;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = AccountLocalDataSource(db);
  });

  tearDown(() async => db.close());

  CreateAccountParams params({
    String name = '现金',
    AccountCategory category = AccountCategory.savings,
    int initialBalanceCents = 1000,
    String parentId = '',
    int creditLimitCents = 0,
  }) =>
      CreateAccountParams(
        name: name,
        accountType: AccountType.liability,
        category: category,
        currencyCode: 'CNY',
        initialBalanceCents: initialBalanceCents,
        ownership: Ownership.joint,
        parentId: parentId,
        creditLimitCents: creditLimitCents,
        interestRate: 2.5,
      );

  test('create defaults + full mapping round-trip', () async {
    final a = await ds.create(params());
    expect(a.id, isNotEmpty);
    expect(a.version, 1);
    expect(a.currentBalanceCents, 1000);
    expect(a.status, AccountStatus.active);
    // Enum mapping survives the index+1 encoding both ways.
    expect(a.accountType, AccountType.liability);
    expect(a.category, AccountCategory.savings);
    expect(a.ownership, Ownership.joint);
    expect(a.interestRate, 2.5);
    expect(a.parentId, isEmpty); // '' stored as NULL, read back as ''

    final reRead = await ds.getById(a.id);
    expect(reRead, a); // Equatable round-trip
  });

  test('every category maps back (index+1 pinned, ADR-3)', () async {
    for (final c in AccountCategory.values) {
      final a = await ds.create(params(category: c));
      expect(a.category, c, reason: c.name);
    }
    expect((await ds.list()), hasLength(AccountCategory.values.length));
  });

  test('parentId and creditLimit special cases round-trip', () async {
    final a = await ds.create(params(parentId: 'p1', creditLimitCents: 900));
    expect(a.parentId, 'p1');
    expect(a.creditLimitCents, 900);

    final b = await ds.create(params(creditLimitCents: 0));
    expect(b.creditLimitCents, 0); // stored NULL, read back 0
  });

  test('update is a patch: absent fields untouched, version bumps', () async {
    final a = await ds.create(params(name: '原名'));
    final updated = await ds.update(UpdateAccountParams(
      id: a.id,
      version: a.version,
      name: '新名',
    ));
    expect(updated.name, '新名');
    expect(updated.interestRate, 2.5); // untouched
    expect(updated.currentBalanceCents, 1000); // untouched
    expect(updated.version, a.version + 1);
  });

  test('delete: zero balance succeeds, non-zero keeps the row', () async {
    final zero = await ds.create(params(initialBalanceCents: 0));
    await ds.delete(zero.id);
    expect(() => ds.getById(zero.id), throwsA(isA<ServerFailure>()));

    final nonZero = await ds.create(params(initialBalanceCents: 42));
    expect(
      () => ds.delete(nonZero.id),
      throwsA(isA<ServerFailure>()),
    );
    expect((await ds.list()).map((a) => a.id), contains(nonZero.id));
  });
}
