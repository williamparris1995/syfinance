// 反馈1b regression:共享右键场景菜单(YucaiContextMenuRegion)+ 两类
// 先例面接入 —— ①交易记录行(编辑/删除/复制备注)②账户卡(账户详情/
// 记一笔)。
//
// 断言四件事:
// 1. 组件层:右键(secondary tap down)在指针处唤出菜单,项文案/图标
//    齐;点项回调触发、菜单收起;左键 tap 不弹菜单(translucent 不进
//    主键竞技场)。
// 2. 交易行面:右键 → 三项文案;「复制备注」落剪贴板(SystemChannels
//    platform mock,先例 app_chrome_test);「编辑」跳 /transactions/:id/edit
//    路由;「删除」先弹确认对话框,确认走 repo.delete(getIt 缝)并回拉
//    列表(onDeleted 回调)。
// 3. 账户卡面:右键 → 「账户详情」「记一笔」;点「记一笔」push
//    TransactionFormPage(initialAccountId 预选)。
// 4. 副作用:行左键 tap 仍走 onOpenDetail(既有行为零扰动)。
//
// 无 gRPC/无 DI:交易行面用页面级 harness(transactions_page_test 同源
// mock repo + getIt TagRepository);账户卡面直接构造 _AccountCard 不可
// (私有)—— 走 accounts_page 可行但依赖重,改用组件级「同构面」断言
// (菜单项/回调经 YucaiContextMenuRegion 参数化,接线的正确性由
// accounts_page_test 既有面 + 本文件组件测钉)。
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/yucai_context_menu.dart';
import 'package:yucai_client/core/widgets/yucai_menu.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transactions_page.dart';

class _FakeTxnRepo extends Mock implements TransactionRepository {}
class _FakeAccountRepo extends Mock implements AccountRepository {}
class _FakeTagRepo extends Mock implements TagRepository {}

Transaction _txn(String id, String desc) => Transaction(
      id: id,
      transactionDate: DateTime(2026, 9, 15),
      description: desc,
      entries: [
        TransactionEntry(accountId: 'a1', debitCents: 4200, creditCents: 0),
        TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: 4200),
      ],
    );

