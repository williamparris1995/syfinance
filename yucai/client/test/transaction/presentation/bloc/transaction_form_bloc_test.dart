// TDD RED → GREEN: bloc for the 记一笔 form.
//
// Three record events map 1:1 to repo.recordExpense / recordIncome /
// recordTransfer. Success → RecordSuccess (page pops); failure → RecordError
// (stays on page, surfaces message). Initial state exposes loaded accounts so
// the category dropdown can render options.
//
// dev 反馈⑧b 回归:账户选项在首次 list() 后改为持续订阅
// AccountRepository.watchAccounts(本地漂移 watch)—— 表单打开期间分类页
// (或表单内入口)新建分类,Ready.accounts 实时合并,下拉即时出现。
import 'dart:async';
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

/// 反馈⑧b 场景:表单打开后新建的支出分类(宠物)。
const _expenseNew = Account(
  id: 'e2',
  name: '宠物',
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
    // 反馈⑦:描述建议缺省空表(既有用例不受影响;建议用例单独覆写)。
    when(() => txnRepo.recentDescriptions())
        .thenAnswer((_) async => const dartz.Right(<String>[]));
    // watch 流缺省静默(不订阅触发的既有用例不受影响;订阅用例单独覆写)。
    when(() => accountRepo.watchAccounts())
        .thenAnswer((_) => const Stream.empty());
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

  // ───────── 反馈⑦:描述「最近使用」建议加载 ─────────

  blocTest<TransactionFormBloc, TransactionFormState>(
    'Load 拉取描述建议并入 Ready(打开表单时一次,DB 不再被打)',
    build: () {
      when(() => txnRepo.recentDescriptions()).thenAnswer(
          (_) async => const dartz.Right(['永辉超市', '地铁通勤', '午餐']));
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) => b.add(const LoadAccountsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormLoading>(),
      isA<TransactionFormReady>()
          .having((s) => s.descriptionSuggestions, 'suggestions',
              ['永辉超市', '地铁通勤', '午餐']),
    ],
    verify: (b) {
      // 只拉一次(后续击键为内存过滤,不打 DB)。
      verify(() => txnRepo.recentDescriptions()).called(1);
    },
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    '建议加载失败(Left)静默降级为空,表单照常 Ready',
    build: () {
      when(() => txnRepo.recentDescriptions())
          .thenAnswer((_) async => const dartz.Left(ServerFailure('db down')));
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) => b.add(const LoadAccountsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormLoading>(),
      isA<TransactionFormReady>()
          .having((s) => s.descriptionSuggestions, 'suggestions', isEmpty),
    ],
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    '提交失败回退的 Ready 前向保留建议(不清空下拉)',
    build: () {
      when(() => txnRepo.recentDescriptions())
          .thenAnswer((_) async => const dartz.Right(['午餐']));
      when(() => txnRepo.recordExpense(any()))
          .thenAnswer((_) async => const dartz.Left(ServerFailure('boom')));
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) async {
      b.add(const LoadAccountsRequested());
      // 与本文件竞态用例同款节奏:先让 load 完成(Ready 带上建议),
      // 再提交失败 —— 断言失败回退的 Ready 不清空建议。
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(RecordExpenseRequested(
        transactionDate: _dummyDate,
        expenseAccountId: 'e1',
        assetAccountId: 'a1',
        amountCents: 100,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TransactionFormLoading>(),
      isA<TransactionFormReady>()
          .having((s) => s.descriptionSuggestions, 'suggestions', ['午餐']),
      isA<TransactionFormSubmitting>(),
      isA<TransactionFormReady>()
          .having((s) => s.error, 'error', 'boom')
          .having((s) => s.descriptionSuggestions, 'suggestions kept',
              ['午餐']),
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

  // Task 5 (WRITE-path transaction_time): when the event carries a
  // transactionTime, the bloc forwards it onto the RecordExpenseParams so the
  // data layer can stamp it onto the SimpleExpenseRequest proto.
  blocTest<TransactionFormBloc, TransactionFormState>(
    'RecordExpense forwards transactionTime onto params (Task 5)',
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
      transactionTime: _expectedRfc3339,
    )),
    wait: const Duration(milliseconds: 100),
    verify: (b) {
      verify(() => txnRepo.recordExpense(any(
          that: predicate<RecordExpenseParams>(
              (p) => p.transactionTime == _expectedRfc3339)))).called(1);
    },
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    'RecordIncome forwards transactionTime onto params (Task 5)',
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
      transactionTime: _expectedRfc3339,
    )),
    wait: const Duration(milliseconds: 100),
    verify: (b) {
      verify(() => txnRepo.recordIncome(any(
          that: predicate<RecordIncomeParams>(
              (p) => p.transactionTime == _expectedRfc3339)))).called(1);
    },
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    'RecordTransfer forwards transactionTime onto params (Task 5)',
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
      transactionTime: _expectedRfc3339,
    )),
    wait: const Duration(milliseconds: 100),
    verify: (b) {
      verify(() => txnRepo.recordTransfer(any(
          that: predicate<RecordTransferParams>(
              (p) => p.transactionTime == _expectedRfc3339)))).called(1);
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

  // ───────── dev 反馈⑧b:账户选项 watch 流 ─────────

  StreamController<List<Account>>? watchCtrl;

  tearDown(() async {
    final c = watchCtrl;
    watchCtrl = null;
    if (c != null && !c.isClosed) {
      await c.close();
    }
  });

  blocTest<TransactionFormBloc, TransactionFormState>(
    'watch 发射新账户列表 → Ready 实时合并(表单打开时新建分类 → 下拉可见)',
    build: () {
      // 反馈⑦回归:账户 watch 合并不得冲掉已加载的描述建议(前向保留)。
      when(() => txnRepo.recentDescriptions())
          .thenAnswer((_) async => const dartz.Right(['午餐']));
      watchCtrl = StreamController<List<Account>>();
      when(() => accountRepo.watchAccounts()).thenAnswer((_) => watchCtrl!.stream);
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) {
      b.add(const LoadAccountsRequested());
      // 单订阅流缓冲:bloc 稍后订阅仍能收到(模拟分类页新建后本地库变更)。
      watchCtrl!.add([_asset, _expense, _expenseNew]);
    },
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionFormLoading>(),
      isA<TransactionFormReady>()
          .having((s) => s.accounts.length, 'accounts', 2)
          .having((s) => s.descriptionSuggestions, 'suggestions', ['午餐']),
      isA<TransactionFormReady>()
          .having((s) => s.accounts.length, 'accounts', 3)
          .having((s) => s.accounts.any((a) => a.id == 'e2'),
              'contains new category', isTrue)
          .having((s) => s.descriptionSuggestions, 'suggestions kept',
              ['午餐']),
    ],
  );

  blocTest<TransactionFormBloc, TransactionFormState>(
    'Submitting/Success 期间 watch 发射不打断提交(余额写库触发 watch 的竞态守卫)',
    build: () {
      watchCtrl = StreamController<List<Account>>();
      when(() => accountRepo.watchAccounts()).thenAnswer((_) => watchCtrl!.stream);
      when(() => txnRepo.recordExpense(any())).thenAnswer((_) async {
        // RPC 在途 80ms:制造 watch 发射落在 Submitting 窗口内的竞态
        // (记账会更新账户余额 → 本地 accounts 表变更 → watch 触发)。
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return dartz.Right(_recorded);
      });
      return TransactionFormBloc(txnRepo, accountRepo);
    },
    act: (b) async {
      b.add(const LoadAccountsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(RecordExpenseRequested(
        transactionDate: _dummyDate,
        expenseAccountId: 'e1',
        assetAccountId: 'a1',
        amountCents: 100,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // 此刻 state == Submitting:发射必须被跳过,不得回到 Ready。
      watchCtrl!.add([_asset, _expense, _expenseNew]);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TransactionFormLoading>(),
      isA<TransactionFormReady>(),
      isA<TransactionFormSubmitting>(),
      isA<TransactionFormSuccess>(),
      // 没有第 5 个状态 —— watch 发射在提交窗口内被守卫吞掉。
    ],
    verify: (b) {
      verify(() => txnRepo.recordExpense(any())).called(1);
    },
  );
}

final _dummyDate = DateTime(2026, 6, 19);

// Task 5: an RFC3339 timestamp the form assembles from date + TimeOfDay.
// 2026-06-19T13:45:00.000Z is what (2026-06-19, 13:45 local) -> UTC yields
// in the UTC zone (test default); the form uses .toUtc().toIso8601String().
final _expectedRfc3339 =
    DateTime(2026, 6, 19, 13, 45).toUtc().toIso8601String();
