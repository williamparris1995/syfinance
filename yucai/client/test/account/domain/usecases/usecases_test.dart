import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRepo extends Mock implements AccountRepository {}

void main() {
  late _MockRepo repo;

  final sample = Account(
    id: 'a1', name: '现金', accountType: AccountType.asset, category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 0,
    ownership: Ownership.personal, status: AccountStatus.active,
  );

  setUp(() {
    repo = _MockRepo();
    registerFallbackValue(CreateAccountParams(
      name: '', accountType: AccountType.asset, category: AccountCategory.savings,
      currencyCode: 'CNY', initialBalanceCents: 0, ownership: Ownership.personal,
    ));
    registerFallbackValue(UpdateAccountParams(id: '', version: 0));
  });

  test('ListAccountsUseCase delegates to repo', () async {
    when(() => repo.list()).thenAnswer((_) async => Right([sample]));
    final result = await ListAccountsUseCase(repo).call();
    expect(result.isRight(), isTrue);
  });

  test('CreateAccountUseCase delegates to repo', () async {
    when(() => repo.create(any())).thenAnswer((_) async => Right(sample));
    final params = CreateAccountParams(
      name: '现金', accountType: AccountType.asset, category: AccountCategory.savings,
      currencyCode: 'CNY', initialBalanceCents: 0, ownership: Ownership.personal,
    );
    final result = await CreateAccountUseCase(repo).call(params);
    expect(result, Right(sample));
  });

  test('DeleteAccountUseCase delegates to repo', () async {
    when(() => repo.delete('a1')).thenAnswer((_) async => const Right(null));
    final result = await DeleteAccountUseCase(repo).call('a1');
    expect(result.isRight(), isTrue);
    verify(() => repo.delete('a1')).called(1);
  });

  test('CreateAccountUseCase propagates failure', () async {
    when(() => repo.create(any())).thenAnswer((_) async => const Left(ServerFailure('bad')));
    final result = await CreateAccountUseCase(repo).call(CreateAccountParams(
      name: 'x', accountType: AccountType.asset, category: AccountCategory.savings,
      currencyCode: 'CNY', initialBalanceCents: 0, ownership: Ownership.personal,
    ));
    expect(result.isLeft(), isTrue);
  });

  test('GetAccountUseCase delegates to repo', () async {
    when(() => repo.getById('a1')).thenAnswer((_) async => Right(sample));
    final result = await GetAccountUseCase(repo).call('a1');
    expect(result, Right(sample));
    verify(() => repo.getById('a1')).called(1);
  });

  test('UpdateAccountUseCase delegates to repo', () async {
    final params = UpdateAccountParams(id: 'a1', version: 1, name: '现金2');
    when(() => repo.update(any())).thenAnswer((_) async => Right(sample));
    final result = await UpdateAccountUseCase(repo).call(params);
    expect(result, Right(sample));
    verify(() => repo.update(params)).called(1);
  });
}
