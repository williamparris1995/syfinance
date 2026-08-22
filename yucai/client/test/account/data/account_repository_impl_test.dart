// AccountRepositoryImpl tests — dual-source routing (R6 ADR-1) plus the
// pre-existing remote-path behaviors. Guest sessions route to the local data
// source (zero remote calls); every other session keeps the remote path.
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:drift/native.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Account;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

class _MockRemote extends Mock implements AccountRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase db;
  late SessionModeTracker tracker;
  late AccountRepositoryImpl repo;

  const sample = Account(
    id: 'a1', name: '现金', accountType: AccountType.asset, category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 1000, currentBalanceCents: 2000,
    ownership: Ownership.personal, status: AccountStatus.active,
  );

  setUp(() {
    remote = _MockRemote();
    db = AppDatabase(NativeDatabase.memory());
    tracker = SessionModeTracker();
    repo = AccountRepositoryImpl(remote, AccountLocalDataSource(db), tracker);
    registerFallbackValue(const CreateAccountParams(
      name: '', accountType: AccountType.asset, category: AccountCategory.savings,
      currencyCode: 'CNY', initialBalanceCents: 0, ownership: Ownership.personal,
    ));
  });

  tearDown(() async => db.close());

  group('remote path (non-guest, zero regression FR-3)', () {
    setUp(() => tracker.isGuest = false);

    test('list success returns Right with accounts', () async {
      when(() => remote.list()).thenAnswer((_) async => [sample]);
      final result = await repo.list();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (accounts) {
          expect(accounts.length, 1);
          expect(accounts.first.id, 'a1');
        },
      );
    });

    test('list unavailable maps to NetworkFailure', () async {
      when(() => remote.list()).thenThrow(const GrpcError.unavailable('down'));
      final result = await repo.list();
      expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
    });

    test('create success returns the created account', () async {
      const params = CreateAccountParams(
        name: '现金', accountType: AccountType.asset, category: AccountCategory.savings,
        currencyCode: 'CNY', initialBalanceCents: 1000, ownership: Ownership.personal,
      );
      when(() => remote.create(any())).thenAnswer((_) async => sample);
      final result = await repo.create(params);
      expect(result, const Right<Failure, Account>(sample));
    });

    test('delete success returns Right(null)', () async {
      when(() => remote.delete('a1')).thenAnswer((_) async {});
      final result = await repo.delete('a1');
      expect(result.isRight(), isTrue);
    });

    test('delete not found maps to ServerFailure', () async {
      when(() => remote.delete(any())).thenThrow(const GrpcError.notFound('gone'));
      final result = await repo.delete('x');
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });
  });

  group('routing (FR-1)', () {
    test('guest list reads local, zero remote calls', () async {
      tracker.isGuest = true;
      final result = await repo.list();
      expect(result.isRight(), isTrue);
      verifyNever(() => remote.list());
      result.fold((_) => fail('expected Right'), (accounts) {
        expect(accounts, isEmpty); // fresh memory db
      });
    });

    test('session switch flips the route for subsequent calls', () async {
      tracker.isGuest = false;
      when(() => remote.list()).thenAnswer((_) async => [sample]);
      expect((await repo.list()).fold((_) => [], (a) => a), hasLength(1));

      tracker.isGuest = true; // logout mid-session
      expect((await repo.list()).fold((_) => null, (a) => a), isEmpty);
      verify(() => remote.list()).called(1); // only the first call
    });

    test('guest create persists locally and round-trips', () async {
      tracker.isGuest = true;
      const params = CreateAccountParams(
        name: '储蓄', accountType: AccountType.asset, category: AccountCategory.savings,
        currencyCode: 'CNY', initialBalanceCents: 5000, ownership: Ownership.personal,
      );
      final created = await repo.create(params);
      expect(created.isRight(), isTrue);
      created.fold((_) => fail('expected Right'), (account) {
        expect(account.name, '储蓄');
        expect(account.currentBalanceCents, 5000);
        expect(account.version, 1);
        expect(account.id, isNotEmpty); // client-generated UUID
      });
      verifyNever(() => remote.create(any()));
    });

    test('guest delete with non-zero balance fails with the remote wording',
        () async {
      tracker.isGuest = true;
      const params = CreateAccountParams(
        name: 'x', accountType: AccountType.asset, category: AccountCategory.savings,
        currencyCode: 'CNY', initialBalanceCents: 5000, ownership: Ownership.personal,
      );
      await repo.create(params);
      final listed = await repo.list();
      final id = listed.fold((_) => fail('expected Right'), (a) => a.single.id);

      final result = await repo.delete(id);
      expect(
        result.fold((l) => l, (_) => null),
        isA<ServerFailure>().having(
            (f) => f.message, 'message', '账户余额非零，无法删除，请先清空余额或转账后再试'),
      );
    });
  });
}
