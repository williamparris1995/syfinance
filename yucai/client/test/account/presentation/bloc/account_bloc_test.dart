import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}

final sample = Account(
  id: 'a1', name: '现金', accountType: AccountType.asset, category: AccountCategory.savings, currencyCode: 'CNY',
  initialBalanceCents: 0, currentBalanceCents: 0,
  ownership: Ownership.personal, status: AccountStatus.active,
);

final params = CreateAccountParams(
  name: '现金', accountType: AccountType.asset, category: AccountCategory.savings,
  currencyCode: 'CNY', initialBalanceCents: 0, ownership: Ownership.personal,
);

void main() {
  late _MockList listUc;
  late _MockCreate createUc;
  late _MockDelete deleteUc;

  setUp(() {
    listUc = _MockList();
    createUc = _MockCreate();
    deleteUc = _MockDelete();
    registerFallbackValue(params);
  });

  blocTest<AccountBloc, AccountState>(
    'Load emits [Loading, Loaded]',
    build: () {
      when(() => listUc.call()).thenAnswer((_) async => Right([sample]));
      return AccountBloc(listUc, createUc, deleteUc);
    },
    act: (b) => b.add(LoadAccountsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AccountLoading(), isA<AccountsLoaded>()],
  );

  blocTest<AccountBloc, AccountState>(
    'Load failure emits [Loading, Error]',
    build: () {
      when(() => listUc.call()).thenAnswer((_) async => const Left(ServerFailure('down')));
      return AccountBloc(listUc, createUc, deleteUc);
    },
    act: (b) => b.add(LoadAccountsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AccountLoading(), isA<AccountError>()],
  );

  blocTest<AccountBloc, AccountState>(
    'Create success refreshes the list',
    build: () {
      when(() => createUc.call(any())).thenAnswer((_) async => Right(sample));
      when(() => listUc.call()).thenAnswer((_) async => Right([sample]));
      return AccountBloc(listUc, createUc, deleteUc);
    },
    act: (b) => b.add(CreateAccountRequested(params)),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<AccountFormSubmitting>(),
      AccountLoading(),
      isA<AccountsLoaded>(),
    ],
  );

  blocTest<AccountBloc, AccountState>(
    'Delete success refreshes the list',
    build: () {
      when(() => deleteUc.call('a1')).thenAnswer((_) async => const Right(null));
      when(() => listUc.call()).thenAnswer((_) async => Right([sample]));
      return AccountBloc(listUc, createUc, deleteUc);
    },
    act: (b) => b.add(DeleteAccountRequested('a1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [AccountLoading(), isA<AccountsLoaded>()],
  );
}
