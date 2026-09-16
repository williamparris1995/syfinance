// F26(R12 sprint-1)— NFR-1 theme-follow 探针:AccountDetailPage hero(变体 A)。
//
// FR-2:账户详情 hero 与 home 净资产 hero 同款迁变体 A —— 暗 = surface 墨面卡 +
// 1.5px 金渐变描边 + 余额大数字 ShaderMask 渐变金;亮 = surface 白卡 + 柔影 +
// 数字 fg。内容排版(徽章/名称/org/fields)不动,仅换容器皮。
//
// 断言走 widget 树特征(Container/BoxDecoration/ShaderMask/boxShadow),不用
// golden(design.md LLD)。theme 经 AppTheme 注入(携带 YucaiTheme extension)。
import 'package:dartz/dartz.dart' as dartz;
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
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/hero_shell.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

Account _account() => const Account(
      id: 'a1',
      name: '现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 100000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Future<void> _pump(WidgetTester t, Brightness brightness) async {
  final accountRepo = _MockAccountRepo();
  final txnRepo = _MockTxnRepo();
  registerFallbackValue(const ListTransactionsParams());
  registerFallbackValue(SummaryScope.month);
  registerFallbackValue(const UpdateAccountParams(id: 'a1', version: 1));
  // 详情页 _loadAccounts 直连 getIt<AccountRepository>(解析近期交易行 entries)。
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  GetIt.instance.registerSingleton<TransactionRepository>(txnRepo);

  final a = _account();
  when(() => accountRepo.getById(any()))
      .thenAnswer((_) async => dartz.Right(a));
  when(() => accountRepo.list())
      .thenAnswer((_) async => dartz.Right([a]));
  when(() => txnRepo.list(any())).thenAnswer((_) async => const dartz.Right(
      ListTransactionsResult(transactions: <Transaction>[])));
  when(() => txnRepo.summary(any(), any(),
          accountId: any(named: 'accountId'),
          scope: any(named: 'scope'),
          day: any(named: 'day')))
      .thenAnswer(
          (_) async => const dartz.Right(MonthlySummary(year: 2026, month: 6)));

  final listUc = _MockList();
  final createUc = _MockCreate();
  final deleteUc = _MockDelete();
  final getUc = _MockGet();
  final updateUc = _MockUpdate();
  when(() => getUc.call(any())).thenAnswer((_) async => dartz.Right(a));
  when(() => listUc.call()).thenAnswer((_) async => dartz.Right([a]));

  await t.pumpWidget(MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AccountBloc>(
          create: (_) {
            final b = AccountBloc(listUc, createUc, deleteUc, getUc, updateUc);
            b.add(const GetAccountRequested('a1'));
            return b;
          },
        ),
        BlocProvider<TransactionBloc>(
          create: (_) {
            final b = TransactionBloc(txnRepo);
            b.add(const LoadTransactionsRequested(
                filter: TxnFilterState(accountId: 'a1')));
            b.add(LoadSummaryRequested(
                year: DateTime.now().year,
                month: DateTime.now().month,
                accountId: 'a1'));
            return b;
          },
        ),
      ],
      child: const AccountDetailPage(id: 'a1'),
    ),
  ));
  await t.pumpAndSettle();
  // 探针不依赖 getIt 残留;清掉本 pump 的注册,防串扰后续测试。
  GetIt.instance.reset();
}

