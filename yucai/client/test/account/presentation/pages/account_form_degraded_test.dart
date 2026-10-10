// F51 FR-1 / FR-2(ADR-3 / U3)—— account_form_page 表单降级态测试:
// loan/invest 账户挂接债/持仓时字段组只读 + 派生值 + 提示条 + 提交不写列。
//
// 挂接检测经 getIt 仓库(表单测试坑记忆:getIt 须注册 mock,照
// account_detail_page_test 的 F35 先例);数字照 spec FR-1 Scenario:
// 总额 35,000+9,100 / 剩余 29,683.44+4,540.32 / 月供 1,630.46+447.44 /
// 下期 2026-10-12、2026-10-25。
import 'package:dartz/dartz.dart';
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
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}
// F51:表单编辑态挂接检测经 GetIt 直取 DebtRepository/HoldingRepository。
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}

/// 挂接 loan 账户 'a1' 的借入债(spec 数字)。
Debt _debt(String id, int totalCents, int remainingCents) => Debt(
      id: id,
      accountId: 'a1',
      counterparty: '债权方$id',
      interestRate: 3.85,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2024, 1, 10),
      dueDate: DateTime(2029, 1, 10),
      totalPrincipalCents: totalCents,
      remainingPrincipalCents: remainingCents,
      version: 1,
      createdAt: DateTime(2024, 1, 10),
      updatedAt: DateTime(2026, 10, 1),
    );

PaymentEntry _entry(String id, DateTime date, int totalCents, {bool paid = false}) =>
    PaymentEntry(
      id: id,
      paymentDate: date,
      principalCents: 100000,
      interestCents: totalCents - 100000,
      totalCents: totalCents,
      paid: paid,
      paidCents: 0,
      transactionId: '',
    );

final _d1 = _debt('d1', 3500000, 2968344); // 总额 ¥35,000.00 / 剩余 ¥29,683.44
final _d2 = _debt('d2', 910000, 454032); // 总额 ¥9,100.00 / 剩余 ¥4,540.32

/// loan 账户(列值故意与债侧一致 —— 提交必须无视 controller 传 null)。
Account _loanAccount() => Account(
      id: 'a1',
      name: '房贷组合',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      loanOriginalCents: 4410000,
      loanRemainingCents: 3422376,
      loanMonthlyCents: 207790,
      loanNextPaymentDate: DateTime(2026, 10, 12),
    );

/// invest 账户(挂持仓 'i1';ytd 列值故意非空 —— 降级态须显示「—」且提交 null)。
Account _investAccount() => const Account(
      id: 'i1',
      name: '证券账户',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      investCostCents: 999999,
      investMarketValueCents: 888888,
      investReturnYtd: 12.5,
    );

Holding _holding(String id, double qty, int avgCostCents, int mvCents) => Holding(
      id: id,
      accountId: 'i1',
      securityId: 's-$id',
      securityName: '基金$id',
      securitySymbol: 'F$id',
      quantity: qty,
      avgCostCents: avgCostCents,
      marketValueCents: mvCents,
      unrealizedPnlCents: mvCents - (qty * avgCostCents).round(),
      version: 1,
    );

// Σ成本 = 100×15 + 200×20 = ¥5,500.00;Σ市值 = ¥1,650.00 + ¥3,900.00 = ¥5,550.00
final _h1 = _holding('h1', 100, 1500, 165000);
final _h2 = _holding('h2', 200, 2000, 390000);

