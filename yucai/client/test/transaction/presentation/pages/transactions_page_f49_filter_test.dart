// F49 T4(FR-3)交易筛选账户下拉过滤 —— isSystem 载体户退出选择器选项集。
// 断言走真实菜单打开(行为面):账户 picker 菜单 = 全部 + 可见账户,
// 载体户名不出现;分类 picker 同口径(载体的 loan 分类不新增选项)。
// 行渲染的名称解析(accountNameOf/accountOf)不在本文件断言 —— 接线只滤
// options 构造,lookup 列表原样传递(生产代码可见 transactions_page
// _buildHeaderBlock 注释)。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transactions_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart'
    show TxnFilterBar;

class _FakeTxnRepo extends Mock implements TransactionRepository {}
class _FakeAccountRepo extends Mock implements AccountRepository {}

const _cash = Account(
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

/// F49 载体户:卡贷并入模式,isSystem=true(应退出筛选选项)。
const _carrier = Account(
  id: 'l-carrier',
  name: '平安信用卡 · 卡贷',
  accountType: AccountType.liability,
  category: AccountCategory.loan,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 840000,
  ownership: Ownership.personal,
  status: AccountStatus.active,
  isSystem: true,
  notes: '信用卡贷款(卡贷)自动创建',
);

void main() {
  late _FakeTxnRepo txnRepo;

  setUp(() {
    txnRepo = _FakeTxnRepo();
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          Transaction(
            id: 't1',
            transactionDate: DateTime(2026, 6, 19),
            description: '卡贷放款',
            // 现金(asset) ↔ 载体(liability)。
            entries: const [
              TransactionEntry(
                  accountId: 'a1', debitCents: 840000, creditCents: 0),
              TransactionEntry(
                  accountId: 'l-carrier', debitCents: 0, creditCents: 840000),
            ],
          ),
        ], nextPageToken: '')));
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 0,
              expenseCents: 0,
              netCents: 0,
              dailyAvgCents: 0,
            )));
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accountRepo = _FakeAccountRepo();
    when(() => accountRepo.list())
        .thenAnswer((_) async => const dartz.Right([_cash, _carrier]));

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1440, 900)),
        child: Scaffold(
          body: RepositoryProvider<AccountRepository>.value(
            value: accountRepo,
            child: BlocProvider<TransactionBloc>(
              create: (_) {
                final b = TransactionBloc(txnRepo);
                b.add(const LoadTransactionsRequested(
                    pageSize: TransactionsPage.listPageSize));
                return b;
              },
              child: const TransactionsPage(),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// 点开筛选条内某个 picker(label 文本定位,scope 到 TxnFilterBar)。
  Future<void> openPicker(WidgetTester tester, String label) async {
    final target = find
        .descendant(
          of: find.byType(TxnFilterBar),
          matching: find.text(label),
        )
        .first;
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('账户筛选菜单:可见账户在,isSystem 载体户不在(FR-3)', (t) async {
    await pumpPage(t);

    // 行渲染的名称解析走全量:载体上的交易在行内显示户名(而非 #id)。
    final carrierCount = find.text('平安信用卡 · 卡贷').evaluate().length;
    expect(carrierCount, greaterThanOrEqualTo(1),
        reason: '行名称解析不受选择器过滤影响');

    // 打开账户 picker(label「账户」)→ 弹出「全部账户 + 选项」菜单。
    // 「全部账户」两处 = 关闭态字段显示 + 菜单项(菜单未开则只有一处)。
    await openPicker(t, '账户');
    expect(find.text('全部账户'), findsNWidgets(2), reason: '菜单已打开');
    expect(find.text('现金'), findsWidgets, reason: '可见账户在选项中');

    // 载体退出选项集:菜单打开后载体文本数不增(未过滤时菜单会 +1)。
    expect(find.text('平安信用卡 · 卡贷').evaluate().length, carrierCount,
        reason: 'isSystem 载体户不可见不可选(FR-3)');
  });

  testWidgets('分类筛选菜单:载体 loan 分类不新增选项(选项由可见账户派生)',
      (t) async {
    await pumpPage(t);

    await openPicker(t, '分类');
    // 同上:关闭态字段 + 菜单项各一处。
    expect(find.text('全部分类'), findsNWidgets(2), reason: '菜单已打开');
    expect(find.text('储蓄'), findsWidgets, reason: '现金的 savings 分类在');

    // 未过滤时载体会贡献「贷款」分类选项 → 此断言翻红。
    expect(find.text('贷款'), findsNothing,
        reason: '分类选项由可见账户派生,载体不贡献 loan 分类');
  });
}
