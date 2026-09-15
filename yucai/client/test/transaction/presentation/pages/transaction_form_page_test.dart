// TDD three-size widget test for TransactionFormPage (OD form-transaction 对齐版).
//
// Asserts the御财 responsive breakpoints drive distinct layouts:
//   - 390   → mobile  → single column (form stacked above preview + hint)
//   - 1024  → tablet  → single column
//   - 1440  → desktop → two columns (form | preview side by side, preview 360px)
//
// Plus: type tabs switch card1 mode (3 mode 互斥); submit guard rejects empty
// amount; quick chips append to amount; tags chip-row toggles; preview is live.
//
// The bloc is wired via BlocProvider with a fake repo pair (no DI / no gRPC).
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';

class _FakeAccountRepo extends Mock implements AccountRepository {}

class _FakeTxnRepo extends Mock implements TransactionRepository {}

class _FakeTagRepo extends Mock implements TagRepository {}

final _assetAccount = Account(
  id: 'cash',
  name: '现金',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);
final _assetAccount2 = Account(
  id: 'bank',
  name: '招行储蓄卡',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);
final _expenseAccount = Account(
  id: 'food',
  name: '餐饮',
  accountType: AccountType.expense,
  category: AccountCategory.otherAsset,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

const _tagDaily = Tag(id: 't-daily', name: '日常', color: '#3B82F6', version: 1);
const _tagBiz = Tag(id: 't-biz', name: '出差', color: '#EF4444', version: 1);
final _allTags = [_tagDaily, _tagBiz];

final _date = DateTime(2026, 6, 19);

/// Opens a DropdownButtonFormField by tapping its [hint] text, then taps the
/// [option] menu item. Drives account selection in the form (asset / category).
Future<void> _openDropdownAndPick(
    WidgetTester tester, String hint, String option) async {
  await tester.tap(find.text(hint).first, warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  final getIt = GetIt.instance;
  late _FakeAccountRepo accountRepo;
  late _FakeTxnRepo txnRepo;
  late _FakeTagRepo tagRepo;

  setUp(() {
    // NOTE: do NOT call getIt.reset() here — in this env reset() defers
    // singleton disposal, which can wipe registrations made immediately after
    // it (leaving the page's initState getIt<TagRepository>() empty). Instead
    // allowReassignment lets registerSingleton overwrite cleanly per test.
    getIt.allowReassignment = true;
    accountRepo = _FakeAccountRepo();
    txnRepo = _FakeTxnRepo();
    tagRepo = _FakeTagRepo();
    // The form's initState reads TagRepository from getIt (ListTags +, on edit,
    // GetTransactionTags). Register a mock so the chip-row loads real tags.
    getIt.registerSingleton<TagRepository>(tagRepo);
    when(() => accountRepo.list()).thenAnswer(
        (_) async => dartz.Right([_assetAccount, _assetAccount2, _expenseAccount]));
    when(() => tagRepo.list()).thenAnswer((_) async => dartz.Right(_allTags));
    registerFallbackValue(
      RecordExpenseParams(
        transactionDate: _date,
        expenseAccountId: 'food',
        assetAccountId: 'cash',
        amountCents: 100,
      ),
    );
    registerFallbackValue(
      RecordIncomeParams(
        transactionDate: _date,
        assetAccountId: 'cash',
        incomeAccountId: 'food',
        amountCents: 100,
      ),
    );
    registerFallbackValue(
      RecordTransferParams(
        transactionDate: _date,
        fromAccountId: 'cash',
        toAccountId: 'bank',
        amountCents: 100,
      ),
    );
    registerFallbackValue(
      UpdateTransactionParams(
        id: 'x',
        version: 0,
        entries: const [],
      ),
    );
  });

  /// Pumps the page inside a BlocProvider at a fixed viewport width. Also
  /// awaits the async account load so the form is rendered.
  Future<void> pumpPage(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = TransactionFormBloc(txnRepo, accountRepo)
      ..add(const LoadAccountsRequested());
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 1000)),
        child: MaterialApp(
          home: TransactionFormPage(bloc: bloc),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders all form regions on mobile (390) — OD 对齐', (tester) async {
    await pumpPage(tester, 390);
    // page-head h1 + 保存 btn
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    // type tabs (3 segmented, sub-captions present)
    expect(find.text('支出'), findsWidgets);
    expect(find.text('花出去的钱'), findsOneWidget);
    expect(find.text('收进来的钱'), findsOneWidget);
    expect(find.text('账户间划转'), findsOneWidget);
    // amount hero
    expect(find.text('交易金额'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
    expect(find.text('清零'), findsOneWidget);
    // numbered sections
    expect(find.text('账户与分类'), findsOneWidget);
    expect(find.text('交易详情'), findsOneWidget);
    // tags chip-row(真 tag 从 TagRepository.list 加载)
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('出差'), findsOneWidget);
    // preview + hint
    expect(find.text('复式分录预览'), findsOneWidget);
    expect(find.text('录入提示'), findsOneWidget);
  });

  testWidgets('mobile & tablet are single-column (form above preview)', (tester) async {
    await pumpPage(tester, 390);
    final formCenter = tester.getCenter(find.text('交易金额'));
    final journalCenter = tester.getCenter(find.text('复式分录预览'));
    expect(formCenter.dy, lessThan(journalCenter.dy));
  });

  testWidgets('tablet (1024) single-column like mobile', (tester) async {
    await pumpPage(tester, 1024);
    final formCenter = tester.getCenter(find.text('交易金额'));
    final journalCenter = tester.getCenter(find.text('复式分录预览'));
    expect(formCenter.dy, lessThan(journalCenter.dy));
  });

  testWidgets('desktop (1440) renders form and preview side-by-side (2-col)',
      (tester) async {
    await pumpPage(tester, 1440);
    // 2-col：form center.x < preview center.x。
    final formCenter = tester.getCenter(find.text('交易金额'));
    final journalCenter = tester.getCenter(find.text('复式分录预览'));
    expect(formCenter.dx, lessThan(journalCenter.dx));
  });

  testWidgets('card1 3-mode 互斥：switching to 转账 hides 分类 fields',
      (tester) async {
    await pumpPage(tester, 1440);
    // default 支出 → 支出分类 field present
    expect(find.text('支出分类'), findsOneWidget);
    expect(find.text('转出账户'), findsOneWidget);
    // tap 转账 tab
    await tester.tap(find.text('转账').last);
    await tester.pumpAndSettle();
    // transfer mode → 转出/转入 (no category)
    expect(find.text('转出账户'), findsOneWidget);
    expect(find.text('转入账户'), findsOneWidget);
    expect(find.text('支出分类'), findsNothing);
    expect(find.text('收入分类'), findsNothing);
    // tap 收入 → 收入分类
    await tester.tap(find.text('收入').last);
    await tester.pumpAndSettle();
    expect(find.text('收入分类'), findsOneWidget);
    expect(find.text('支出分类'), findsNothing);
  });

  testWidgets('submit with empty amount does NOT call record (form guard)',
      (tester) async {
    await pumpPage(tester, 1440);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    verifyNever(() => txnRepo.recordExpense(any()));
    verifyNever(() => txnRepo.recordIncome(any()));
    verifyNever(() => txnRepo.recordTransfer(any()));
  });

  testWidgets('quick amount chips append to the amount field (千分位 ok)',
      (tester) async {
    await pumpPage(tester, 1440);
    await tester.tap(find.text('+50'));
    await tester.pump();
    final amountField =
        tester.widget<TextFormField>(find.byKey(const ValueKey('hero_amount')));
    expect((amountField.controller!.text), '50.00');
    // +1,000 chip → 千分位 (OD fmt: 1,050.00)
    await tester.tap(find.text('+1,000'));
    await tester.pump();
    expect((amountField.controller!.text), '1,050.00');
  });

  testWidgets('tags chip-row toggles on tap (真 tag state)', (tester) async {
    await pumpPage(tester, 1440);
    // 初始无 chip 选中 → 无 ✓ 标记
    expect(find.text('✓'), findsNothing);
    // 日常 chip 可能在 form 滚动区底部 → ensureVisible 后再 tap,确保命中。
    await tester.ensureVisible(find.text('日常'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();
    expect(find.text('✓'), findsOneWidget);
    // 再点 → off(✓ 消失)
    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();
    expect(find.text('✓'), findsNothing);
  });

  testWidgets(
      'edit mode pre-selects tags from GetTransactionTags (Task 5 tag 集成)',
      (tester) async {
    final existing = Transaction(
      id: 'txn-1',
      transactionDate: _date,
      version: 3,
      entries: [
        const TransactionEntry(
            accountId: 'food', debitCents: 100, creditCents: 0),
        const TransactionEntry(
            accountId: 'cash', debitCents: 0, creditCents: 100),
      ],
    );
    when(() => tagRepo.getTransactionTags('txn-1'))
        .thenAnswer((_) async => const dartz.Right([_tagDaily]));
    when(() => txnRepo.update(any()))
        .thenAnswer((_) async => dartz.Right(existing));

    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = TransactionFormBloc(txnRepo, accountRepo)
      ..add(const LoadAccountsRequested());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1440, 1000)),
        child: MaterialApp(
          home: TransactionFormPage(bloc: bloc, existing: existing),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 日常 预选(✓),出差 未选
    expect(find.text('✓'), findsOneWidget);
  });

  testWidgets(
      'create submits transaction then attaches selected tag via AddTag (Task 5)',
      (tester) async {
    await pumpPage(tester, 1440);
    // recordExpense → 新 transaction id 'new-1'
    when(() => txnRepo.recordExpense(any())).thenAnswer((_) async =>
        dartz.Right(
            Transaction(id: 'new-1', transactionDate: _date, entries: const [])));
    when(() => tagRepo.addTagToTransaction(
            tagId: any(named: 'tagId'),
            transactionId: any(named: 'transactionId')))
        .thenAnswer((_) async => const dartz.Right(null));

    // 选 日常 tag(ensureVisible 避免 chip 在滚动区底部漏点)
    await tester.ensureVisible(find.text('日常'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日常'));
    await tester.pumpAndSettle();
    expect(find.text('✓'), findsOneWidget, reason: '日常 chip 应被选中');
    // 金额(+50 chip)
    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    // 支出模式:转出账户(asset) + 支出分类(expense)
    await _openDropdownAndPick(tester, '例如：招商银行、现金', '现金');
    await _openDropdownAndPick(tester, '例如：餐饮、交通', '餐饮');
    // 提交(成功后 listener 异步跑 _syncTags → AddTag;pumpAndSettle 排空微任务)
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    verify(() => txnRepo.recordExpense(any())).called(1);
    // 新 txn 拿到 id 后,选中 tag 经 AddTag 持久化
    verify(() => tagRepo.addTagToTransaction(
        tagId: 't-daily', transactionId: 'new-1')).called(1);
    verifyNever(() => tagRepo.removeTagFromTransaction(
        tagId: any(named: 'tagId'),
        transactionId: any(named: 'transactionId')));
  });

  testWidgets('preview is live：amount 改 → preview 借/贷金额同步刷新',
      (tester) async {
    await pumpPage(tester, 1440);
    // 初始金额 0 → preview amt 显示 ¥0.00
    expect(find.text('¥0.00'), findsWidgets);
    // +50 → 金额 50.00 → preview 4 处同步刷新：借 row amt + 贷 row amt +
    // pv-bal-strip 借方合计 + 贷方合计。
    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    expect(find.text('¥50.00'), findsNWidgets(4));
  });

  testWidgets('time picker field present and defaults to HH:MM (Task 5)',
      (tester) async {
    await pumpPage(tester, 1440);
    expect(find.text('交易时间'), findsOneWidget);
    final hhMm = RegExp(r'^\d{2}:\d{2}$');
    final hhMmText = find
        .byWidgetPredicate((w) => w is Text && hhMm.hasMatch(w.data ?? ''))
        .evaluate()
        .map((e) => (e.widget as Text).data!)
        .toList();
    expect(hhMmText, isNotEmpty,
        reason: 'time field should display an HH:MM value');
  });
}
