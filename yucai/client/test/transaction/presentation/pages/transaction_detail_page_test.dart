// OD-aligned widget test for TransactionDetailPage (detail OD alignment).
//
// Asserts the page mirrors yucai-transaction-trisize-9d3e / detail-transaction.html:
//   - page-head: 返回 link + h1 (description) + 编辑 (gold) + 更多 menu.
//   - col1 交易概要: 大金额 (42px mono) + chip (支出/收入) + meta-list
//     (交易日期 / 支付方式 / 备注 / 对账状态). OD **无「描述」行**(描述即 h1),
//     「标签」行待 DTO 加 tags 后补(detail 4fix gap1+gap2). TX-id present.
//   - col2 复式分录: JournalEntry 借/贷 side + acc+类型副标 + amt + je-bal
//     (借方/贷方合计) + je-foot(借贷平衡 差额) + je-formula(会计等式).
//   - col3 快捷操作: qa-items (编辑交易 / 复制交易 / 查看账单 / 删除交易[danger]).
//   - 同分类近期交易: rel-list (type icon: arrowDownLeft/Up/LeftRight + 名称/
//     账户/日期/金额,icon+金额色 按 type 区分;sub 显示支付账户名).
//   - Three breakpoints render without crashing.
//   - Amount colour follows the touched account types.
//   - initState self-drives the load.
//   - Delete qa-item → confirm dialog → DeleteTransactionRequested → repo.delete.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_detail_page.dart';

class _FakeTxnRepo extends Mock implements TransactionRepository {}
class _FakeAcctRepo extends Mock implements AccountRepository {}

final DateTime _date = DateTime(2026, 6, 19);

Transaction _expense() => Transaction(
      id: 't1',
      transactionDate: _date,
      description: '晚餐 餐厅',
      entries: const [
        TransactionEntry(
            accountId: 'exp-food', debitCents: 38000, creditCents: 0),
        TransactionEntry(
            accountId: 'acc-cmb', debitCents: 0, creditCents: 38000),
      ],
    );

/// SimpleIncome (复式记账的收入交易): 借 asset / 贷 income。
Transaction _income() => Transaction(
      id: 't1',
      transactionDate: _date,
      description: '工资',
      entries: const [
        TransactionEntry(
            accountId: 'acc-cmb', debitCents: 50000, creditCents: 0),
        TransactionEntry(
            accountId: 'inc-salary', debitCents: 0, creditCents: 50000),
      ],
    );

/// SimpleTransfer: both legs are asset accounts → neutral colour.
Transaction _transfer() => Transaction(
      id: 't1',
      transactionDate: _date,
      description: '转账',
      entries: const [
        TransactionEntry(
            accountId: 'acc-cmb', debitCents: 0, creditCents: 10000),
        TransactionEntry(
            accountId: 'acc-ali', debitCents: 10000, creditCents: 0),
      ],
    );

Transaction _recent(String id, int amount, {String assetId = 'acc-cmb'}) =>
    Transaction(
      id: id,
      transactionDate: _date,
      description: '早餐 $id',
      entries: [
        TransactionEntry(
            accountId: 'exp-food', debitCents: amount, creditCents: 0),
        TransactionEntry(
            accountId: assetId, debitCents: 0, creditCents: amount),
      ],
    );

