// F26(R12 sprint-1)— NFR-1 theme-follow 探针:HomePage 净资产 hero(变体 A)。
//
// spec Scenario(NFR-1):
// - GIVEN 暗色主题 WHEN 渲染 hero THEN 存在金渐变描边容器与 ShaderMask 数字层,
//   无固定深色面。
// - GIVEN 亮色主题 WHEN 渲染 hero THEN 卡面为 surface + 阴影,数字非渐变,
//   label/pill 语义色。
//
// 断言全部走 widget 树特征(HeroShell 内 Container/BoxDecoration/ShaderMask/
// boxShadow),不用 golden(脆测,design.md LLD)。色值断言用 AppTheme 注入的
// context.yucai 语义令牌实际值(暗=墨鎏金,亮=晨白)。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/hero_shell.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}
class _MockHasCredentials extends Mock implements HasStoredCredentialsUseCase {}
class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockGoalRepo extends Mock implements GoalRepository {}

class _FakeNetWorthDs extends Fake implements NetWorthDataSource {
  @override
  Future<NetWorthView> getNetWorth({required String baseCurrency}) async =>
      NetWorthView(
        totalAssetsCents: 1200000,
        totalLiabilitiesCents: 300000,
        netWorthCents: 900000,
        currency: baseCurrency,
      );
}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  _FakeCurrencySettings(this._base);
  final String _base;
  final ValueNotifier<String> _notifier = ValueNotifier<String>('CNY');

  @override
  ValueListenable<String> get listenable => _notifier;

  @override
  String get value => _base;

  @override
  Future<String> getBaseCurrency() async => _base;
}

/// AuthBloc seeded Authenticated(HomePage watch state 取显示名)。
class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
    emit(Authenticated(User(
      id: 'u1',
      tenantId: 't1',
      email: 't@example.com',
      displayName: '测试用户',
      avatarUrl: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    )));
  }
}

