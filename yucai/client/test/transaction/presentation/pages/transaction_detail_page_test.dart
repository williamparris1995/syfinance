// OD-aligned widget test for TransactionDetailPage (detail OD alignment).
//
// Asserts the page mirrors yucai-transaction-trisize-9d3e / detail-transaction.html:
//   - page-head: h1 (description). 返回 link + 编辑 gold + 更多 menu 均退役
//     (F59 FR-7/FR-4 — back goes through the shell breadcrumb; edit/copy/delete
//     migrate into the right-bottom FloatingActionDock).
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
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:design_kit/design_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/shell_detail_title.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_detail_page.dart';

class _FakeTxnRepo extends Mock implements TransactionRepository {}
class _FakeAcctRepo extends Mock implements AccountRepository {}
class _FakeTagRepo extends Mock implements TagRepository {}

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
  final getIt = GetIt.instance;
  late _FakeTxnRepo txnRepo;
  late _FakeAcctRepo acctRepo;
  late _FakeTagRepo tagRepo;

  setUp(() {
    // allowReassignment (no reset()) — see transaction_form_page_test note.
    getIt.allowReassignment = true;
    txnRepo = _FakeTxnRepo();
    acctRepo = _FakeAcctRepo();
    tagRepo = _FakeTagRepo();
    getIt.registerSingleton<TagRepository>(tagRepo);
    // 删除成功 listener bump DataRefreshNotifier(跨页刷新广播)。
    getIt.registerSingleton<DataRefreshNotifier>(DataRefreshNotifier());
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue('');
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
    // Default: no tags → 标签 row shows '—'. Overridden in the tag test.
    when(() => tagRepo.getTransactionTags(any()))
        .thenAnswer((_) async => dartz.Right(<Tag>[]));
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

    // page-head: 返回 link retired (F59 FR-7 — page-level back goes through
    // the shell breadcrumb) + h1 title (description).
    expect(find.text('返回'), findsNothing,
        reason: 'F59 FR-7:page-head 返回链接退役,回退统一走顶栏面包屑 page 级');
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
    // F59 T3:更多菜单退役(复制/删除迁 dock muted 淡显;占位 toast 项随菜单退场)。
    expect(find.byIcon(LucideIcons.moreHorizontal), findsNothing);

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

  // ───────────────── Tag chip row (Task 6) ─────────────────

  testWidgets(
      'meta-list 标签 row: GetTransactionTags chips render (read-only, non-toggle)',
      (tester) async {
    final tags = <Tag>[
      const Tag(id: 'tg-a', name: '日常', color: '#3B82F6', version: 1),
      const Tag(id: 'tg-b', name: '出差', color: '#EF4444', version: 1),
    ];
    when(() => tagRepo.getTransactionTags(any()))
        .thenAnswer((_) async => dartz.Right(tags));

    await pumpPage(tester, const Size(1440, 900));

    // 标签 row label present.
    expect(find.text('标签'), findsOneWidget);
    // Both tag names render as chips in the meta-list.
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('出差'), findsOneWidget);
  });

  testWidgets('meta-list 标签 row: empty tags → "—" placeholder', (tester) async {
    // Default setUp stub returns [] → 标签 row shows '—'.
    await pumpPage(tester, const Size(1440, 900));

    expect(find.text('标签'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  // ───────────────── F59 T3: page-head 金钮/菜单迁悬浮簇 ─────────────────

  group('F59 T3 迁移', () {
    testWidgets('page-head 无金钮无菜单;dock=编辑(primary)+[复制交易,删除交易]'
        '(muted) 常驻右下 28', (tester) async {
      await pumpPage(tester, const Size(1440, 900));

      expect(find.byType(FloatingActionDock), findsOneWidget);
      final pos = tester.widget<Positioned>(
          find.ancestor(
              of: find.byType(FloatingActionDock),
              matching: find.byType(Positioned)).first);
      expect(pos.right, 28);
      expect(pos.bottom, 28);
      // 三段映射:编辑进金圆(原 page-head 金主钮);复制/删除入淡显组
      //(危险置顶 —— 删除渲染在复制之上,离主钮最远)。
      final dock =
          tester.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.tooltip, '编辑');
      expect(dock.primary.onTap, isNotNull, reason: 'loaded → 可触发');
      expect(dock.secondary, isEmpty);
      expect(dock.muted.map((a) => a.tooltip).toList(),
          ['复制交易', '删除交易']);
      expect(dock.muted.every((a) => a.onTap != null), isTrue);
    });

    testWidgets('dock 编辑 tap → push /transactions/:id/edit', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? pushedId;
      final router = GoRouter(
        initialLocation: '/transactions/t1',
        routes: [
          GoRoute(
            path: '/transactions/:id',
            builder: (_, state) => BlocProvider<TransactionBloc>(
              create: (_) => TransactionBloc(txnRepo),
              child: TransactionDetailPage(id: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/transactions/:id/edit',
            builder: (_, state) {
              pushedId = state.pathParameters['id'];
              return const Scaffold(body: Center(child: Text('EDIT_STUB')));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();

      expect(pushedId, 't1');
      expect(find.text('EDIT_STUB'), findsOneWidget);
    });

    testWidgets('dock 复制 tap → push /transactions/new(extra 携带源交易)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Object? pushedExtra;
      final router = GoRouter(
        initialLocation: '/transactions/t1',
        routes: [
          // 字面量 new 路由必须先于 :id 通配,否则 "new" 会被 :id 捕获。
          GoRoute(
            path: '/transactions/new',
            builder: (_, state) {
              pushedExtra = state.extra;
              return const Scaffold(body: Center(child: Text('NEW_STUB')));
            },
          ),
          GoRoute(
            path: '/transactions/:id',
            builder: (_, state) => BlocProvider<TransactionBloc>(
              create: (_) => TransactionBloc(txnRepo),
              child: TransactionDetailPage(id: state.pathParameters['id']!),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('复制交易'));
      await tester.pumpAndSettle();

      expect(find.text('NEW_STUB'), findsOneWidget);
      // clone-to-new:extra 携带源交易(表单全字段预填;与 col3 复制同语义)。
      expect(pushedExtra, isA<Transaction>());
    });

    testWidgets('dock 删除 tap → confirm dialog → DeleteTransactionRequested '
        '→ repo.delete', (tester) async {
      await pumpPage(tester, const Size(1440, 900));

      await tester.tap(find.byTooltip('删除交易'));
      await tester.pumpAndSettle();
      expect(find.textContaining('将生成一条冲销分录'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      verify(() => txnRepo.delete('t1')).called(1);
      // Drain the 3s AppToast timer the success listener schedules.
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    testWidgets('loading 恒渲染 dock:全动作禁用', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final completer = Completer<dartz.Either<Failure, Transaction>>();
      when(() => txnRepo.getById(any())).thenAnswer((_) => completer.future);

      await tester.pumpWidget(_harness(
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AccountRepository>.value(value: acctRepo),
          ],
          child: BlocProvider<TransactionBloc>(
            create: (_) => TransactionBloc(txnRepo),
            child: const TransactionDetailPage(id: 't1'),
          ),
        ),
      ));
      await tester.pump(); // 不 settle(保持 TransactionDetailLoading)。

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FloatingActionDock), findsOneWidget,
          reason: 'F59 FR-3:loading 态恒渲染悬浮簇');
      final dock =
          tester.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.onTap, isNull, reason: 'loading:主操作禁用');
      expect(dock.muted.every((a) => a.onTap == null), isTrue,
          reason: 'loading:淡显组全禁用');

      completer.complete(dartz.Right(_expense()));
      await tester.pumpAndSettle();
    });

    testWidgets('error 恒渲染 dock:全动作禁用', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      when(() => txnRepo.getById(any())).thenAnswer((_) async =>
          const dartz.Left<Failure, Transaction>(ServerFailure('读取失败')));

      await tester.pumpWidget(_harness(
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AccountRepository>.value(value: acctRepo),
          ],
          child: BlocProvider<TransactionBloc>(
            create: (_) => TransactionBloc(txnRepo),
            child: const TransactionDetailPage(id: 't1'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 正文错误文案 + AppToast(error listener)各一处 → findsWidgets。
      expect(find.textContaining('读取失败'), findsWidgets);
      expect(find.byType(FloatingActionDock), findsOneWidget,
          reason: 'F59 FR-3:error 态恒渲染悬浮簇');
      final dock =
          tester.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.onTap, isNull, reason: 'error:主操作禁用');
      expect(dock.muted.every((a) => a.onTap == null), isTrue,
          reason: 'error:淡显组全禁用');

      // Drain the 3s AppToast timer the error listener schedules.
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    testWidgets('TransactionDeleting 态:dock 恒渲染,三钮全禁用(防重复提交)',
        (tester) async {
      await pumpPage(tester, const Size(1440, 900));

      // delete 挂起(Completer 不完成)→ 确认后 bloc 停留 TransactionDeleting。
      final deleteCompleter = Completer<dartz.Either<Failure, void>>();
      when(() => txnRepo.delete(any())).thenAnswer((_) => deleteCompleter.future);

      await tester.tap(find.byTooltip('删除交易'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 三钮(编辑 primary + 复制交易/删除交易 muted)全部禁用,簇不缺席。
      expect(find.byType(FloatingActionDock), findsOneWidget,
          reason: 'F59 FR-3:deleting 态恒渲染悬浮簇');
      final dock =
          tester.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.tooltip, '编辑');
      expect(dock.primary.onTap, isNull, reason: 'deleting:编辑禁用');
      expect(dock.muted.map((a) => a.tooltip).toList(),
          ['复制交易', '删除交易']);
      expect(dock.muted.every((a) => a.onTap == null), isTrue,
          reason: 'deleting:复制/删除禁用');

      // 收尾:放行 delete → TransactionDeleted(toast 计时器排空,测试可退出)。
      deleteCompleter.complete(dartz.Right(null));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    testWidgets('标题注入:加载完成 set(交易名);离开页面 clear', (tester) async {
      final getIt = GetIt.instance;
      if (!getIt.isRegistered<ShellDetailTitle>()) {
        getIt.registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
      }

      await pumpPage(tester, const Size(1440, 900));

      expect(getIt<ShellDetailTitle>().value, '晚餐 餐厅',
          reason: '加载完成 → 交易名注入顶栏面包屑当前级');

      await tester.pumpWidget(const MaterialApp());
      await tester.pump();
      expect(getIt<ShellDetailTitle>().value, isNull);
    });
  });
}
