// F49 T4(FR-3)widget 测试 —— 账户页展示过滤 + 净资产钉死:
//  - 载体行不可见:isSystem=true 载体户(卡贷并入模式)不渲染成卡片,
//    贷款组计数/小计=可见行之和(默认与「含已归档」两口径下均不可见);
//  - 净资产钉死:汇总头(净资产/总负债)对 isSystem 翻转逐位一致
//    (计算处保留),对照不含载体库的数字断言不同(逐位含载体余额)。
//
// 夹具口径(credit-正不变式):
//   储蓄 ×2 = ¥10,000.00 资产;房贷(可见贷款,无关联债)欠款 ¥4,000.00;
//   载体「平安信用卡 · 卡贷」余额 ¥8,400.00,关联 card_loan 借入债剩余
//   ¥8,400.00 → 账户页 hero 总负债 = 房贷 4,000 + 债务剩余 8,400
//   = ¥12,400.00;净资产 = 10,000 − 12,400 = −¥2,400.00。
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
import 'package:yucai_client/debt/domain/value_objects.dart'
    show AmortizationMethod;

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

Account _savings(String id, String name, {int bal = 5000000}) => Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: bal,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// 可见贷款(无关联债务):小计/hero 走 currentBalanceCents(credit-正)。
Account _mortgage() => const Account(
      id: 'l-vis',
      name: '房贷',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 400000, // ¥4,000.00
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// F49 载体户:卡贷并入模式自动建户(isSystem=true),余额镜像债务剩余。
Account _carrier({bool isSystem = true}) => Account(
      id: 'l-carrier',
      name: '平安信用卡 · 卡贷',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 840000, // ¥8,400.00
      ownership: Ownership.personal,
      status: AccountStatus.active,
      isSystem: isSystem,
      notes: '信用卡贷款(卡贷)自动创建',
    );

/// 载体户名下的 card_loan 借入债(剩余本金 ¥8,400,无未付利息)。
Debt _cardLoanDebt() => Debt(
      id: 'd-card',
      accountId: 'l-carrier',
      counterparty: '平安银行',
      interestRate: 0,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 9, 10),
      dueDate: DateTime(2027, 9, 10),
      totalPrincipalCents: 840000,
      remainingPrincipalCents: 840000,
      version: 1,
      createdAt: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 10),
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

/// 储蓄 ×2(¥5,000 + ¥5,000 = 资产 ¥10,000.00)+ 房贷 + 载体(可选置位)。
List<Account> _library({required bool withCarrier, bool isSystem = true}) => [
      _savings('s1', '招行储蓄', bal: 500000),
      _savings('s2', '建行储蓄', bal: 500000),
      _mortgage(),
      if (withCarrier) _carrier(isSystem: isSystem),
    ];

void main() {
  // 宽视口:desktop 汇总卡 + 分组小计(「小计 ¥…」仅非 mobile 渲染)。
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

  group('F49-T4 载体行不可见(FR-3 列表过滤)', () {
    testWidgets('isSystem 载体行不渲染;贷款组计数=可见行;储蓄组不受扰', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      registerDebts([_cardLoanDebt()]);

      await t.pumpWidget(_harness(_library(withCarrier: true)));
      await t.pumpAndSettle();

      // 载体行消失。
      expect(find.text('平安信用卡 · 卡贷'), findsNothing);
      // 可见账户照常。
      expect(find.text('招行储蓄'), findsOneWidget);
      expect(find.text('建行储蓄'), findsOneWidget);
      expect(find.text('房贷'), findsOneWidget);
      // 组计数=可见行:储蓄 2 个;贷款只剩房贷 1 个(载体不计数)。
      // 未过滤时贷款组会是「2 个账户」→ '2 个账户' 出现两次,此断言翻红。
      expect(find.text('2 个账户'), findsOneWidget, reason: '储蓄组 2 个账户');
      expect(find.text('1 个账户'), findsOneWidget, reason: '贷款组仅剩房贷');
    });

    testWidgets('贷款组小计=可见行之和(载体关联债务剩余不进小计)', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      registerDebts([_cardLoanDebt()]);

      await t.pumpWidget(_harness(_library(withCarrier: true)));
      await t.pumpAndSettle();

      // 可见贷款只有房贷 ¥4,000.00 → 小计 ¥4,000.00(group-head Text.rich
      // 扁平化匹配)。未过滤时载体债务剩余 8,400 会并入 → ¥12,400.00。
      expect(find.textContaining('小计 ¥4,000.00'), findsOneWidget);
      expect(find.textContaining('小计 ¥12,400.00'), findsNothing);
    });

    testWidgets('「含已归档」开关下载体仍不可见(过滤在归档开关上游)', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      registerDebts([_cardLoanDebt()]);

      await t.pumpWidget(_harness([
        ..._library(withCarrier: true),
        _savings('s3', '老账户', bal: 0).copyWith(
            status: AccountStatus.archived), // 归档可见账户,证明开关生效
      ]));
      await t.pumpAndSettle();

      // 勾选「含已归档账户」。
      await t.tap(find.byType(Checkbox));
      await t.pumpAndSettle();

      // 归档的可见账户出现(开关生效),载体仍不可见。
      expect(find.text('老账户'), findsOneWidget);
      expect(find.text('平安信用卡 · 卡贷'), findsNothing);
    });
  });

  group('F49-T4 净资产钉死(FR-3 计算处保留)', () {
    testWidgets('isSystem=true:hero 总负债/净资产逐位含载体余额', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      registerDebts([_cardLoanDebt()]);

      await t.pumpWidget(_harness(_library(withCarrier: true, isSystem: true)));
      await t.pumpAndSettle();

      // 总负债 = 房贷 4,000 + 载体债务剩余 8,400 = ¥12,400.00;
      // 净资产 = 10,000 − 12,400 = −¥2,400.00(负号在币符前,整串匹配)。
      expect(find.textContaining('12,400.00'), findsOneWidget,
          reason: 'hero 总负债含载体余额;列表小计已滤(仅 4,000)');
      expect(find.text('-¥2,400.00'), findsOneWidget,
          reason: '净资产 = 资产 10,000 − 总负债 12,400');
      expect(find.textContaining('10,000.00'), findsWidgets,
          reason: '总资产 ¥10,000.00');
    });

    testWidgets('isSystem 翻转(false):hero 数字逐位一致(计算不受过滤影响)',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      registerDebts([_cardLoanDebt()]);

      await t.pumpWidget(
          _harness(_library(withCarrier: true, isSystem: false)));
      await t.pumpAndSettle();

      // 同库仅 isSystem=false(= 过滤开关前):hero 与置位库逐位一致;
      // 此时载体行可见,其小计 ¥12,400.00 与 hero 同串 → 两处。
      expect(find.textContaining('12,400.00'), findsNWidgets(2),
          reason: 'hero 总负债 + 可见载体并入后的贷款组小计');
      expect(find.text('-¥2,400.00'), findsOneWidget);
    });

    testWidgets('对照:不含载体的库 hero 数字不同(证载体余额被计入)', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      registerDebts(const []); // 无 card_loan 债

      await t.pumpWidget(_harness(_library(withCarrier: false)));
      await t.pumpAndSettle();

      // 总负债只剩房贷 ¥4,000.00;净资产 = 10,000 − 4,000 = ¥6,000.00。
      // 与含载体库(12,400 / −2,400)逐位不同 —— 反证上一组断言确含载体余额。
      expect(find.textContaining('12,400.00'), findsNothing);
      expect(find.text('-¥2,400.00'), findsNothing);
      expect(find.text('¥6,000.00'), findsOneWidget);
    });
  });
}
