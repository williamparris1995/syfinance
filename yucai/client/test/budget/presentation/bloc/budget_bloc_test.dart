import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRepo extends Mock implements BudgetRepository {}

// —— 样本数据 ——

const sampleItem = BudgetItemView(
  id: 'i1',
  accountId: 'a1',
  accountName: 'Groceries',
  plannedAmountCents: 50000,
  actualAmountCents: 12000,
);

/// 列表用(BudgetDTO 路径,items 空)。
const sampleBudgetListItem = BudgetView(
  id: 'b1',
  name: 'June',
  month: '2026-06',
  currencyCode: 'CNY',
  totalAmountCents: 50000,
  totalActualCents: 12000,
  usagePct: 24,
  items: [],
);

/// 详情用(BudgetDetailDTO 路径,items 填充)。
const sampleBudgetDetail = BudgetView(
  id: 'b1',
  name: 'June',
  month: '2026-06',
  currencyCode: 'CNY',
  totalAmountCents: 50000,
  totalActualCents: 12000,
  usagePct: 24,
  items: [sampleItem],
);

const createItems = <({String accountId, int plannedAmountCents, String? notes})>[
  (accountId: 'a1', plannedAmountCents: 50000, notes: null),
];

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  // —— LoadListRequested ——

  blocTest<BudgetBloc, BudgetState>(
    'LoadListRequested emits [Loading, ListLoaded]',
    build: () {
      when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => Right([sampleBudgetListItem]));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const LoadListRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      BudgetLoading(),
      BudgetListLoaded([sampleBudgetListItem]),
    ],
  );

  blocTest<BudgetBloc, BudgetState>(
    'LoadListRequested(activeOnly: true) forwards flag to repo',
    build: () {
      when(() => repo.listBudgets(activeOnly: true))
          .thenAnswer((_) async => const Right([]));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const LoadListRequested(activeOnly: true)),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      BudgetLoading(),
      const BudgetListLoaded([]),
    ],
    verify: (b) {
      verify(() => repo.listBudgets(activeOnly: true)).called(1);
    },
  );

  // —— LoadDetailRequested ——

  blocTest<BudgetBloc, BudgetState>(
    'LoadDetailRequested emits [Loading, DetailLoaded]',
    build: () {
      when(() => repo.getBudget(any()))
          .thenAnswer((_) async => Right(sampleBudgetDetail));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('b1')),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      BudgetLoading(),
      BudgetDetailLoaded(sampleBudgetDetail),
    ],
    verify: (b) {
      verify(() => repo.getBudget('b1')).called(1);
    },
  );

  blocTest<BudgetBloc, BudgetState>(
    'LoadDetailRequested failure emits BudgetError',
    build: () {
      when(() => repo.getBudget(any()))
          .thenAnswer((_) async => const Left(ServerFailure('not found')));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('missing')),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      BudgetLoading(),
      isA<BudgetError>().having((s) => s.message, 'message', 'not found'),
    ],
  );

  // —— CreateBudgetRequested ——

  blocTest<BudgetBloc, BudgetState>(
    'CreateBudgetRequested success refreshes list (Loading deduped, ListLoaded)',
    build: () {
      when(() => repo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          )).thenAnswer((_) async => Right(sampleBudgetListItem));
      when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => Right([sampleBudgetListItem]));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const CreateBudgetRequested(
      name: 'June',
      month: '2026-06',
      currencyCode: 'CNY',
      items: createItems,
    )),
    wait: const Duration(milliseconds: 150),
    // Note: _onCreate emits BudgetLoading, then re-dispatches
    // LoadListRequested which emits BudgetLoading again — but bloc_test
    // dedupes consecutive equal Equatable states, so only one appears.
    expect: () => [
      BudgetLoading(),
      BudgetListLoaded([sampleBudgetListItem]),
    ],
    verify: (b) {
      verify(() => repo.createBudget(
            name: 'June',
            month: '2026-06',
            currencyCode: 'CNY',
            items: createItems,
          )).called(1);
    },
  );

  blocTest<BudgetBloc, BudgetState>(
    'CreateBudgetRequested failure emits BudgetError',
    build: () {
      when(() => repo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          )).thenAnswer((_) async => const Left(ServerFailure('dup month')));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const CreateBudgetRequested(
      name: 'June',
      month: '2026-06',
      currencyCode: 'CNY',
      items: createItems,
    )),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      BudgetLoading(),
      isA<BudgetError>().having((s) => s.message, 'message', 'dup month'),
    ],
    verify: (b) {
      verifyNever(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')));
    },
  );

  // —— DeleteBudgetRequested ——

  blocTest<BudgetBloc, BudgetState>(
    'DeleteBudgetRequested success refreshes list',
    build: () {
      when(() => repo.deleteBudget(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => const Right([]));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const DeleteBudgetRequested('b1')),
    wait: const Duration(milliseconds: 150),
    // BudgetLoading deduped (see CreateBudgetRequested test note).
    expect: () => [
      BudgetLoading(),
      const BudgetListLoaded([]),
    ],
    verify: (b) {
      verify(() => repo.deleteBudget('b1')).called(1);
    },
  );

  blocTest<BudgetBloc, BudgetState>(
    'DeleteBudgetRequested failure emits BudgetError',
    build: () {
      when(() => repo.deleteBudget(any()))
          .thenAnswer((_) async => const Left(ServerFailure('no perm')));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const DeleteBudgetRequested('b1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      BudgetLoading(),
      isA<BudgetError>().having((s) => s.message, 'message', 'no perm'),
    ],
  );

  // —— AddItemRequested: 关键 — addItem 返回无 items 的 BudgetView,
  // bloc 必须重新 getBudget 取完整 detail(含 items),而非直接 emit addItem 结果。

  blocTest<BudgetBloc, BudgetState>(
    'AddItemRequested re-fetches detail via getBudget (not the item-less addItem result)',
    build: () {
      when(() => repo.addItem(
            budgetId: any(named: 'budgetId'),
            accountId: any(named: 'accountId'),
            plannedAmountCents: any(named: 'plannedAmountCents'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => Right(sampleBudgetListItem)); // 无 items
      when(() => repo.getBudget(any()))
          .thenAnswer((_) async => Right(sampleBudgetDetail)); // 含 items
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const AddItemRequested(
      budgetId: 'b1',
      accountId: 'a1',
      plannedAmountCents: 50000,
    )),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      BudgetLoading(),
      BudgetDetailLoaded(sampleBudgetDetail),
    ],
    verify: (b) {
      // 关键:必须调 getBudget 取完整 detail,且用正确的 budgetId。
      verify(() => repo.getBudget('b1')).called(1);
    },
  );

  blocTest<BudgetBloc, BudgetState>(
    'AddItemRequested failure (addItem) emits BudgetError without getBudget',
    build: () {
      when(() => repo.addItem(
            budgetId: any(named: 'budgetId'),
            accountId: any(named: 'accountId'),
            plannedAmountCents: any(named: 'plannedAmountCents'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => const Left(ServerFailure('addItem fail')));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const AddItemRequested(
      budgetId: 'b1',
      accountId: 'a1',
      plannedAmountCents: 50000,
    )),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      BudgetLoading(),
      isA<BudgetError>().having((s) => s.message, 'message', 'addItem fail'),
    ],
    verify: (b) {
      // addItem fail 时不应再调 getBudget。
      verifyNever(() => repo.getBudget(any()));
    },
  );

  // —— RemoveItemRequested: 同 AddItem,成功后 re-fetch detail ——

  blocTest<BudgetBloc, BudgetState>(
    'RemoveItemRequested re-fetches detail via getBudget',
    build: () {
      when(() => repo.removeItem(
            budgetId: any(named: 'budgetId'),
            itemId: any(named: 'itemId'),
          )).thenAnswer((_) async => Right(sampleBudgetListItem)); // 无 items
      when(() => repo.getBudget(any()))
          .thenAnswer((_) async => Right(sampleBudgetDetail)); // 含 items
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const RemoveItemRequested(budgetId: 'b1', itemId: 'i1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      BudgetLoading(),
      BudgetDetailLoaded(sampleBudgetDetail),
    ],
    verify: (b) {
      verify(() => repo.getBudget('b1')).called(1);
    },
  );

  blocTest<BudgetBloc, BudgetState>(
    'RemoveItemRequested failure (removeItem) emits BudgetError',
    build: () {
      when(() => repo.removeItem(
            budgetId: any(named: 'budgetId'),
            itemId: any(named: 'itemId'),
          )).thenAnswer((_) async => const Left(ServerFailure('removeItem fail')));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const RemoveItemRequested(budgetId: 'b1', itemId: 'i1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      BudgetLoading(),
      isA<BudgetError>().having((s) => s.message, 'message', 'removeItem fail'),
    ],
    verify: (b) {
      verifyNever(() => repo.getBudget(any()));
    },
  );

  // —— LoadListRequested failure (整体 BudgetError 路径) ——

  blocTest<BudgetBloc, BudgetState>(
    'LoadListRequested failure emits BudgetError',
    build: () {
      when(() => repo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => const Left(ServerFailure('list down')));
      return BudgetBloc(repo);
    },
    act: (b) => b.add(const LoadListRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      BudgetLoading(),
      isA<BudgetError>().having((s) => s.message, 'message', 'list down'),
    ],
  );
}