/// 探针 harness:照 home_page_test 空数据口径(交易/持仓/到期空、无 budget/
/// goals → 面板空态/摘要卡隐藏),仅净资产 hero 渲染真实数据;theme 注入
/// AppTheme 双主题(携带 YucaiTheme 语义令牌 extension)。
Widget _harness(Brightness brightness) {
  final getIt = GetIt.instance;
  getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs());
  getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings('CNY'));
  getIt.registerSingleton<DataRefreshNotifier>(DataRefreshNotifier());

  final accountRepo = _MockAccountRepo();
  when(() => accountRepo.list())
      .thenAnswer((_) async => const dartz.Right(<Account>[]));
  final accountBloc = AccountBloc(
    ListAccountsUseCase(accountRepo),
    CreateAccountUseCase(accountRepo),
    DeleteAccountUseCase(accountRepo),
    GetAccountUseCase(accountRepo),
    UpdateAccountUseCase(accountRepo),
  );

  final txnRepo = _MockTxnRepo();
  when(() => txnRepo.list(any())).thenAnswer((_) async => const dartz.Right(
      ListTransactionsResult(transactions: <Transaction>[])));
  when(() => txnRepo.summary(any(), any(),
          accountId: any(named: 'accountId'),
          scope: any(named: 'scope'),
          day: any(named: 'day')))
      .thenAnswer((_) async =>
          const dartz.Right(MonthlySummary(year: 2026, month: 7)));
  getIt.registerSingleton<TransactionRepository>(txnRepo);

  final debtRepo = _MockDebtRepo();
  when(() => debtRepo.upcomingPayments(any()))
      .thenAnswer((_) async => const dartz.Right(<Debt>[]));
  getIt.registerSingleton<DebtRepository>(debtRepo);

  final holdingRepo = _MockHoldingRepo();
  when(() => holdingRepo.listHoldings())
      .thenAnswer((_) async => const dartz.Right(<Holding>[]));
  getIt.registerSingleton<HoldingRepository>(holdingRepo);

  final budgetRepo = _MockBudgetRepo();
  when(() => budgetRepo.getBudgetByMonth(any()))
      .thenAnswer((_) async => const dartz.Left(ServerFailure('not found')));
  getIt.registerSingleton<BudgetRepository>(budgetRepo);

  final goalRepo = _MockGoalRepo();
  when(() => goalRepo.listGoals(
          type: any(named: 'type'), completed: any(named: 'completed')))
      .thenAnswer((_) async => const dartz.Right(<GoalView>[]));
  getIt.registerSingleton<GoalRepository>(goalRepo);

  return MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _SeededAuthedBloc()),
        BlocProvider<AccountBloc>.value(value: accountBloc),
      ],
      child: const HomePage(),
    ),
  );
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
  });
  setUp(() => getIt.reset());

  /// hero 定位:净资产 hero 外壳(F26 变体 A 壳;Finder 惰性,使用时才求值)。
  final hero = find.byType(HeroShell);

  /// hero 内双色 LinearGradient 容器(暗色=金渐变描边外层)。
  Finder gradientBorderIn(Finder scope) => find.descendant(
        of: scope,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container || w.decoration is! BoxDecoration) return false;
          final g = (w.decoration as BoxDecoration).gradient;
          return g is LinearGradient && g.colors.length == 2;
        }),
      );

  /// 全树「固定深色面」残留检查:#1C1E21→#2A2D33 系(v1 遗留,F4-P2 已退役)。
  bool hasFixedDeepGradient(Container c) {
    if (c.decoration is! BoxDecoration) return false;
    final g = (c.decoration as BoxDecoration).gradient;
    if (g is! LinearGradient) return false;
    return g.colors.contains(const Color(0xFF1C1E21)) ||
        g.colors.contains(const Color(0xFF2A2D33));
  }

  /// hero 内径向金晕容器。
  Finder glowIn(Finder scope) => find.descendant(
        of: scope,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container || w.decoration is! BoxDecoration) return false;
          return (w.decoration as BoxDecoration).gradient is RadialGradient;
        }),
      );

  testWidgets(
      'dark: 金渐变描边双层容器 + ShaderMask 渐变金数字,无固定深色面(NFR-1 S1)',
      (t) async {
    await t.pumpWidget(_harness(Brightness.dark));
    await t.pumpAndSettle();

    expect(hero, findsOneWidget, reason: '净资产 hero 应由 HeroShell(变体 A)承载');

    // 金渐变描边层(ADR-1 双层容器):accent→accentDeep(墨鎏金 #E8C07A→#C9964A)。
    final border = gradientBorderIn(hero);
    expect(border, findsOneWidget, reason: '暗色 hero 应有金渐变描边外层容器');
    final grad =
        (t.widget<Container>(border).decoration as BoxDecoration).gradient
            as LinearGradient;
    expect(grad.colors.first, const Color(0xFFE8C07A));
    expect(grad.colors.last, const Color(0xFFC9964A));

    // 内层 surface 墨面卡(镂空露边)且无阴影(墨鎏金=描边分层,无阴影)。
    final surface = find.descendant(
      of: hero,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container || w.decoration is! BoxDecoration) return false;
        return (w.decoration as BoxDecoration).color ==
            const Color(0xFF141922);
      }),
    );
    expect(surface, findsOneWidget, reason: '暗色 hero 卡面应为 surface 墨面');
    expect(
        (t.widget<Container>(surface).decoration as BoxDecoration).boxShadow,
        isNull,
        reason: '暗色走描边分层,不应有 boxShadow');

    // 数字层 ShaderMask(ADR-2,srcIn 渐变金)。
    final mask = find.descendant(of: hero, matching: find.byType(ShaderMask));
    expect(mask, findsOneWidget, reason: '暗色大数字应有 ShaderMask 渐变金层');
    expect(t.widget<ShaderMask>(mask).blendMode, BlendMode.srcIn);

    // 无固定深色面(FR-1 退役检查,全树)。
    expect(
        t
            .widgetList<Container>(find.byType(Container))
            .where(hasFixedDeepGradient),
        isEmpty,
        reason: '#1C1E21→#2A2D33 固定深渐变面应退役');

    // 金晕保留(ADR-4 暗色 0.18)。
    final glow = glowIn(hero);
    expect(glow, findsOneWidget, reason: '金晕应保留');
    final rg = (t.widget<Container>(glow).decoration as BoxDecoration).gradient
        as RadialGradient;
    expect(rg.colors.first.a, closeTo(0.18, 0.01));

    // 金晕溢出放行:Stack 不得在内容框硬裁(默认 hardEdge 会把负偏移晕切成
    // 直边方块残块),交给 HeroShell 卡面 antiAlias 按卡片圆角裁。
    final glowStack = t.widget<Stack>(
        find.ancestor(of: glow, matching: find.byType(Stack)).first);
    expect(glowStack.clipBehavior, Clip.none,
        reason: '负偏移金晕应溢出至卡缘由卡面圆角裁剪');

    // label 语义色(muted 暗档)。
    expect(t.widget<Text>(find.text('总净资产')).style?.color,
        const Color(0xFF8B93A3));
  });

  testWidgets('light: surface 白卡 + 柔影,数字非渐变,label/pill 语义(NFR-1 S2)',
      (t) async {
    await t.pumpWidget(_harness(Brightness.light));
    await t.pumpAndSettle();

    expect(hero, findsOneWidget);

    // 卡面 = surface 白 + 非空 boxShadow(晨白柔影;FR-1)。
    final card = find.descendant(
      of: hero,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container || w.decoration is! BoxDecoration) return false;
        final d = w.decoration as BoxDecoration;
        return d.color == const Color(0xFFFFFFFF) &&
            d.boxShadow != null &&
            d.boxShadow!.isNotEmpty;
      }),
    );
    expect(card, findsOneWidget, reason: '亮色 hero 应为白卡 + boxShadow 柔影');

    // 数字非渐变:hero 内无 ShaderMask,也无渐变描边层(亮=白卡阴影,无描边)。
    expect(find.descendant(of: hero, matching: find.byType(ShaderMask)),
        findsNothing,
        reason: '亮色数字直出 fg,不应有渐变层');
    expect(gradientBorderIn(hero), findsNothing,
        reason: '亮色不应有金渐变描边层');

    // label/pill 语义色(muted/positive 晨白档)。
    expect(t.widget<Text>(find.text('总净资产')).style?.color,
        const Color(0xFF64748B));
    final pill = t
        .widgetList<Text>(find.byType(Text))
        .firstWhere((x) => (x.data ?? '').contains('个账户'));
    expect(pill.style?.color, const Color(0xFF059669));

    // 金晕保留(ADR-4 单值 0.18 随 prototype .glow 单一定义)。
    final glow = glowIn(hero);
    expect(glow, findsOneWidget);
    final rg = (t.widget<Container>(glow).decoration as BoxDecoration).gradient
        as RadialGradient;
    expect(rg.colors.first.a, closeTo(0.18, 0.01));

    // 亮色同口径:Stack 溢出放行(负偏移晕由卡面 antiAlias 圆角裁)。
    final glowStack = t.widget<Stack>(
        find.ancestor(of: glow, matching: find.byType(Stack)).first);
    expect(glowStack.clipBehavior, Clip.none);
  });
}