Account _account(String id, String name, AccountType type) => Account(
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

Widget _harness({required Widget child}) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  late _FakeTxnRepo txnRepo;
  late _FakeAcctRepo acctRepo;

  setUp(() {
    txnRepo = _FakeTxnRepo();
    acctRepo = _FakeAcctRepo();
    registerFallbackValue(ListTransactionsParams());
    when(() => txnRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(_expense()));
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
            ListTransactionsResult(transactions: [
          _recent('r1', 1500),
          // r2 用不同支付账户(支付宝),让 detail 4fix gap4 的「rel-row sub
          // 显示支付账户名」有独立可断言信号(支付宝仅出现在 r2 sub)。
          _recent('r2', 2200, assetId: 'acc-ali'),
        ], nextPageToken: '')));
    when(() => acctRepo.list()).thenAnswer((_) async => dartz.Right([
          _account('exp-food', '餐饮', AccountType.expense),
          _account('acc-cmb', '招商银行', AccountType.asset),
          _account('acc-ali', '支付宝', AccountType.asset),
          _account('inc-salary', '工资', AccountType.income),
        ]));
    // Default delete stub (overridden in the delete test).
    when(() => txnRepo.delete(any()))
        .thenAnswer((_) async => dartz.Right(null));
  });

  /// Pumps the page. By default pre-dispatches LoadTransactionDetail (mirrors
  /// how list pages navigate in with the event already in flight). Pass
  /// [selfDriveOnly] = true to NOT pre-dispatch and verify initState triggers
  /// the load itself.
  Future<void> pumpPage(
    WidgetTester tester,
    Size size, {
    bool selfDriveOnly = false,
    Transaction Function()? txnOverride,
  }) async {
    if (txnOverride != null) {
      when(() => txnRepo.getById(any()))
          .thenAnswer((_) async => dartz.Right(txnOverride()));
    }
    // Set the real view size so layout constraints match the breakpoint
    // (MediaQuery.size alone makes ResponsiveLayout pick the right branch but
    // leaves layout constraints at the binding default 800x600 → squeezed cols).
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness(
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AccountRepository>.value(value: acctRepo),
        ],
        child: BlocProvider<TransactionBloc>(
          create: (_) {
            final b = TransactionBloc(txnRepo);
            if (!selfDriveOnly) {
              b.add(const LoadTransactionDetail('t1'));
            }
            return b;
          },
          child: const TransactionDetailPage(id: 't1'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'desktop (1440): OD layout — summary meta-list + journal balance/formula + qa-items + recent',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // page-head: 返回 link + h1 title (description).
    expect(find.text('返回'), findsOneWidget);
    expect(find.text('晚餐 餐厅'), findsWidgets);

    // Summary: big amount body (42px) + 支出 chip + TX-id.
    expect(find.textContaining('380'), findsWidgets);
    expect(find.text('支出'), findsOneWidget);
    expect(find.textContaining('TX-'), findsOneWidget);

    // meta-list: 支付方式 resolves to asset account; 对账状态 placeholder.
    expect(find.text('支付方式'), findsOneWidget);
    expect(find.text('招商银行'), findsWidgets);
    expect(find.text('对账状态'), findsOneWidget);
    expect(find.text('待对账'), findsOneWidget);
    // detail 4fix gap1: OD meta-list 无「描述」行(描述即 h1,不在 meta-list 重复)。
    expect(find.text('描述'), findsNothing);
    // detail 4fix gap3: 更多按钮触发器(OD .btn.icon-only 白底+框)仍在。
    expect(find.byIcon(LucideIcons.moreHorizontal), findsOneWidget);

    // Journal (OD col2 复式分录): card-title + DOUBLE-ENTRY + 借/贷 rows with
    // account-type subtitles + je-bal(借方/贷方合计) + je-foot(借贷平衡 差额)
    // + je-formula(会计等式 explainer)。
    expect(find.textContaining('分笔明细'), findsOneWidget);
    expect(find.text('DOUBLE-ENTRY'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('费用账户 · Expense'), findsOneWidget);
    expect(find.text('招商银行'), findsWidgets);
    expect(find.text('资产账户 · Asset'), findsOneWidget);
    expect(find.text('借方合计'), findsOneWidget);
    expect(find.text('贷方合计'), findsOneWidget);
    expect(find.textContaining('借贷平衡'), findsOneWidget);
    expect(find.textContaining('借贷差额'), findsOneWidget);
    expect(find.textContaining('会计等式'), findsOneWidget);
    expect(find.textContaining('权益等式始终保持平衡'), findsOneWidget);

    // Quick actions qa-items.
    expect(find.text('编辑交易'), findsOneWidget);
    expect(find.text('复制交易'), findsOneWidget);
    expect(find.text('查看账单'), findsOneWidget);
    expect(find.text('删除交易'), findsOneWidget);

    // Recent same-account transactions.
    expect(find.text('早餐 r1'), findsOneWidget);
    expect(find.text('早餐 r2'), findsOneWidget);
    // detail 4fix gap4: rel-row sub 现显示支付账户名(非分类名)。r2 用支付宝,
    // 「支付宝」仅出现在 r2 的 sub → findsOneWidget 锁定账户显示已落地。
    expect(find.text('支付宝'), findsOneWidget);
    // rel-list type icon(用户要求按 type 区分,非 per-category):r1/r2 均为支出
    // → arrowDownLeft(红)。2 行 → 2 个 icon(主交易 summary 不用此 icon)。
    expect(find.byIcon(LucideIcons.arrowDownLeft), findsNWidgets(2));

    // OD removed the legacy placeholder zones — assert they're gone.
    expect(find.text('AA 分摊'), findsNothing);
    expect(find.text('同商户交易'), findsNothing);
    expect(find.text('预算联动'), findsNothing);
  });

  testWidgets('tablet (1024): renders without crashing', (tester) async {
    await pumpPage(tester, const Size(1024, 768));
    expect(find.text('晚餐 餐厅'), findsWidgets);
    expect(find.textContaining('借贷平衡'), findsOneWidget);
  });

  testWidgets('mobile (390): renders stacked cards without crashing',
      (tester) async {
    await pumpPage(tester, const Size(390, 844));
    expect(find.text('晚餐 餐厅'), findsWidgets);
    expect(find.textContaining('借贷平衡'), findsOneWidget);
  });

  // ───────────────── Amount colour by account type ─────────

  /// Finds the summary big-amount Text (the 42px mono number) and returns its
  /// colour. The OD layout splits ¥ (20px) from the number (42px), so match on
  /// the large-font Text.
  Color? summaryAmountColor(WidgetTester tester) {
    Color? found;
    tester.widgetList<Text>(find.byType(Text)).forEach((t) {
      if (found != null) return;
      if ((t.style?.fontSize ?? 0) >= 40 && t.style?.color != null) {
        found = t.style!.color;
      }
    });
    return found;
  }

  testWidgets('amount colour: expense transaction → 支出红 (negative)',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    expect(summaryAmountColor(tester), AppColors.negative);
  });

  testWidgets('amount colour: income transaction → 收入绿 (positive)',
      (tester) async {
    await pumpPage(
      tester,
      const Size(1440, 900),
      txnOverride: _income,
    );
    expect(summaryAmountColor(tester), AppColors.positive);
  });

  testWidgets('amount colour: asset-only transfer → 中性色 (fg)',
      (tester) async {
    await pumpPage(
      tester,
      const Size(1440, 900),
      txnOverride: _transfer,
    );
    expect(summaryAmountColor(tester), AppColors.fg);
  });

  // ───────────────── initState self-drive ─────────────────

  testWidgets(
      'initState dispatches LoadTransactionDetail (self-drive on real route)',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900), selfDriveOnly: true);
    verify(() => txnRepo.getById('t1')).called(1);
    expect(find.text('晚餐 餐厅'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // ───────────────── Delete CRUD (Task 3.2) ─────────────────

  testWidgets(
      'delete qa-item → confirm dialog → DeleteTransactionRequested → repo.delete',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Tap the 删除交易 qa-item → opens confirm dialog.
    await tester.tap(find.text('删除交易'));
    await tester.pumpAndSettle();
    // Dialog body is unique (qa-item row has no such text).
    expect(find.textContaining('将生成一条冲销分录'), findsOneWidget);

    // Tap the dialog 删除 button → dispatches DeleteTransactionRequested.
    // The dialog button is the only '删除' Text (qa-item is '删除交易').
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    // repo.delete invoked once with the txn id.
    verify(() => txnRepo.delete('t1')).called(1);

    // Drain the 3s AppToast timer the success listener schedules (otherwise the
    // binding's timersPending invariant fails the test).
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
