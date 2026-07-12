// Task 7 — widget tests for SecurityPage(列表 / 搜索 / 创建 / 价格管理)。
// Task 2(late-align)— provider bar 替换旧 sync-disabled banner。
//
// 验证(对齐 brief + A-od security-mobile.html):
//   - 列表渲染:symbol / name / type 中文标签 / exchange / currency / 现价。
//   - provider bar:行情源「新浪财经」只读 chip + 上次同步时间 + 手动刷新
//     (去 Switch;刷新触发 RefreshPricesRequested → repo.syncPrices)。
//   - 搜索:输入触发 SearchSecuritiesRequested(后端 repo.searchSecurities 被调)。
//   - 创建表单:填 symbol/name/exchange → 提交触发 CreateSecurityRequested
//     (repo.createSecurity 被调,参数对齐 SecurityParams)。
//   - 改价:点击「改价」→ Dialog 输入现价 → 保存触发 UpdatePriceRequested
//     (repo.updateSecurityPrice 被调,priceCents = 元*100)。
//   - 空 / Loading 处理。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_module_tabs.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/holding/presentation/pages/security_page.dart';

/// 包一层 GoRouter(security_page 其他部分仍可能用 GoRouterState.of,保留祖先)。
Widget _routed(Widget child) => MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => child),
        ],
      ),
    );

class _MockRepo extends Mock implements HoldingRepository {}

Security _sec({
  required String id,
  required String symbol,
  required String name,
  SecurityType type = SecurityType.stock,
  String currency = 'CNY',
  String? exchange,
  int priceCents = 10000, // ¥100.00
}) =>
    Security(
      id: id,
      symbol: symbol,
      name: name,
      securityType: type,
      exchange: exchange,
      currency: currency,
      currentPriceCents: priceCents,
    );

/// harness:注入 HoldingBloc(mock repo)。securities 预置为 [securities];
/// [searchResult] 为搜索返回(默认同 securities)。
Widget _harness({
  required _MockRepo repo,
}) {
  return _routed(BlocProvider<HoldingBloc>(
    create: (_) => HoldingBloc(repo),
    child: const SecurityPage(),
  ));
}

