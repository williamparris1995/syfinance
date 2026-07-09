// Reproduces the category-edit parent_id bug: editing a category, selecting a
// parent, and saving should dispatch UpdateAccountParams with the chosen
// parentId. Drives the desktop _EditorPanel end-to-end (load → select row →
// pick parent in dropdown → save).
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

Account _expCat(String id, String name, {String parentId = ''}) => Account(
      id: id,
      name: name,
      accountType: AccountType.expense,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      parentId: parentId,
      version: 1,
    );

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
    registerFallbackValue(const UpdateAccountParams(id: 'x', version: 1));
  });

  Future<void> pumpPage(WidgetTester tester, List<Account> accounts) async {
    when(() => listUc.call())
        .thenAnswer((_) async => dartz.Right(accounts));
    when(() => updateUc.call(any()))
        .thenAnswer((_) async => dartz.Right(accounts.first));
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(
      BlocProvider<CategoryBloc>(
        create: (_) => CategoryBloc(listUc, createUc, deleteUc, updateUc),
        child: const MaterialApp(home: CategoryManagementPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('edit category + select parent + save dispatches parentId (Bug)',
      (tester) async {
    final accounts = [
      _expCat('e1', '餐饮'), // preset, top-level → parent candidate
      _expCat('e2', '老村长'), // user category, top-level initially
    ];
    await pumpPage(tester, accounts);

    // 1. click 老村长 row (desktop list)
    await tester.tap(find.byKey(CategoryManagementPage.rowKey('e2')));
    await tester.pumpAndSettle();

    // 2. open parent dropdown (shows '无（顶级分类）' initially) and pick 餐饮
    await tester.tap(find.text('无（顶级分类）'));
    await tester.pumpAndSettle();
    // popup overlay renders 餐饮 as a DropdownMenuItem after the list row
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();

    // 3. save
    await tester.tap(find.byKey(CategoryManagementPage.saveKey));
    await tester.pumpAndSettle();

    // 4. verify UpdateAccountParams carries parentId='e1'
    final captured = verify(() => updateUc.call(captureAny())).captured.single
        as UpdateAccountParams;
    expect(captured.id, 'e2', reason: 'should update 老村长');
    expect(captured.parentId, 'e1',
        reason: 'BUG: parentId empty despite selecting 餐饮 as parent');
  });

  testWidgets(
      'editing a sub-category shows its actual parent in the dropdown '
      '(DropdownButtonFormField.value must reapply after _hydrate)',
      (tester) async {
    // DropdownButtonFormField.value is deprecated: it acts as initialValue and
    // is NOT reapplied when _hydrate changes _parentId on item switch. So when
    // the editor first mounts in new-mode (_parentId='') and the user then
    // selects a sub-category (parentId non-empty), _hydrate sets _parentId but
    // the dropdown's internal FormField state stays '' → shows 无（顶级分类）
    // instead of the real parent. A ValueKey tied to item id forces remount.
    final accounts = [
      _expCat('e1', '餐饮'),
      _expCat('e2', '咖啡', parentId: 'e1'), // sub-category of 餐饮
    ];
    await pumpPage(tester, accounts);

    // click 咖啡 (sub-category) → editor should hydrate _parentId='e1'
    await tester.tap(find.byKey(CategoryManagementPage.rowKey('e2')));
    await tester.pumpAndSettle();

    // the dropdown must display 餐饮 (咖啡's actual parent), not 无（顶级分类）
    final dropdownDisplay = find.descendant(
      of: find.byType(DropdownButtonFormField<String>),
      matching: find.text('餐饮'),
    );
    expect(dropdownDisplay, findsOneWidget,
        reason: 'dropdown should show 餐饮 (咖啡 parent); stale 无 means '
            'DropdownButtonFormField internal state diverged from _parentId');
  });
}
