// TDD bloc test for CategoryBloc.
//
// CategoryBloc wraps the account repository (categories = accounts with
// accountType expense/income). It:
//   - loads categories filtered by [CategoryType]
//   - creates a new category account
//   - updates an existing category account
//   - deletes a category account (server rejects is_system; client guards too)
//   - reorders the local list (no server RPC yet — visual only, Task 5 wires)
//
// Tests mock the account use-cases (same pattern as account_bloc_test.dart).
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_state.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

Account _cat(String id, String name, AccountType type) => Account(
      id: id,
      name: name,
      accountType: type,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

void main() {
  late _MockList listUc;
  late _MockCreate createUc;
  late _MockDelete deleteUc;
  late _MockUpdate updateUc;

  final expenseAccounts = [
    _cat('e1', '餐饮', AccountType.expense), // preset → isSystem
    _cat('e2', '自定义', AccountType.expense),
  ];
  final incomeAccounts = [
    _cat('i1', '工资', AccountType.income), // preset → isSystem
  ];

  setUp(() {
    listUc = _MockList();
    createUc = _MockCreate();
    deleteUc = _MockDelete();
    updateUc = _MockUpdate();
    registerFallbackValue(CreateAccountParams(
      name: 'x',
      accountType: AccountType.expense,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    registerFallbackValue(const UpdateAccountParams(id: 'e2', version: 1));
  });

  blocTest<CategoryBloc, CategoryState>(
    'Load expense emits [Loading, Loaded] filtered to expense type',
    build: () {
      when(() => listUc.call())
          .thenAnswer((_) async => Right([...expenseAccounts, ...incomeAccounts]));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    act: (b) => b.add(const LoadCategoriesRequested(CategoryType.expense)),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<CategoryLoading>(),
      isA<CategoryLoaded>(),
    ],
    verify: (bloc) {
      final state = bloc.state as CategoryLoaded;
      expect(state.type, CategoryType.expense);
      expect(state.categories.length, 2);
      // preset name 餐饮 → isSystem true
      expect(state.categories.first.isSystem, isTrue);
      expect(state.categories.last.isSystem, isFalse);
      // Bug 2: both type counts derived from full accounts (2 expense + 1
      // income), not just the selected type.
      expect(state.expenseCount, 2);
      expect(state.incomeCount, 1);
    },
  );

  blocTest<CategoryBloc, CategoryState>(
    'Load income keeps expense count visible on the non-selected tab',
    build: () {
      when(() => listUc.call())
          .thenAnswer((_) async => Right([...expenseAccounts, ...incomeAccounts]));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    act: (b) => b.add(const LoadCategoriesRequested(CategoryType.income)),
    wait: const Duration(milliseconds: 100),
    verify: (bloc) {
      final state = bloc.state as CategoryLoaded;
      expect(state.type, CategoryType.income);
      // categories filtered to income only (1), but counts cover both types.
      expect(state.categories.length, 1);
      expect(state.expenseCount, 2);
      expect(state.incomeCount, 1);
    },
  );

  blocTest<CategoryBloc, CategoryState>(
    'Save edit dispatches UpdateAccountParams with parentId (Bug 1)',
    build: () {
      when(() => updateUc.call(any()))
          .thenAnswer((_) async => Right(expenseAccounts.first));
      when(() => listUc.call())
          .thenAnswer((_) async => Right(expenseAccounts));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    seed: () => CategoryLoaded(
      type: CategoryType.expense,
      categories: expenseAccounts.map((a) => CategoryItem.fromAccount(a)).toList(),
    ),
    act: (b) => b.add(SaveCategoryRequested(
      type: CategoryType.expense,
      name: '外卖',
      id: 'e2',
      version: 1,
      icon: 'utensils',
      color: '#FF6B6B',
      parentId: 'e1',
    )),
    wait: const Duration(milliseconds: 150),
    verify: (bloc) {
      final captured = verify(() => updateUc.call(captureAny())).captured.single
          as UpdateAccountParams;
      expect(captured.id, 'e2');
      expect(captured.parentId, 'e1');
    },
  );

  blocTest<CategoryBloc, CategoryState>(
    'Load failure emits [Loading, Error]',
    build: () {
      when(() => listUc.call())
          .thenAnswer((_) async => const Left(ServerFailure('down')));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    act: (b) => b.add(const LoadCategoriesRequested(CategoryType.income)),
    wait: const Duration(milliseconds: 100),
    expect: () => [isA<CategoryLoading>(), isA<CategoryError>()],
  );

  blocTest<CategoryBloc, CategoryState>(
    'Create success refreshes the list',
    build: () {
      when(() => createUc.call(any()))
          .thenAnswer((_) async => Right(expenseAccounts.first));
      when(() => listUc.call())
          .thenAnswer((_) async => Right(expenseAccounts));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    act: (b) => b.add(SaveCategoryRequested(
      type: CategoryType.expense,
      name: '外卖',
      icon: 'utensils',
      color: '#FF6B6B',
    )),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<CategorySubmitting>(),
      isA<CategoryLoading>(),
      isA<CategoryLoaded>(),
    ],
  );

  blocTest<CategoryBloc, CategoryState>(
    'Delete non-system success refreshes the list',
    build: () {
      when(() => deleteUc.call('e2')).thenAnswer((_) async => const Right(null));
      when(() => listUc.call())
          .thenAnswer((_) async => Right(expenseAccounts));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    seed: () => CategoryLoaded(
      type: CategoryType.expense,
      categories: expenseAccounts
          .map((a) => CategoryItem.fromAccount(a))
          .toList(),
    ),
    act: (b) => b.add(const DeleteCategoryRequested('e2')),
    wait: const Duration(milliseconds: 150),
    expect: () => [isA<CategoryLoading>(), isA<CategoryLoaded>()],
  );

  blocTest<CategoryBloc, CategoryState>(
    'Delete system category is blocked client-side (no RPC, error emitted)',
    build: () {
      when(() => deleteUc.call(any())).thenAnswer((_) async => const Right(null));
      when(() => listUc.call())
          .thenAnswer((_) async => Right(expenseAccounts));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    seed: () => CategoryLoaded(
      type: CategoryType.expense,
      categories: expenseAccounts
          .map((a) => CategoryItem.fromAccount(a))
          .toList(),
    ),
    act: (b) => b.add(const DeleteCategoryRequested('e1')),
    wait: const Duration(milliseconds: 100),
    verify: (bloc) {
      verifyNever(() => deleteUc.call(any()));
    },
    expect: () => [isA<CategoryError>()],
  );

  blocTest<CategoryBloc, CategoryState>(
    'Reorder swaps local list without RPC',
    build: () {
      when(() => listUc.call())
          .thenAnswer((_) async => Right(expenseAccounts));
      return CategoryBloc(listUc, createUc, deleteUc, updateUc);
    },
    seed: () => CategoryLoaded(
      type: CategoryType.expense,
      categories: expenseAccounts
          .map((a) => CategoryItem.fromAccount(a))
          .toList(),
    ),
    act: (b) => b.add(const ReorderCategoriesRequested(oldIndex: 0, newIndex: 2)),
    wait: const Duration(milliseconds: 50),
    expect: () => [isA<CategoryLoaded>()],
    verify: (bloc) {
      final state = bloc.state as CategoryLoaded;
      // ReorderableListView semantics: 0 → 2 moves item 0 past item 1.
      expect(state.categories.first.id, 'e2');
      expect(state.categories.last.id, 'e1');
    },
  );
}
