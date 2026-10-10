// F49 T5(FR-4a)widget 测试 —— 信用卡卡面分期徽标(fchip,照 prototype v12):
//  - 挂 1 笔并入型分期:卡面余额下方渲染「分期 1 笔 · 剩余 ¥X」
//    (accent 软底 pill,文案含笔数与剩余金额,与卡详情 FR-4b 区块同源
//    debts 流);
//  - 0 笔(无挂接/已清偿):不渲染徽标(条件渲染,N≥1 才出)。
//
// 夹具口径:平安信用卡(挂接卡,credit-正欠款 ¥1,250.00)+ 招行储蓄;
// card_loan 借入债经 collectionAccountId 挂接平安卡(剩余本金 ¥8,400.00)
// —— 债的载体户不在账户库(已被 T4 过滤),徽标数据走全量 debts 流,
// 不受列表过滤影响。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart'
    show CreateAccountParams, UpdateAccountParams;
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/accounts_page.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}
class _MockDebtRepo extends Mock implements DebtRepository {}

class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

Account _savings() => const Account(
      id: 's1',
      name: '招行储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 500000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// 挂接卡:平安信用卡(credit-正不变式,欠款 ¥1,250.00)。
Account _card() => const Account(
      id: 'card-1',
      name: '平安信用卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 125000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// 并入型 card_loan 借入债:collectionAccountId 挂接 card-1。
Debt _cardLoan(int remaining) => Debt(
      id: 'd-card',
      accountId: 'l-carrier', // 载体户(不在账户库,已被 T4 过滤)
      counterparty: '平安银行',
      interestRate: 0.6,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 9, 10),
      dueDate: DateTime(2027, 9, 10),
      totalPrincipalCents: 840000,
      remainingPrincipalCents: remaining,
      version: 1,
      createdAt: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 10),
      subtype: DebtSubtypes.cardLoan,
      collectionAccountId: 'card-1',
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
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AccountBloc>(
          create: (_) =>
              AccountBloc(listUc, createUc, deleteUc, getUc, updateUc),
        ),
        BlocProvider<CurrencyBloc>.value(
            value: _FakeCurrencyBloc(const CurrencyState())),
      ],
      child: const AccountsPage(),
    ),
  );
}

void main() {
  // 宽视口:desktop 完整卡(fchip 渲染于余额行下,对齐 v12)。
  const size = Size(1400, 900);

  setUp(() {
    GetIt.instance.registerLazySingleton<DataRefreshNotifier>(
        DataRefreshNotifier.new);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  void registerDebts(List<Debt> debts) {
    final debtRepo = _MockDebtRepo();
    when(() => debtRepo.list())
        .thenAnswer((_) async => dartz.Right(debts));
    GetIt.instance.registerSingleton<DebtRepository>(debtRepo);
  }

  testWidgets('挂 1 笔并入型分期:卡面渲染「分期 1 笔 · 剩余 ¥8,400.00」',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    registerDebts([_cardLoan(840000)]);

    await t.pumpWidget(_harness([_savings(), _card()]));
    await t.pumpAndSettle();

    expect(find.text('平安信用卡'), findsOneWidget);
    // 徽标整串:笔数 1 + 剩余金额(tabular 两位小数,app 金额口径)。
    expect(find.text('分期 1 笔 · 剩余 ¥8,400.00'), findsOneWidget);
    // 卡面欠款主数字照常(徽标是追加行,不改余额口径)。
    expect(find.text('¥1,250.00'), findsOneWidget);
  });

  testWidgets('0 笔(已清偿不计):不渲染分期徽标', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    // 挂接债已清偿(剩余 0)→ 未结清口径 0 笔 → 徽标不渲染。
    registerDebts([_cardLoan(0)]);

    await t.pumpWidget(_harness([_savings(), _card()]));
    await t.pumpAndSettle();

    expect(find.text('平安信用卡'), findsOneWidget);
    expect(find.textContaining('分期'), findsNothing);
    expect(find.textContaining('¥8,400.00'), findsNothing);
  });
}