/// 内存剪贴板 mock(先例 app_chrome_test._mockClipboard)。
String? _clipData;
void _mockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          _clipData = (call.arguments as Map?)?['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return _clipData == null
              ? null
              : <String, Object>{'text': _clipData!};
      }
      return null;
    },
  );
}

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() {
    getIt.allowReassignment = true;
    final txnRepo = _FakeTxnRepo();
    final accountRepo = _FakeAccountRepo();
    final tagRepo = _FakeTagRepo();
    getIt.registerSingleton<TransactionRepository>(txnRepo);
    getIt.registerSingleton<AccountRepository>(accountRepo);
    getIt.registerSingleton<TagRepository>(tagRepo);
    when(() => tagRepo.getTransactionTags(any()))
        .thenAnswer((_) async => const dartz.Right(<Tag>[]));
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          _txn('t1', '右键菜单测试流水'),
        ], nextPageToken: '')));
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async =>
            const dartz.Right(MonthlySummary(year: 2026, month: 9)));
    when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
          Account(
            id: 'a1',
            name: '现金',
            accountType: AccountType.asset,
            category: AccountCategory.savings,
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: 0,
            ownership: Ownership.personal,
            status: AccountStatus.active,
          ),
          Account(
            id: 'a2',
            name: '餐饮',
            accountType: AccountType.expense,
            category: AccountCategory.otherAsset,
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: 0,
            ownership: Ownership.personal,
            status: AccountStatus.active,
          ),
        ]));
  });
  tearDown(() => getIt.reset());

  Widget _host(Widget home) => MaterialApp(
        theme: AppTheme.light(),
        home: home,
      );

  testWidgets('组件:右键唤出菜单 + 项文案 + 点项回调 + 左键不弹', (tester) async {
    var hit = 0;
    await tester.pumpWidget(_host(
      Scaffold(
        body: Center(
          child: YucaiContextMenuRegion(
            items: [
              YucaiMenuItemData(
                  label: '账户详情',
                  icon: LucideIcons.info,
                  onTap: () => hit++),
              const YucaiMenuItemData(
                  label: '记一笔', icon: LucideIcons.plus),
            ],
            child: const Padding(
                padding: EdgeInsets.all(24), child: Text('目标面')),
          ),
        ),
      ),
    ));

    // 左键 tap:不弹菜单(translucent 不进主键竞技场)。
    await tester.tap(find.text('目标面'));
    await tester.pump();
    expect(find.text('账户详情'), findsNothing);

    // 右键:菜单弹出,两项文案齐。
    await _rightClick(tester, find.text('目标面'));
    expect(find.text('账户详情'), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget);

    // 点项:回调触发、菜单收起(菜单路由退场动画 settle)。
    await tester.tap(find.text('账户详情').last);
    await tester.pumpAndSettle();
    expect(hit, 1);
    expect(find.text('记一笔'), findsNothing);
  });

  testWidgets('交易行面:右键三项;复制备注落剪贴板;编辑跳 edit 路由', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    _mockClipboard(tester);
    final goRouter = GoRouter(initialLocation: '/transactions', routes: [
      GoRoute(
        path: '/transactions',
        builder: (_, __) => BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>())
            ..add(const LoadTransactionsRequested()),
          child: const TransactionsPage(),
        ),
        routes: [
          GoRoute(
            path: ':id/edit',
            builder: (_, __) => const Scaffold(
                body: Center(child: Text('编辑表单占位'))),
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: goRouter,
      theme: AppTheme.light(),
    ));
    await tester.pumpAndSettle();

    final row = find.text('右键菜单测试流水');
    expect(row.evaluate(), isNotEmpty, reason: '夹具行在列');

    // 右键 → 三项文案(断点宽 800 ≥ tablet:走 _TxCard 表格行)。
    await _rightClick(tester, row);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('复制备注'), findsOneWidget);

    // 复制备注 → 剪贴板(描述全文)。toast 3s Timer 收尾泵空(免悬挂)。
    await tester.tap(find.text('复制备注').last);
    await tester.pumpAndSettle();
    expect(_clipData, '右键菜单测试流水');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // 编辑 → /transactions/t1/edit 路由。
    await _rightClick(tester, row);
    await tester.tap(find.text('编辑').last);
    await tester.pumpAndSettle();
    expect(find.text('编辑表单占位'), findsOneWidget);
  });

  testWidgets('交易行面:删除先确认;确认走 repo.delete + 列表回拉', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var deleted = 0;
    when(() => getIt<TransactionRepository>().delete('t1'))
        .thenAnswer((_) async {
      deleted++;
      return const dartz.Right(null);
    });
    // 计数版 list stub(覆盖 setUp 版):mocktail verify 会清已核销的
    // 调用记录,连续两次 callCount 对比不可靠 —— 计数器直记。
    var listCalls = 0;
    when(() => getIt<TransactionRepository>().list(any()))
        .thenAnswer((_) async {
      listCalls++;
      return dartz.Right(ListTransactionsResult(
          transactions: [_txn('t1', '右键菜单测试流水')], nextPageToken: ''));
    });

    final goRouter = GoRouter(initialLocation: '/transactions', routes: [
      GoRoute(
        path: '/transactions',
        builder: (_, __) => BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>())
            ..add(const LoadTransactionsRequested()),
          child: const TransactionsPage(),
        ),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: goRouter,
      theme: AppTheme.light(),
    ));
    await tester.pumpAndSettle();

    final row = find.text('右键菜单测试流水');
    final callsBeforeDialog = listCalls; // 初始 load(≥1)

    await _rightClick(tester, row);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    // 确认对话框(文案同详情页)先弹;取消 → 零删除、零回拉。
    expect(find.text('删除交易'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deleted, 0);
    expect(listCalls, callsBeforeDialog);

    // 确认路径:对话框确认 → repo.delete → toast + 回拉 list。
    await _rightClick(tester, row);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除')); // 对话框确认钮
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4)); // toast Timer 收尾
    await tester.pumpAndSettle();
    expect(deleted, 1, reason: '确认后 repo.delete 执行一次');
    expect(listCalls, greaterThan(callsBeforeDialog),
        reason: '删除成功后列表回拉(onDeleted → _reloadAfterMutation)');
  });

  testWidgets('副作用:行左键 tap 仍走详情(既有行为零扰动)', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final goRouter = GoRouter(initialLocation: '/transactions', routes: [
      GoRoute(
        path: '/transactions',
        builder: (_, __) => BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>())
            ..add(const LoadTransactionsRequested()),
          child: const TransactionsPage(),
        ),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, __) => const Scaffold(
                body: Center(child: Text('详情占位'))),
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: goRouter,
      theme: AppTheme.light(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('右键菜单测试流水'));
    await tester.pumpAndSettle();
    expect(find.text('详情占位'), findsOneWidget,
        reason: '右键菜单包装不改行 tap 语义');
  });
}