/// 公用 repo stub:listSecurities / searchSecurities / 业务事件成功路径。
void _stubRepo(
  _MockRepo repo, {
  List<Security> securities = const [],
  List<Security> searchResult = const [],
  Security? created,
}) {
  registerFallbackValue(SecurityType.stock);
  when(() => repo.listSecurities(type: any(named: 'type')))
      .thenAnswer((_) async => dartz.Right(securities));
  when(() => repo.searchSecurities(any()))
      .thenAnswer((_) async => dartz.Right(searchResult));
  when(() => repo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((_) async => const dartz.Right([]));
  when(() => repo.createSecurity(
        symbol: any(named: 'symbol'),
        name: any(named: 'name'),
        type: any(named: 'type'),
        exchange: any(named: 'exchange'),
        currency: any(named: 'currency'),
      )).thenAnswer((_) async => dartz.Right(
        created ?? securities.firstOrNull ?? _sec(id: 'new', symbol: 'NEW', name: 'New'),
      ));
  when(() => repo.updateSecurityPrice(
        id: any(named: 'id'),
        priceCents: any(named: 'priceCents'),
      )).thenAnswer((_) async => const dartz.Right(null));
  // provider bar 手动刷新价格(RefreshPricesRequested → repo.syncPrices)。
  when(() => repo.syncPrices()).thenAnswer((_) async => dartz.Right(
        SyncPricesResult(
          syncedCount: 2,
          syncedAt: DateTime(2026, 7, 9, 15, 7),
        ),
      ));
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  // 搜索 debounce 300ms:test 里需额外 wait 触发 SearchSecuritiesRequested。
  // 列表卡片较多,设高视口避免溢出。
  Future<void> setViewport(WidgetTester t) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  /// AppToast 用 OverlayEntry + 3s Timer + 动画,会令 pumpAndSettle 永不收敛,
  /// 且 Timer 在 widget tree dispose 后仍 pending 导致 "timersPending" 断言失败。
  /// 故触发 toast 后用 [pumpToastFrames]:推进帧让 bloc 处理 + toast 显示,
  /// 再快进 > 3s 让 toast Timer 触发并 _dismiss(清掉 pending Timer)。
  Future<void> pumpToastFrames(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 100));
    // 快进 toast 的 3s Timer(默认 duration),触发 _dismiss → 无 pending Timer。
    await t.pump(const Duration(seconds: 4));
  }

  final sample = [
    _sec(
        id: 's1',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        type: SecurityType.stock,
        currency: 'USD',
        exchange: 'NASDAQ',
        priceCents: 18500),
    _sec(
        id: 's2',
        symbol: '510300',
        name: '沪深300ETF',
        type: SecurityType.etf,
        currency: 'CNY',
        exchange: 'SH',
        priceCents: 412),
    _sec(
        id: 's3',
        symbol: 'GFUND',
        name: '货币基金',
        type: SecurityType.fund,
        currency: 'CNY',
        priceCents: 10120),
  ];

  testWidgets('renders security list (symbol/name/type label/price)', (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // symbol / name 渲染。
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('Apple Inc.'), findsOneWidget);
    expect(find.text('510300'), findsOneWidget);
    expect(find.text('沪深300ETF'), findsOneWidget);
    // type 中文标签(对齐原型 TYPE_META)。
    expect(find.text('股票'), findsOneWidget);
    expect(find.text('ETF'), findsOneWidget);
    expect(find.text('基金'), findsOneWidget);
    // 现价(USD $185.00 / CNY ¥4.12)。
    expect(find.text(r'$185.00'), findsOneWidget);
    expect(find.text('¥4.12'), findsOneWidget);
    // exchange + currency meta。
    expect(find.text('NASDAQ'), findsOneWidget);
    expect(find.text('USD'), findsWidgets);
  });

  testWidgets(
      'provider bar: 显示新浪财经 + 无 Switch + 刷新触发 RefreshPricesRequested',
      (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // 行情源条存在 + 新浪财经只读 chip + 刷新按钮。
    expect(find.byKey(const ValueKey('providerBar')), findsOneWidget);
    // 「新浪财经」既出现在 page-head sub 又在 provider bar(对齐 OD .page-title
    // .sub + .provider-bar 双处展示)。
    expect(find.textContaining('新浪财经'), findsWidgets);
    expect(find.byKey(const ValueKey('providerRefresh')), findsOneWidget);
    // 已去 Switch(旧 syncToggle 不再存在)。
    expect(find.byType(Switch), findsNothing);

    // 初始未同步 → 「尚未同步」。
    expect(find.textContaining('尚未同步'), findsOneWidget);

    // 点刷新 → repo.syncPrices 被调(即 RefreshPricesRequested 端到端落地)。
    verifyNever(() => repo.syncPrices());
    await t.tap(find.byKey(const ValueKey('providerRefresh')));
    await t.pumpAndSettle();
    verify(() => repo.syncPrices()).called(1);

    // 刷新后显示「上次同步 HH:mm」(stub syncedAt = 2026-07-09 15:07)。
    expect(find.textContaining('上次同步 15:07'), findsOneWidget);
  });

  testWidgets('empty state when no securities', (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: const []);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    expect(find.text('还没有证券'), findsOneWidget);
    expect(find.text('点击右下角「+」创建第一个证券'), findsOneWidget);
  });

  testWidgets('search dispatches SearchSecuritiesRequested (repo.search called)',
      (t) async {
    await setViewport(t);
    _stubRepo(repo,
        securities: sample, searchResult: [sample[0]]); // 搜 'AAPL' → 仅 1 条
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();
    // 初始:全部 3 条。
    expect(find.text('510300'), findsOneWidget);

    // 输入搜索词(触发 300ms debounce)。
    await t.enterText(find.byKey(const ValueKey('searchField')), 'AAPL');
    // wait debounce(>300ms)+ settle。
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();

    verify(() => repo.searchSecurities('AAPL')).called(1);
    // 搜索后仅剩 AAPL(510300 / 货币基金 消失)。注意搜索框本身也含 "AAPL"
    // 文本(EditableText),故不直接断言 find.text('AAPL')。
    expect(find.text('510300'), findsNothing);
    expect(find.text('沪深300ETF'), findsNothing);
    expect(find.text('货币基金'), findsNothing);
  });

  testWidgets('create form submit dispatches CreateSecurityRequested',
      (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // 打开创建 sheet。
    await t.tap(find.byKey(const ValueKey('createFab')));
    await t.pumpAndSettle();

    // 填表单(symbol/name/exchange;type/currency 用默认 stock/CNY)。
    await t.enterText(find.byKey(const ValueKey('symbolField')), 'MSFT');
    await t.enterText(find.byKey(const ValueKey('nameField')), 'Microsoft');
    await t.enterText(find.byKey(const ValueKey('exchangeField')), 'NASDAQ');
    await t.pumpAndSettle();

    await t.ensureVisible(find.byKey(const ValueKey('createSubmitBtn')));
    await t.tap(find.byKey(const ValueKey('createSubmitBtn')));
    // 成功 → BlocListener 弹 success toast(3s Timer)→ pumpAndSettle 不收敛,
    // 改用固定帧推进(bloc Submitting → Loaded + toast 显示 + sheet pop)。
    await pumpToastFrames(t);

    // repo.createSecurity 被调,参数对齐 SecurityParams。
    verify(() => repo.createSecurity(
          symbol: 'MSFT',
          name: 'Microsoft',
          type: SecurityType.stock,
          exchange: 'NASDAQ',
          currency: 'CNY',
        )).called(1);
  });

  testWidgets(
      'price edit dialog dispatches UpdatePriceRequested (priceCents = yuan*100)',
      (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // 点击 s1(AAPL)的「改价」按钮。
    await t.tap(find.byKey(const ValueKey('editPriceBtn-s1')));
    await t.pumpAndSettle();

    // Dialog 输入新价(清空后输入 190.50)。
    final field = find.byKey(const ValueKey('priceEditField'));
    expect(field, findsOneWidget);
    await t.tap(field);
    await t.enterText(field, '190.50');
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('priceEditSave')));
    await t.pumpAndSettle();

    // repo.updateSecurityPrice 被调,priceCents = 190.50 * 100 = 19050。
    verify(() => repo.updateSecurityPrice(
          id: 's1',
          priceCents: 19050,
        )).called(1);
  });

  testWidgets('price edit rejects non-positive (no repo call)', (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('editPriceBtn-s1')));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const ValueKey('priceEditField')), '0');
    await t.tap(find.byKey(const ValueKey('priceEditSave')));
    // 校验失败 → warning toast(3s Timer)→ pumpAndSettle 不收敛,改用固定帧。
    await pumpToastFrames(t);

    // 校验拦截:repo 未被调。
    verifyNever(() => repo.updateSecurityPrice(
          id: any(named: 'id'),
          priceCents: any(named: 'priceCents'),
        ));
    // Dialog 仍打开(校验失败不关闭)。
    expect(find.byKey(const ValueKey('priceEditField')), findsOneWidget);
  });

  testWidgets('create form requires symbol (toast, no repo call)', (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('createFab')));
    await t.pumpAndSettle();

    // 只填 name,不填 symbol → 校验拦截。
    await t.enterText(find.byKey(const ValueKey('nameField')), 'NoSym');
    await t.ensureVisible(find.byKey(const ValueKey('createSubmitBtn')));
    await t.tap(find.byKey(const ValueKey('createSubmitBtn')));
    // 校验失败 → warning toast → pumpAndSettle 不收敛,改用固定帧。
    await pumpToastFrames(t);

    verifyNever(() => repo.createSecurity(
          symbol: any(named: 'symbol'),
          name: any(named: 'name'),
          type: any(named: 'type'),
          exchange: any(named: 'exchange'),
          currency: any(named: 'currency'),
        ));
  });

  // ─── Task 4:页内 tab + OD page-head 对齐 + 类型 chips ───

  testWidgets('module tabs rendered (HoldingModuleTabs, 4 labels)', (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    expect(find.byType(HoldingModuleTabs), findsOneWidget);
    // 4 tab labels(对齐 OD .tabs)。「Security 管理」既在 active tab 又在 h1。
    expect(find.text('持仓列表'), findsOneWidget);
    expect(find.text('收益统计'), findsOneWidget);
    expect(find.text('投资目标'), findsOneWidget);
    expect(find.text('Security 管理'), findsWidgets);
  });

  testWidgets('page-head: h1 serif + sub 共 N 个证券 · 行情源 新浪财经', (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // sub:共 3 个证券 + 行情源 新浪财经(新浪财经 同时出现在 _ProviderBar,
    // 故 findsWidgets)。
    expect(find.textContaining('共 3 个证券'), findsOneWidget);
    expect(find.textContaining('新浪财经'), findsWidgets);
  });

  testWidgets('type chips filter list client-side (全部 / 单类型 回切)',
      (t) async {
    await setViewport(t);
    _stubRepo(repo, securities: sample);
    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // 初始:全部 3 个,3 个 symbol 都在。
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('510300'), findsOneWidget);
    expect(find.text('GFUND'), findsOneWidget);

    // 点「ETF 1」chip → 仅剩 ETF(510300),其他消失。
    await t.tap(find.text('ETF 1'));
    await t.pumpAndSettle();
    expect(find.text('510300'), findsOneWidget);
    expect(find.text('AAPL'), findsNothing);
    expect(find.text('GFUND'), findsNothing);

    // 点「全部 3」chip → 恢复全量。
    await t.tap(find.text('全部 3'));
    await t.pumpAndSettle();
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('510300'), findsOneWidget);
    expect(find.text('GFUND'), findsOneWidget);
  });
}
