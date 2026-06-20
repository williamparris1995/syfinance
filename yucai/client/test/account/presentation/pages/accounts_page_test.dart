// Task 1 (UI-align P0-1) — TDD widget tests for _AccountCard type-specific
// subline + progress bar by AccountCategory.
//
// The _AccountCard widget is private inside accounts_page.dart, so tests drive
// the public AccountsPage via a mocked AccountBloc that emits AccountsLoaded.
// Each test seeds one account per category, asserts the type-specific 副信息
// text and the progress bar presence/absence/color:
//   - savings: 利率（interestRate 有值时），无进度条
//   - creditCard: 额度 · 账单/还款日，已用额度红 bar
//   - investment: +X% 今年收益（正绿/负红），无 bar
//   - fixedDeposit: 到期日 · 利率，无 bar
//   - goldFx: 买入 · 涨幅，无 bar
//   - realEstate: 现估值 · 增值，无 bar
//   - loan: 原始 · 月供 · 下次还款，已还比例绿 bar
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:yucai_client/account/presentation/pages/accounts_page.dart';
import 'package:yucai_client/core/theme/app_design.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

Account _savings() => const Account(
      id: 's1',
      name: '招行储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      institution: '招商银行',
      initialBalanceCents: 0,
      currentBalanceCents: 1200000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      interestRate: 1.5,
    );

Account _credit() => const Account(
      id: 'c1',
      name: '招行信用卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      institution: '招商银行',
      initialBalanceCents: 0,
      currentBalanceCents: 300000, // 欠款 3000
      ownership: Ownership.personal,
      status: AccountStatus.active,
      creditLimitCents: 500000, // 额度 5000
      creditBillingDay: 5,
      creditRepaymentDay: 25,
    );

Account _investment() => const Account(
      id: 'i1',
      name: '证券账户',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      institution: '华泰',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      investReturnYtd: 8.25,
    );

Account _fixed() => Account(
      id: 'f1',
      name: '大额存单',
      accountType: AccountType.asset,
      category: AccountCategory.fixedDeposit,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      fixedMaturityDate: DateTime(2027, 6, 15),
      interestRate: 2.75,
    );

Account _gold() => const Account(
      id: 'g1',
      name: '实物黄金',
      accountType: AccountType.asset,
      category: AccountCategory.goldFx,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      goldProductType: 'Au9999',
      goldQuantity: 10.0,
      goldBuyPriceCents: 50000, // 买入 500/克
      goldCurrentPriceCents: 60000, // 现价 600/克
    );

Account _estate() => const Account(
      id: 'e1',
      name: '自住房',
      accountType: AccountType.asset,
      category: AccountCategory.realEstate,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      estatePurchasePriceCents: 300000000, // 300 万
      estateCurrentValueCents: 360000000, // 360 万
    );

Account _loan() => Account(
      id: 'l1',
      name: '房贷',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      loanOriginalCents: 100000000, // 100 万
      loanRemainingCents: 40000000, // 剩 40 万 → 已还 60%
      loanMonthlyCents: 500000, // 月供 5000
      loanNextPaymentDate: DateTime(2026, 7, 1),
    );

Widget _harness(List<Account> accounts) {
  final listUc = _MockList();
  final createUc = _MockCreate();
  final deleteUc = _MockDelete();
  final getUc = _MockGet();
  final updateUc = _MockUpdate();
  when(() => listUc.call())
      .thenAnswer((_) async => dartz.Right(accounts));
  registerFallbackValue(const CreateAccountParams(
    name: '',
    accountType: AccountType.asset,
    category: AccountCategory.savings,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));
  registerFallbackValue(const UpdateAccountParams(id: '', version: 0));
  return MaterialApp(
    home: BlocProvider<AccountBloc>(
      create: (_) =>
          AccountBloc(listUc, createUc, deleteUc, getUc, updateUc),
      child: const AccountsPage(),
    ),
  );
}

void main() {
  // 真实布局单卡最小 280px；副信息为单行，窄视口会触发省略号。
  // 用宽视口确保单行完整渲染，匹配实际桌面网格。
  const size = Size(1400, 900);

  testWidgets('savings card shows 利率 and no progress bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_savings()]));
    await t.pumpAndSettle();
    expect(find.textContaining('利率 1.50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('credit card shows 额度 + 账单/还款日 + red usage bar',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_credit()]));
    await t.pumpAndSettle();
    expect(find.textContaining('额度'), findsWidgets);
    expect(find.textContaining('账单5日'), findsOneWidget);
    expect(find.textContaining('还款25日'), findsOneWidget);
    final bar = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.6, 0.001)); // 3000/5000
    expect(bar.backgroundColor ?? AppColors.fg, isNot(AppColors.negative));
    expect((bar.valueColor as AlwaysStoppedAnimation<Color?>?)?.value,
        AppColors.negative);
  });

  testWidgets('investment card shows +return% (green) and no bar',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_investment()]));
    await t.pumpAndSettle();
    expect(find.textContaining('今年收益'), findsOneWidget);
    expect(find.textContaining('+8.25%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('fixed deposit card shows 到期 + 利率 and no bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_fixed()]));
    await t.pumpAndSettle();
    expect(find.textContaining('到期'), findsOneWidget);
    expect(find.textContaining('2027-06-15'), findsOneWidget);
    expect(find.textContaining('利率 2.75%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('gold card shows 买入 + 涨幅 and no bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_gold()]));
    await t.pumpAndSettle();
    expect(find.textContaining('买入'), findsOneWidget);
    expect(find.textContaining('+20.00%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('real estate card shows 现估值 + 增值 and no bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_estate()]));
    await t.pumpAndSettle();
    expect(find.textContaining('现估值'), findsOneWidget);
    expect(find.textContaining('+20.00%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('loan card shows 原始/月供/下次 + green repaid bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_loan()]));
    await t.pumpAndSettle();
    expect(find.textContaining('原始'), findsOneWidget);
    expect(find.textContaining('月供'), findsOneWidget);
    expect(find.textContaining('下次'), findsOneWidget);
    final bar = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.6, 0.001)); // (100-40)/100
    expect((bar.valueColor as AlwaysStoppedAnimation<Color?>?)?.value,
        AppColors.positive);
  });
}
