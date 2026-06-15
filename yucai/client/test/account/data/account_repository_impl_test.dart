import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRemote extends Mock implements AccountRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AccountRepositoryImpl repo;

  final sample = Account(
    id: 'a1', name: '现金', accountType: AccountType.asset, category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 1000, currentBalanceCents: 2000,
    ownership: Ownership.personal, status: AccountStatus.active,
  );

  setUp(() {
    remote = _MockRemote();
    repo = AccountRepositoryImpl(remote);
    registerFallbackValue(CreateAccountParams(
      name: '', accountType: AccountType.asset, category: AccountCategory.savings,
      currencyCode: 'CNY', initialBalanceCents: 0, ownership: Ownership.personal,
    ));
  });

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
    when(() => remote.list()).thenThrow(GrpcError.unavailable('down'));
    final result = await repo.list();
    expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
  });

  test('create success returns the created account', () async {
    final params = CreateAccountParams(
      name: '现金', accountType: AccountType.asset, category: AccountCategory.savings,
      currencyCode: 'CNY', initialBalanceCents: 1000, ownership: Ownership.personal,
    );
    when(() => remote.create(any())).thenAnswer((_) async => sample);
    final result = await repo.create(params);
    expect(result, Right<Failure, Account>(sample));
  });

  test('delete success returns Right(null)', () async {
    when(() => remote.delete('a1')).thenAnswer((_) async {});
    final result = await repo.delete('a1');
    expect(result.isRight(), isTrue);
  });

  test('delete not found maps to ServerFailure', () async {
    when(() => remote.delete(any())).thenThrow(GrpcError.notFound('gone'));
    final result = await repo.delete('x');
    expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
  });
}
