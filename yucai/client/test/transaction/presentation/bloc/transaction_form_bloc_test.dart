// TDD RED → GREEN: bloc for the 记一笔 form.
//
// Three record events map 1:1 to repo.recordExpense / recordIncome /
// recordTransfer. Success → RecordSuccess (page pops); failure → RecordError
// (stays on page, surfaces message). Initial state exposes loaded accounts so
// the category dropdown can render options.
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_state.dart';

class _MockTxnRepo extends Mock implements TransactionRepository {}

class _MockAccountRepo extends Mock implements AccountRepository {}

final _asset = Account(
  id: 'a1',
  name: '现金',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

final _expense = Account(
  id: 'e1',
  name: '餐饮',
  accountType: AccountType.expense,
  category: AccountCategory.otherAsset,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

final _recorded = Transaction(
  transactionDate: DateTime(2026, 6, 19),
  description: '午餐',
  entries: const [
    TransactionEntry(accountId: 'e1', debitCents: 3000, creditCents: 0),
    TransactionEntry(accountId: 'a1', debitCents: 0, creditCents: 3000),
  ],
);

void main() {
  late _MockTxnRepo txnRepo;
  late _MockAccountRepo accountRepo;

  setUp(() {
    txnRepo = _MockTxnRepo();
    accountRepo = _MockAccountRepo();
    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right([_asset, _expense]));
    registerFallbackValue(
      RecordExpenseParams(
        transactionDate: _dummyDate,
        expenseAccountId: 'e1',
        assetAccountId: 'a1',
        amountCents: 100,
      ),
    );
    registerFallbackValue(
      RecordIncomeParams(
        transactionDate: _dummyDate,
        assetAccountId: 'a1',
        incomeAccountId: 'i1',
        amountCents: 100,
      ),
    );
    registerFallbackValue(
      RecordTransferParams(
        transactionDate: _dummyDate,
        fromAccountId: 'a1',
        toAccountId: 'a2',
        amountCents: 100,
      ),
    );
  });

  blocTest<TransactionFormBloc, TransactionFormState>(
    'initial LoadAccounts emits [Loading, Ready]',
    build: () => TransactionFormBloc(txnRepo, accountRepo),
    act: (b) => b.add(const LoadAccountsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormLoading>(),
      isA<TransactionFormReady>(),
    ],
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    'RecordExpense success emits [Submitting, Success]',
    build: () {
      when(() => txnRepo.recordExpense(any()))
          .thenAnswer((_) async => dartz.Right(_recorded));
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) => b.add(RecordExpenseRequested(
      transactionDate: _dummyDate,
      expenseAccountId: 'e1',
      assetAccountId: 'a1',
      amountCents: 100,
      description: '午餐',
    )),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormSubmitting>(),
      isA<TransactionFormSuccess>(),
    ],
    verify: (b) {
      verify(() => txnRepo.recordExpense(any())).called(1);
    },
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    'RecordIncome success emits [Submitting, Success]',
    build: () {
      when(() => txnRepo.recordIncome(any()))
          .thenAnswer((_) async => dartz.Right(_recorded));
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) => b.add(RecordIncomeRequested(
      transactionDate: _dummyDate,
      assetAccountId: 'a1',
      incomeAccountId: 'e1',
      amountCents: 100,
    )),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormSubmitting>(),
      isA<TransactionFormSuccess>(),
    ],
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    'RecordTransfer success emits [Submitting, Success]',
    build: () {
      when(() => txnRepo.recordTransfer(any()))
          .thenAnswer((_) async => dartz.Right(_recorded));
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) => b.add(RecordTransferRequested(
      transactionDate: _dummyDate,
      fromAccountId: 'a1',
      toAccountId: 'a2',
      amountCents: 100,
    )),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormSubmitting>(),
      isA<TransactionFormSuccess>(),
    ],
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    'Record failure emits [Submitting, Ready with error]',
    build: () {
      when(() => txnRepo.recordExpense(any()))
          .thenAnswer((_) async => const dartz.Left(ServerFailure('boom')));
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) => b.add(RecordExpenseRequested(
      transactionDate: _dummyDate,
      expenseAccountId: 'e1',
      assetAccountId: 'a1',
      amountCents: 100,
    )),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormSubmitting>(),
      isA<TransactionFormReady>()
          .having((s) => s.error, 'error', 'boom'),
    ],
  );
}

final _dummyDate = DateTime(2026, 6, 19);
