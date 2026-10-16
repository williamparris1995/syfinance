// F62 FR-2/ADR-2 —— FilteredAccountPicker(灰显过滤选择器)单测。
// 契约源:prototype/v18 components.md(FilteredAccountPicker)+ design LLD
// 「到账卡过滤:资产类∧status=active;挂卡过滤:category=creditCard;灰显项
// disabled item+副文案原因」。
//
// 覆盖:
//   - 到账卡模式:资产亮 / 信用卡灰+「信用卡不能作为到账卡」/ 负债灰 /
//     归档资产灰
//   - 挂卡模式:信用卡亮,其余灰(方向反转)
//   - 灰显项不可点(NN/g:disabled MenuItem)
//   - 兼容项点选 → onChanged 携带账户 id
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/widgets/filtered_account_picker.dart';

Account _asset({
  String id = 'sav-1',
  String name = '招行储蓄卡',
  AccountStatus status = AccountStatus.active,
}) =>
    Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 100,
      ownership: Ownership.personal,
      status: status,
    );

Account _creditCard({String id = 'cc-1', String name = '平安信用卡'}) => Account(
      id: id,
      name: name,
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Account _loan({String id = 'loan-1', String name = '平安车主贷'}) => Account(
      id: id,
      name: name,
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('到账卡模式(资产类 ∧ active)', () {
    testWidgets('资产亮 / 信用卡灰+原因 / 贷款户灰+原因 / 归档资产灰',
        (t) async {
      String? picked;
      await t.pumpWidget(_wrap(FilteredAccountPicker(
        key: const ValueKey('pick'),
        mode: FilteredAccountMode.disbursement,
        accounts: [
          _asset(),
          _asset(id: 'sav-2', name: '停用储蓄卡', status: AccountStatus.archived),
          _creditCard(),
          _loan(),
        ],
        value: null,
        onChanged: (v) => picked = v,
      )));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('pick')));
      await t.pumpAndSettle();
      // 四项全渲染(灰显不隐藏 —— NN/g 下拉准则:让用户知道选项存在)。
      expect(find.text('招行储蓄卡'), findsWidgets);
      expect(find.text('平安信用卡'), findsWidgets);
      expect(find.text('平安车主贷'), findsWidgets);
      // 副文案原因句(prototype 文案逐字)。
      expect(find.text('信用卡不能作为到账卡'), findsOneWidget);
      expect(find.textContaining('负债账户'), findsOneWidget);
      expect(find.textContaining('归档'), findsOneWidget);
      // 灰显项 disabled:MenuItem.enabled == false。
      final ccItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('平安信用卡').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(ccItem.enabled, isFalse);
      final savItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('招行储蓄卡').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(savItem.enabled, isTrue);
      // 点兼容项 → onChanged 携带 id;点灰显项 → 无效。
      await t.tap(find.text('平安信用卡').last);
      await t.pumpAndSettle();
      expect(picked, isNull, reason: '灰显项不可点');
      await t.tap(find.byKey(const ValueKey('pick')));
      await t.pumpAndSettle();
      await t.tap(find.text('招行储蓄卡').last);
      await t.pumpAndSettle();
      expect(picked, 'sav-1');
    });
  });

  group('挂卡模式(category=creditCard,方向反转)', () {
    testWidgets('信用卡亮,储蓄卡/贷款户灰+原因;点选信用卡 → onChanged',
        (t) async {
      String? picked;
      await t.pumpWidget(_wrap(FilteredAccountPicker(
        key: const ValueKey('mount'),
        mode: FilteredAccountMode.cardMount,
        accounts: [_asset(), _creditCard(), _loan()],
        value: null,
        onChanged: (v) => picked = v,
      )));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('mount')));
      await t.pumpAndSettle();
      expect(find.textContaining('信用卡账户可挂接'), findsNWidgets(2),
          reason: '储蓄卡 + 贷款户各一条原因句');
      final ccItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('平安信用卡').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(ccItem.enabled, isTrue);
      final loanItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('平安车主贷').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(loanItem.enabled, isFalse);
      await t.tap(find.text('平安信用卡').last);
      await t.pumpAndSettle();
      expect(picked, 'cc-1');
    });
  });

  testWidgets('selected value 渲染在闭合态(items 含 value 时不断言)', (t) async {
    await t.pumpWidget(_wrap(FilteredAccountPicker(
      mode: FilteredAccountMode.disbursement,
      accounts: [_asset(), _creditCard()],
      value: 'sav-1',
      onChanged: (_) {},
    )));
    await t.pumpAndSettle();
    // 闭合态显示当前值(DropdownButton selectedItem)。
    expect(find.text('招行储蓄卡'), findsOneWidget);
  });
}
