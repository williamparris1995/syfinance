// TDD three-size widget test for CategoryManagementPage (OD-aligned).
//
// Asserts御财 responsive breakpoints drive three distinct edit surfaces:
//   - 390   → mobile  → edit form opens as a bottom sheet
//   - 1024  → tablet  → edit form opens as an end-drawer
//   - 1440  → desktop → left list + right edit panel always visible
//
// Plus (OD alignment):
//   - type tabs (支出分类 / 收入分类) switch the loaded type
//   - the category list shows emoji + name + 系统标记 for preset categories
//   - the editor delete affordance is disabled for system (preset) categories
//   - the 新建分类 entry exists and opens the edit surface
//   - icon grid + color palette selectors (click-to-pick)
//   - picking icon + color then save dispatches values via CreateAccountParams
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
    // 新建分类 button in custom topbar.
    expect(find.byKey(CategoryManagementPage.newCategoryKey), findsOneWidget);
    // 系统标记出现在 preset 分类行。
    expect(find.text('系统'), findsOneWidget);
    // 右侧编辑面板在 desktop 常驻。
    expect(find.byKey(CategoryManagementPage.editPanelKey), findsOneWidget);
  });

  testWidgets('tablet: edit panel opens in end-drawer on 新建分类',
      (tester) async {
    await pumpPage(tester, const Size(1024, 768));
    expect(find.text('餐饮'), findsOneWidget);
    await tester.tap(find.byKey(CategoryManagementPage.newCategoryKey));
    await tester.pumpAndSettle();
    // 抽屉内的编辑表单。
    expect(find.byKey(CategoryManagementPage.editPanelKey), findsOneWidget);
  });

  testWidgets('mobile: edit panel opens as bottom sheet on 新建分类',
      (tester) async {
    await pumpPage(tester, const Size(390, 844));
    expect(find.text('餐饮'), findsOneWidget);
    await tester.tap(find.byKey(CategoryManagementPage.newCategoryKey));
    await tester.pumpAndSettle();
    expect(find.byKey(CategoryManagementPage.editPanelKey), findsOneWidget);
  });

  testWidgets('system category editor disables delete', (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    // 餐饮(e1) is preset → system. Tap its row to open the editor.
    await tester.tap(find.byKey(CategoryManagementPage.rowKey('e1')));
    await tester.pumpAndSettle();
    // Delete button exists; tapping it must NOT call the delete use-case
    // (disabled for system presets).
    expect(find.byKey(CategoryManagementPage.editorDeleteKey), findsOneWidget);
    await tester.tap(find.byKey(CategoryManagementPage.editorDeleteKey),
        warnIfMissed: false);
    await tester.pump();
    verifyNever(() => deleteUc.call('e1'));
  });

  testWidgets('type tab switches to income and reloads', (tester) async {
    when(() => listUc.call()).thenAnswer((_) async => dartz.Right(<Account>[
          ..._expenseAccounts,
          _cat('i1', '工资', AccountType.income),
        ]));
    await pumpPage(tester, const Size(1440, 900));
    // Initial load is expense.
    verify(() => listUc.call()).called(greaterThanOrEqualTo(1));
    expect(find.text('餐饮'), findsOneWidget);

    // Tap 收入分类 tab (first occurrence = the tab, not the seg-readonly).
    await tester.tap(find.text('收入分类').first);
    await tester.pumpAndSettle();
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('餐饮'), findsNothing);
  });

  testWidgets('edit panel shows icon grid and color palette selectors '
      '(click-to-pick, not manual text input)', (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    // Icon picker: preset emoji chips present and clickable.
    expect(find.byKey(const ValueKey('icon_pick_🥢')), findsOneWidget);
    expect(find.byKey(const ValueKey('icon_pick_🚌')), findsOneWidget);
    // Color picker: preset swatches present and clickable.
    expect(find.byKey(const ValueKey('color_pick_#B08D57')), findsOneWidget);
    expect(find.byKey(const ValueKey('color_pick_#4A7FC4')), findsOneWidget);
    // No manual icon/color TextFields (the old TextEditingController inputs).
    expect(find.text('图标（名称）'), findsNothing);
    expect(find.text('颜色（hex）'), findsNothing);
    // Parent dropdown exists with the default top-level option.
    expect(find.text('父分类'), findsWidgets);
    expect(find.text('无（顶级分类）'), findsOneWidget);
  });

  testWidgets('clicking an icon + color then save dispatches the picked '
      'values through CreateAccountParams', (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    // Enter a name (the first TextField in the panel = 分类名称).
    await tester.enterText(find.byType(TextField).first, '测试分类');
    // Pick an icon chip and a color swatch (ensureVisible first — the editor
    // body scrolls and the pickers may be below the fold).
    await tester.ensureVisible(find.byKey(const ValueKey('icon_pick_🚌')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('icon_pick_🚌')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('color_pick_#4A7FC4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color_pick_#4A7FC4')));
    await tester.pump();
    // Save (desktop default panel is in 新建 mode → create).
    await tester.ensureVisible(find.byKey(CategoryManagementPage.saveKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CategoryManagementPage.saveKey),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    final captured = verify(() => createUc.call(captureAny())).captured.single
        as CreateAccountParams;
    expect(captured.icon, '🚌');
    expect(captured.color, '#4A7FC4');
    // Default parent is '' (顶级分类) → empty parentId.
    expect(captured.parentId, '');
  });
}
