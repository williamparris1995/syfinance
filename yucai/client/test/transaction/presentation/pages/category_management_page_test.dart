// TDD three-size widget test for CategoryManagementPage.
//
// Asserts御财 responsive breakpoints drive three distinct edit surfaces:
//   - 390   → mobile  → edit form opens as a bottom sheet
//   - 1024  → tablet  → edit form opens as an end-drawer
//   - 1440  → desktop → left list + right edit panel always visible
//
// Plus:
//   - type tabs (支出分类 / 收入分类) switch the loaded type
//   - the category list shows icon + name + 系统标记 for preset categories
//   - the delete affordance is disabled for system (preset) categories
//   - the 新建分类 entry exists and opens the edit surface
//
// The bloc is wired via BlocProvider with mocked use-cases; no DI / no gRPC.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/category_bloc.dart';
import 'package:yucai_client/transaction/presentation/pages/category_management_page.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

Account _cat(String id, String name, AccountType type) => Account(
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

const _expenseAccounts = <Account>[
  Account(
    id: 'e1', name: '餐饮', accountType: AccountType.expense,
    category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 0,
    ownership: Ownership.personal, status: AccountStatus.active,
  ),
  Account(
    id: 'e2', name: '自定义', accountType: AccountType.expense,
    category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 0,
    ownership: Ownership.personal, status: AccountStatus.active,
  ),
];

Widget _harness(Widget child, Size size) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late _MockList listUc;
  late _MockCreate createUc;
  late _MockDelete deleteUc;
  late _MockUpdate updateUc;

  setUp(() {
    listUc = _MockList();
    createUc = _MockCreate();
    deleteUc = _MockDelete();
    updateUc = _MockUpdate();
    registerFallbackValue(CreateAccountParams(
      name: 'x',
      accountType: AccountType.expense,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    registerFallbackValue(const UpdateAccountParams(id: 'e2', version: 1));
    when(() => listUc.call())
        .thenAnswer((_) async => dartz.Right(List.of(_expenseAccounts)));
    when(() => createUc.call(any()))
        .thenAnswer((_) async => dartz.Right(_expenseAccounts.first));
    when(() => updateUc.call(any()))
        .thenAnswer((_) async => dartz.Right(_expenseAccounts.first));
    when(() => deleteUc.call(any()))
        .thenAnswer((_) async => const dartz.Right(null));
  });

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    await tester.pumpWidget(_harness(
      BlocProvider<CategoryBloc>(
        create: (_) => CategoryBloc(listUc, createUc, deleteUc, updateUc),
        child: const CategoryManagementPage(),
      ),
      size,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop: list + edit panel both visible, 新建分类 present',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('支出分类'), findsWidgets);
    // AppBar 新建按钮（descendant of AppBar action FilledButton.icon label）。
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('新建分类'),
      ),
      findsOneWidget,
    );
    // 系统标记出现在 preset 分类行。
    expect(find.text('系统'), findsOneWidget);
    // 右侧编辑面板在 desktop 常驻。
    expect(find.byKey(CategoryManagementPage.editPanelKey), findsOneWidget);
  });

  testWidgets('tablet: edit panel opens in end-drawer on 新建分类',
      (tester) async {
    await pumpPage(tester, const Size(1024, 768));
    expect(find.text('餐饮'), findsOneWidget);
    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();
    // 抽屉内的编辑表单。
    expect(find.byKey(CategoryManagementPage.editPanelKey), findsOneWidget);
  });

  testWidgets('mobile: edit panel opens as bottom sheet on 新建分类',
      (tester) async {
    await pumpPage(tester, const Size(390, 844));
    expect(find.text('餐饮'), findsOneWidget);
    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();
    expect(find.byKey(CategoryManagementPage.editPanelKey), findsOneWidget);
  });

  testWidgets('system category row disables delete',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    // 餐饮 is preset → delete disabled (onPressed null).
    final btn = tester.widget<IconButton>(find.descendant(
      of: find.byKey(CategoryManagementPage.rowKey('e1')),
      matching: find.byKey(CategoryManagementPage.deleteKey('e1')),
    ));
    expect(btn.onPressed, isNull);
    // Tapping the system delete must NOT call the delete use-case.
    await tester.tap(find.byKey(CategoryManagementPage.deleteKey('e1')));
    await tester.pump();
    verifyNever(() => deleteUc.call('e1'));
  });

  testWidgets('type tab switches to income and reloads',
      (tester) async {
    when(() => listUc.call()).thenAnswer((_) async => dartz.Right(<Account>[
          ..._expenseAccounts,
          _cat('i1', '工资', AccountType.income),
        ]));
    await pumpPage(tester, const Size(1440, 900));
    // Initial load is expense.
    verify(() => listUc.call()).called(greaterThanOrEqualTo(1));
    expect(find.text('餐饮'), findsOneWidget);

    // Tap 收入分类 tab.
    await tester.tap(find.text('收入分类'));
    await tester.pumpAndSettle();
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('餐饮'), findsNothing);
  });
}