void main() {
  /// hero 定位:余额(ValueKey heroBalance)所在的 HeroShell(变体 A 壳;
  /// Finder 惰性,使用时才求值)。
  final hero = find.ancestor(
    of: find.byKey(const ValueKey('heroBalance')),
    matching: find.byType(HeroShell),
  );

  Finder gradientBorderIn(Finder scope) => find.descendant(
        of: scope,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container || w.decoration is! BoxDecoration) return false;
          final g = (w.decoration as BoxDecoration).gradient;
          return g is LinearGradient && g.colors.length == 2;
        }),
      );

  bool hasFixedDeepGradient(Container c) {
    if (c.decoration is! BoxDecoration) return false;
    final g = (c.decoration as BoxDecoration).gradient;
    if (g is! LinearGradient) return false;
    return g.colors.contains(const Color(0xFF1C1E21)) ||
        g.colors.contains(const Color(0xFF2A2D33));
  }

  Finder glowIn(Finder scope) => find.descendant(
        of: scope,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container || w.decoration is! BoxDecoration) return false;
          return (w.decoration as BoxDecoration).gradient is RadialGradient;
        }),
      );

  testWidgets(
      'dark: 金渐变描边 + 余额 ShaderMask 渐变金,账户名走 fg,无固定深色面(FR-2)',
      (t) async {
    await _pump(t, Brightness.dark);

    expect(hero, findsOneWidget, reason: '账户详情 hero 应由 HeroShell 承载');

    // 金渐变描边层(ADR-1):accent→accentDeep(墨鎏金)。
    final border = gradientBorderIn(hero);
    expect(border, findsOneWidget);
    final grad =
        (t.widget<Container>(border).decoration as BoxDecoration).gradient
            as LinearGradient;
    expect(grad.colors.first, const Color(0xFFE8C07A));
    expect(grad.colors.last, const Color(0xFFC9964A));

    // 内层 surface 墨面卡,无阴影。
    final surface = find.descendant(
      of: hero,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container || w.decoration is! BoxDecoration) return false;
        return (w.decoration as BoxDecoration).color ==
            const Color(0xFF141922);
      }),
    );
    expect(surface, findsOneWidget);
    expect(
        (t.widget<Container>(surface).decoration as BoxDecoration).boxShadow,
        isNull);

    // 余额大数字 ShaderMask(ADR-2;两处 hero 一致)。
    final mask = find.descendant(of: hero, matching: find.byType(ShaderMask));
    expect(mask, findsOneWidget, reason: '暗色余额大数字应有渐变金层');
    expect(t.widget<ShaderMask>(mask).blendMode, BlendMode.srcIn);

    // 账户名(28px)不渐变:hero 内 ShaderMask 仅此一层(名称走 fg,
    // ADR-2 克制;该语义由上面的 findsOneWidget 单层性承载)。

    // 无固定深色面(全树,F4-P2 退役)。
    expect(
        t
            .widgetList<Container>(find.byType(Container))
            .where(hasFixedDeepGradient),
        isEmpty);

    // 金晕保留(ADR-4 暗色 0.18)。
    final glow = glowIn(hero);
    expect(glow, findsOneWidget);
    final rg = (t.widget<Container>(glow).decoration as BoxDecoration).gradient
        as RadialGradient;
    expect(rg.colors.first.a, closeTo(0.18, 0.01));

    // 白系文本 → 语义令牌:账户名 fg(暗档 #F2F4F8)/label muted(#8B93A3)。
    expect(t.widget<Text>(find.text('现金')).style?.color,
        const Color(0xFFF2F4F8));
    expect(t.widget<Text>(find.text('可用余额')).style?.color,
        const Color(0xFF8B93A3));
  });

  testWidgets('light: 白卡柔影 + 数字非渐变 + 名称/label 语义色(FR-2)', (t) async {
    await _pump(t, Brightness.light);

    expect(hero, findsOneWidget);

    // 卡面 = surface 白 + 非空 boxShadow。
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
    expect(card, findsOneWidget, reason: '亮色 hero 应为白卡 + 柔影');

    // 数字非渐变 + 无描边层。
    expect(find.descendant(of: hero, matching: find.byType(ShaderMask)),
        findsNothing);
    expect(gradientBorderIn(hero), findsNothing);

    // 名称 fg(#0F172A)/label muted(#64748B)晨白档。
    expect(t.widget<Text>(find.text('现金')).style?.color,
        const Color(0xFF0F172A));
    expect(t.widget<Text>(find.text('可用余额')).style?.color,
        const Color(0xFF64748B));

    // 金晕保留(ADR-4 单值 0.18,prototype .glow 单一定义)。
    final glow = glowIn(hero);
    expect(glow, findsOneWidget);
    final rg = (t.widget<Container>(glow).decoration as BoxDecoration).gradient
        as RadialGradient;
    expect(rg.colors.first.a, closeTo(0.18, 0.01));

    // 金晕溢出放行:Stack 不得在内容框硬裁(默认 hardEdge 会把负偏移晕切成
    // 直边方块残块),交给 HeroShell 卡面 antiAlias 按卡片圆角裁。
    final glowStack = t.widget<Stack>(
        find.ancestor(of: glow, matching: find.byType(Stack)).first);
    expect(glowStack.clipBehavior, Clip.none,
        reason: '负偏移金晕应溢出至卡缘由卡面圆角裁剪');
  });
}