void main() {
  late _MockDebtRepo debtRepo;
  late _MockHoldingRepo holdingRepo;

  setUpAll(() {
    registerFallbackValue(const CreateAccountParams(
      name: '',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    registerFallbackValue(const UpdateAccountParams(id: '', version: 0));
    // list(typeFilter:) 的枚举实参需要 mocktail fallback(F35 同款)。
    registerFallbackValue(DebtType.borrowedIn);
  });

  setUp(() {
    debtRepo = _MockDebtRepo();
    holdingRepo = _MockHoldingRepo();
    // F51:表单 _detectAttachments 经 GetIt 取两仓库;默认空(未挂接)。
    when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => const Right(<Debt>[]));
    when(() => debtRepo.list())
        .thenAnswer((_) async => const Right(<Debt>[]));
    when(() => holdingRepo
            .listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const Right(<Holding>[]));
    GetIt.instance.registerSingleton<DebtRepository>(debtRepo);
    GetIt.instance.registerSingleton<HoldingRepository>(holdingRepo);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Widget harness({
    Account? existing,
    GetAccountUseCase? get,
    UpdateAccountUseCase? update,
  }) {
    final list = _MockList();
    when(() => list.call())
        .thenAnswer((_) async => const Right(<Account>[]));
    final bloc = AccountBloc(
      list,
      _MockCreate(),
      _MockDelete(),
      get ?? _MockGet(),
      update ?? _MockUpdate(),
    );
    return MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => bloc,
        child: AccountFormPage(existing: existing),
      ),
    );
  }

  testWidgets('① 挂债 loan 账户编辑 → loan 四字段只读派生值 + 提示条(spec 数字)', (tester) async {
    when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => Right(<Debt>[_d1, _d2]));
    when(() => debtRepo.get('d1')).thenAnswer((_) async => Right(DebtDetail(
          debt: _d1,
          schedule: [_entry('e1', DateTime(2026, 10, 12), 163046)],
        )));
    when(() => debtRepo.get('d2')).thenAnswer((_) async => Right(DebtDetail(
          debt: _d2,
          schedule: [_entry('e2', DateTime(2026, 10, 25), 44744)],
        )));

    await tester.pumpWidget(harness(existing: _loanAccount()));
    await tester.pumpAndSettle();

    // 派生四值(spec FR-1 Scenario:Σ总额 / Σ剩余 / Σ下一未还期 / min 下期日)。
    expect(find.text('¥44,100.00'), findsOneWidget);
    expect(find.text('¥34,223.76'), findsOneWidget);
    expect(find.text('¥2,077.90'), findsOneWidget);
    expect(find.text('2026-10-12'), findsOneWidget);
    // 组头提示条。
    expect(find.textContaining('以债务数据为准'), findsOneWidget);
    // loan 组编辑控件移除(降级只读);共享字段(机构/利率)保留可编辑。
    expect(find.text('原始本金'), findsNothing);
    expect(find.text('贷款总额'), findsOneWidget);
    expect(find.text('贷款机构'), findsOneWidget);
    expect(find.text('利率 (%)'), findsOneWidget);
  });

  testWidgets('②a 无挂接 loan 编辑 → 字段组可编辑原样(FR-4)', (tester) async {
    await tester.pumpWidget(harness(existing: _loanAccount()));
    await tester.pumpAndSettle();

    expect(find.text('原始本金'), findsOneWidget);
    expect(find.text('月供'), findsOneWidget);
    expect(find.textContaining('以债务数据为准'), findsNothing);
    expect(find.text('¥44,100.00'), findsNothing);
  });

  testWidgets('②b 新建态切 loan tab → 不检测挂接、组可编辑(ADR-3 grill)', (tester) async {
    // 仓库里有挂 'a1' 的债,但新建态无账户 id,不应触发降级。
    when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => Right(<Debt>[_d1]));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('贷款'));
    await tester.pumpAndSettle();

    expect(find.text('原始本金'), findsOneWidget);
    expect(find.textContaining('以债务数据为准'), findsNothing);
    verifyNever(() => debtRepo.list(typeFilter: any(named: 'typeFilter')));
  });

  testWidgets('③ 降级 loan 保存 → UpdateAccountParams loan 组四字段 null(orAbsent 保留列值)', (tester) async {
    when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => Right(<Debt>[_d1, _d2]));
    when(() => debtRepo.get('d1')).thenAnswer((_) async => Right(DebtDetail(
          debt: _d1,
          schedule: [_entry('e1', DateTime(2026, 10, 12), 163046)],
        )));
    when(() => debtRepo.get('d2')).thenAnswer((_) async => Right(DebtDetail(
          debt: _d2,
          schedule: [_entry('e2', DateTime(2026, 10, 25), 44744)],
        )));

    final acc = _loanAccount();
    final get = _MockGet();
    when(() => get.call('a1')).thenAnswer((_) async => Right(acc));
    final update = _MockUpdate();
    // Left 阻断成功 reload/pop(测试 harness 无路由栈可 pop)。
    when(() => update.call(captureAny()))
        .thenAnswer((_) async => const Left(ServerFailure('stub-no-reload')));

    await tester.pumpWidget(harness(existing: acc, get: get, update: update));
    await tester.pumpAndSettle();
    // 表单长,保存按钮在视口外:先滚动可见再点。
    await tester.ensureVisible(find.text('保存修改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    final captured = verify(() => update.call(captureAny())).captured;
    expect(captured, hasLength(1));
    final p = captured.single as UpdateAccountParams;
    // loan 组四列全 null → DS orAbsent → 保留原列值(不写列)。
    expect(p.loanOriginalCents, isNull);
    expect(p.loanRemainingCents, isNull);
    expect(p.loanMonthlyCents, isNull);
    expect(p.loanNextPaymentDate, isNull);
    // 对照:共享字段正常提交(降级不误伤编辑能力)。
    expect(p.name, '房贷组合');
  });

  testWidgets('④ 挂持仓 invest 账户编辑 → 只读派生成本/市值 + ytd「—」;保存 invest 组 null', (tester) async {
    when(() => holdingRepo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => Right(<Holding>[_h1, _h2]));

    final acc = _investAccount();
    final get = _MockGet();
    when(() => get.call('i1')).thenAnswer((_) async => Right(acc));
    final update = _MockUpdate();
    when(() => update.call(captureAny()))
        .thenAnswer((_) async => const Left(ServerFailure('stub-no-reload')));

    await tester.pumpWidget(harness(existing: acc, get: get, update: update));
    await tester.pumpAndSettle();

    // 派生两值 + ytd「—」(持仓侧无同义字段,不造新数字)。
    expect(find.text('¥5,500.00'), findsOneWidget);
    expect(find.text('¥5,550.00'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('以持仓数据为准'), findsOneWidget);

    await tester.ensureVisible(find.text('保存修改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    final captured = verify(() => update.call(captureAny())).captured;
    final p = captured.single as UpdateAccountParams;
    // invest 组三列全 null(成本/市值/ytd)。
    expect(p.investCostCents, isNull);
    expect(p.investMarketValueCents, isNull);
    expect(p.investReturnYtd, isNull);
    expect(p.name, '证券账户');
  });

  testWidgets('⑤ 挂债但全付清(无未还期)→ 月供/下期显「—」(边界)', (tester) async {
    when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => Right(<Debt>[_d1]));
    when(() => debtRepo.get('d1')).thenAnswer((_) async => Right(DebtDetail(
          debt: _d1,
          schedule: [_entry('e1', DateTime(2026, 9, 12), 163046, paid: true)],
        )));

    await tester.pumpWidget(harness(existing: _loanAccount()));
    await tester.pumpAndSettle();

    // Σ总额/Σ剩余仍显示;月供与下期还款日 = null → 「—」。
    expect(find.text('¥35,000.00'), findsOneWidget);
    expect(find.text('¥29,683.44'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
  });
}
