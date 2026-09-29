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
//
// dev 反馈⑧ 分类两连坑回归:b) watch 流刷新下拉(分类页新建 → 表单实时可见);
// a) 表单内「+ 新建分类」入口 → 小对话框 → 创建 → 自动选中。
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';

class _FakeAccountRepo extends Mock implements AccountRepository {}

class _FakeTxnRepo extends Mock implements TransactionRepository {}

class _FakeTagRepo extends Mock implements TagRepository {}
class _FakeTplRepo extends Mock implements TemplateRepository {}

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
final _cardAccount = Account(
  id: 'card',
  name: '招商信用卡',
  accountType: AccountType.liability,
  category: AccountCategory.creditCard,
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

/// 反馈⑧ 场景:表单打开期间新建的支出分类(宠物)。
const _petExpense = Account(
  id: 'pet',
  name: '宠物',
  accountType: AccountType.expense,
  category: AccountCategory.otherAsset,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

/// 反馈⑧ 场景:表单内新建的收入分类(外快)。
const _sideIncome = Account(
  id: 'side',
  name: '外快',
  accountType: AccountType.income,
  category: AccountCategory.otherAsset,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

final _baseAccounts = [
  _assetAccount,
  _assetAccount2,
  _expenseAccount,
  _cardAccount,
];

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
  late _FakeTplRepo tplRepo;

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
    // 保存成功 listener bump DataRefreshNotifier(跨页刷新广播)。
    getIt.registerSingleton<DataRefreshNotifier>(DataRefreshNotifier());
    // v6 关联订阅:表单 initState 读 TemplateRepository(空列表 → 下拉不渲染)。
    tplRepo = _FakeTplRepo();
    getIt.registerSingleton<TemplateRepository>(tplRepo);
    when(() => tplRepo.list())
        .thenAnswer((_) async => dartz.Right(<Template>[]));
    when(() => tplRepo.list(paused: any(named: 'paused')))
        .thenAnswer((_) async => dartz.Right(<Template>[]));
    when(() => accountRepo.list()).thenAnswer(
        (_) async => dartz.Right([_assetAccount, _assetAccount2, _expenseAccount, _cardAccount]));
    // 反馈⑦:描述建议缺省空表(既有用例不受影响;建议用例单独覆写)。
    when(() => txnRepo.recentDescriptions())
        .thenAnswer((_) async => const dartz.Right(<String>[]));
    // 反馈⑧b:watch 缺省静默流(不发射 → 既有用例行为不变);watch 用例
    // 单独覆写为 StreamController 驱动。
    when(() => accountRepo.watchAccounts())
        .thenAnswer((_) => const Stream.empty());
    // 反馈⑧a:表单内新建分类走分类页同一创建服务(CreateAccountUseCase →
    // AccountRepository.create)。注册与生产 DI 同构的实例。
    getIt.registerSingleton<CreateAccountUseCase>(
        CreateAccountUseCase(accountRepo));
    registerFallbackValue(const CreateAccountParams(
      name: '',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
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
  Future<void> pumpPage(WidgetTester tester, double width,
      {String? initialAccountId}) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = TransactionFormBloc(txnRepo, accountRepo)
      ..add(const LoadAccountsRequested());
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 1000)),
        child: MaterialApp(
          home: TransactionFormPage(
              bloc: bloc, initialAccountId: initialAccountId),
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

  testWidgets('v6 关联订阅:支出提交成功后 markRecorded 推进订阅下次续费',
      (tester) async {
    registerFallbackValue(DateTime(2026, 1, 1));
    final tpl = Template(
      id: 'tpl-1',
      name: '健身房年卡',
      description: '',
      amountCents: 360000,
      direction: TemplateDirection.expense,
      sourceAccountId: 'cash',
      destinationAccountId: null,
      cycle: TemplateCycle.yearly,
      cycleDays: 0,
      billingDay: 0,
      interval: 1,
      weekdayMask: 0,
      monthlyMode: TemplateMonthlyMode.byDate,
      nth: 0,
      nextDate: '2027-03-01',
      startDate: '2026-03-01',
      endDate: null,
      autoRecord: false,
      paused: false,
      lastTransactionId: null,
      category: 'food',
      version: 1,
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );
    when(() => tplRepo.list()).thenAnswer((_) async => dartz.Right([tpl]));
    when(() => tplRepo.list(paused: any(named: 'paused')))
        .thenAnswer((_) async => dartz.Right([tpl]));
    when(() => tplRepo.markRecorded('tpl-1', 'new-1', any()))
        .thenAnswer((_) async => dartz.Right(tpl));
    when(() => txnRepo.recordExpense(any())).thenAnswer((_) async =>
        dartz.Right(
            Transaction(id: 'new-1', transactionDate: _date, entries: const [])));

    await pumpPage(tester, 1440);
    // 选关联订阅(2 列网格第 3 格,视口外需先滚入)
    await tester.ensureVisible(find.text('关联订阅(可选)'));
    await tester.pumpAndSettle();
    await _openDropdownAndPick(tester, '关联订阅(可选)', '健身房年卡');
    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    await _openDropdownAndPick(tester, '例如：招商银行、现金', '现金');
    await _openDropdownAndPick(tester, '例如：餐饮、交通', '餐饮');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    // 成功后 listener 异步 markRecorded + 成功 toast(3s 定时器):
    // 显式推进时间排空,避免 pumpAndSettle 悬挂 timer 断言。
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    verify(() => txnRepo.recordExpense(any())).called(1);
    // 交易入账成功 → 挂到订阅(交易 id + 表单日期)
    verify(() => tplRepo.markRecorded('tpl-1', 'new-1', any())).called(1);
  });

  testWidgets(
      '商户留空提交 → 描述自动填分类账户名(方案 2:列表不再出现「(无描述)」)',
      (tester) async {
    await pumpPage(tester, 1440);
    when(() => txnRepo.recordExpense(any())).thenAnswer((_) async =>
        dartz.Right(
            Transaction(id: 'new-2', transactionDate: _date, entries: const [])));
    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    await _openDropdownAndPick(tester, '例如：招商银行、现金', '现金');
    await _openDropdownAndPick(tester, '例如：餐饮、交通', '餐饮');
    // 商户(描述)留空不动,直接提交。
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured = verify(() => txnRepo.recordExpense(captureAny()))
        .captured
        .single as RecordExpenseParams;
    expect(captured.description, '餐饮',
        reason: '空商户 → 分类账户名兜底,描述永不为空');
  });

  testWidgets('转账商户留空提交 → 描述=「转账」字面(无分类账户可兜底)',
      (tester) async {
    await pumpPage(tester, 1440);
    when(() => txnRepo.recordTransfer(any())).thenAnswer((_) async =>
        dartz.Right(
            Transaction(id: 'new-3', transactionDate: _date, entries: const [])));
    await tester.tap(find.text('转账').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    await _openDropdownAndPick(tester, '钱从哪来', '现金');
    await _openDropdownAndPick(tester, '钱到哪去', '招行储蓄卡');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured = verify(() => txnRepo.recordTransfer(captureAny()))
        .captured
        .single as RecordTransferParams;
    expect(captured.description, '转账');
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


  group('F34 信用卡支付', () {
    testWidgets('支出转出账户下拉含信用卡且可选', (tester) async {
      await pumpPage(tester, 1440);
      await _openDropdownAndPick(tester, '例如：招商银行、现金', '招商信用卡');
      expect(find.text('招商信用卡'), findsWidgets);
    });

    testWidgets('信用卡详情记一笔:initialAccountId 带卡预选', (tester) async {
      await pumpPage(tester, 1440, initialAccountId: 'card');
      expect(find.text('招商信用卡'), findsWidgets);
    });

    testWidgets('刷卡提交:assetAccountId=卡(dr 支出/cr 信用卡)', (tester) async {
      await pumpPage(tester, 1440);
      when(() => txnRepo.recordExpense(any())).thenAnswer((_) async =>
          dartz.Right(
              Transaction(id: 'new-1', transactionDate: _date, entries: const [])));
      await tester.tap(find.text('+50'));
      await tester.pumpAndSettle();
      await _openDropdownAndPick(tester, '例如：招商银行、现金', '招商信用卡');
      await _openDropdownAndPick(tester, '例如：餐饮、交通', '餐饮');
      await tester.ensureVisible(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final captured =
          verify(() => txnRepo.recordExpense(captureAny())).captured;
      final params = captured.last as RecordExpenseParams;
      expect(params.assetAccountId, 'card');
      expect(params.expenseAccountId, 'food');
    });

    testWidgets('卡选中切转账:转出清空不崩溃,转账选项仍无信用卡', (tester) async {
      await pumpPage(tester, 1440);
      await _openDropdownAndPick(tester, '例如：招商银行、现金', '招商信用卡');
      expect(find.text('招商信用卡'), findsWidgets);
      await tester.tap(find.text('转账').last);
      await tester.pumpAndSettle(); // 守卫:不得触发下拉 value∉items 断言
      // 转出下拉重开,不含信用卡(asset-only 保持)
      await tester.tap(find.text('钱从哪来').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('招商信用卡'), findsNothing);
    });
  });

  // ───────── dev 反馈⑧:分类两连坑 ─────────

  group('反馈⑧b 分类下拉 watch 流实时刷新', () {
    testWidgets('表单打开状态下新建分类(页别处落库)→ watch 发射 → 下拉出现并可选中',
        (tester) async {
      final watch = StreamController<List<Account>>.broadcast();
      addTearDown(() => watch.close());
      when(() => accountRepo.watchAccounts()).thenAnswer((_) => watch.stream);
      await pumpPage(tester, 1440);

      // 初始:支出分类下拉无 宠物。
      await tester.tap(find.text('例如：餐饮、交通').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('宠物'), findsNothing);
      // 点 barrier 关闭下拉,再模拟分类页新建后本地库变更(watch 发射)。
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      watch.add([..._baseAccounts, _petExpense]);
      await tester.pumpAndSettle();

      // 下拉出现新分类并可选中。
      await tester.tap(find.text('例如：餐饮、交通').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('宠物'), findsOneWidget);
      await tester.tap(find.text('宠物').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      // 选中后字段本体显示 宠物(菜单已关,仅剩字段文本)。
      expect(find.text('宠物'), findsOneWidget);
    });
  });

  group('反馈⑧a 表单内新建分类入口', () {
    testWidgets('支出分类「+」→ 对话框 → 创建 expense 分类账户 → 自动选中', (tester) async {
      final watch = StreamController<List<Account>>.broadcast();
      addTearDown(() => watch.close());
      when(() => accountRepo.watchAccounts()).thenAnswer((_) => watch.stream);
      when(() => accountRepo.create(any()))
          .thenAnswer((_) async => const dartz.Right(_petExpense));
      await pumpPage(tester, 1440);

      // 入口仅挂在分类字段上(支出模式 1 个,资金账户字段无)。
      expect(find.byKey(const ValueKey('txn_form_new_category')), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('txn_form_new_category')));
      await tester.pumpAndSettle();
      // 对话框:标题按表单方向(支出)。
      expect(find.text('新建支出分类'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('txn_form_new_category_name')), '宠物');
      await tester
          .tap(find.byKey(const ValueKey('txn_form_new_category_submit')));
      await tester.pumpAndSettle();

      // 走分类页同一创建链:CreateAccountUseCase → AccountRepository.create,
      // 参数与 CategoryBloc 新建分支同构(expense 分类账户)。
      final captured =
          verify(() => accountRepo.create(captureAny())).captured.single
              as CreateAccountParams;
      expect(captured.name, '宠物');
      expect(captured.accountType, AccountType.expense);
      expect(captured.ownership, Ownership.personal);
      expect(captured.initialBalanceCents, 0);
      expect(captured.currencyCode, 'CNY');

      // 建完自动选中:watch 发射新列表 → 字段显示 宠物。
      watch.add([..._baseAccounts, _petExpense]);
      await tester.pumpAndSettle();
      expect(find.text('宠物'), findsOneWidget);
      // 成功 toast 的 overlay 定时器排空(照 v6 markRecorded 用例先例)。
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('收入方向 → 创建 income 分类;转账模式无入口', (tester) async {
      final watch = StreamController<List<Account>>.broadcast();
      addTearDown(() => watch.close());
      when(() => accountRepo.watchAccounts()).thenAnswer((_) => watch.stream);
      when(() => accountRepo.create(any()))
          .thenAnswer((_) async => const dartz.Right(_sideIncome));
      await pumpPage(tester, 1440);

      // 切到收入 tab → 收入分类字段同样有入口。
      await tester.tap(find.text('收入').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('txn_form_new_category')), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('txn_form_new_category')));
      await tester.pumpAndSettle();
      expect(find.text('新建收入分类'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('txn_form_new_category_name')), '外快');
      await tester
          .tap(find.byKey(const ValueKey('txn_form_new_category_submit')));
      await tester.pumpAndSettle();

      final captured =
          verify(() => accountRepo.create(captureAny())).captured.single
              as CreateAccountParams;
      expect(captured.name, '外快');
      expect(captured.accountType, AccountType.income);

      watch.add([..._baseAccounts, _sideIncome]);
      await tester.pumpAndSettle();
      expect(find.text('外快'), findsOneWidget);
      // 成功 toast 定时器排空。
      await tester.pump(const Duration(seconds: 4));

      // 转账模式无分类字段 → 无入口。
      await tester.tap(find.text('转账').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('txn_form_new_category')), findsNothing);
    });

    testWidgets('对话框留空直接创建 → 不落库(名称必填)', (tester) async {
      when(() => accountRepo.watchAccounts())
          .thenAnswer((_) => const Stream.empty());
      await pumpPage(tester, 1440);
      await tester.tap(find.byKey(const ValueKey('txn_form_new_category')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('txn_form_new_category_submit')));
      await tester.pumpAndSettle();
      verifyNever(() => accountRepo.create(any()));
      // 对话框仍开着(等有效输入)。
      expect(find.text('新建支出分类'), findsOneWidget);
    });

    // ───────── 反馈⑦:描述「最近使用」建议(页面接线,改版口径) ─────────

    testWidgets('表单描述字段:bloc 建议入页 → 聚焦弹最近 10 条 → 点击填入',
        (tester) async {
      when(() => txnRepo.recentDescriptions()).thenAnswer((_) async =>
          const dartz.Right([
            '永辉超市',
            '美团外卖',
            '地铁通勤',
            '午餐',
            '山姆会员店',
            '星巴克',
            '滴滴出行',
            '水电燃气',
            '京东购物',
            'Apple Store',
            '瑞幸咖啡', // 第 11 条:不弹
          ]));
      await pumpPage(tester, 1440);

      final field = find.byKey(const ValueKey('txn_form_payee_field'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      // 空值聚焦 → 最近 10 条(第 11 条不弹)。
      expect(find.text('永辉超市'), findsOneWidget);
      expect(find.text('Apple Store'), findsOneWidget);
      expect(find.text('瑞幸咖啡'), findsNothing);
      // 两列面板(GridView,相邻两条同行)。
      expect(find.byType(GridView), findsOneWidget);
      final a = tester.getTopLeft(find.text('永辉超市'));
      final b = tester.getTopLeft(find.text('美团外卖'));
      expect(a.dy, b.dy);
      expect(a.dx, lessThan(b.dx));

      // 鼠标点击建议 → 填入描述字段。
      await tester.tap(find.text('美团外卖'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller!.text, '美团外卖');

      // 键入过滤(contains):「午」只留 午餐。
      await tester.enterText(field, '午');
      await tester.pumpAndSettle();
      expect(find.text('午餐'), findsOneWidget);
      expect(find.text('永辉超市'), findsNothing);
    });

    testWidgets('空历史(建议空表)→ 描述字段为普通输入框,无建议浮层',
        (tester) async {
      await pumpPage(tester, 1440); // setUp 缺省 stub:Right([])
      // 降级分支:整页不出现 RawAutocomplete(描述字段退化为普通输入框)。
      expect(find.byType(RawAutocomplete<String>), findsNothing);
      final field = find.byKey(const ValueKey('txn_form_payee_field'));
      expect(field, findsNothing); // 降级分支无该 key(仅在建议分支挂)
      // 描述 label 仍在,手输不受影响。
      expect(find.text('交易对象 / 商户'), findsOneWidget);
    });
  });
}
