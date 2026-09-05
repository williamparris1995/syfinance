/// F6 UI 链:持仓买入表单(ui_buy_form)。
///
/// 链路:DS 预置标的 + 资金账户 + 投资账户 → 投资组合顶栏「买入持仓」→
/// TradeSheetPage(选择证券 / 持仓账户 / 资金账户 / 数量 / 价格 / 费用)→
/// 「确认买入」提交 → 断言:
///   ① DS 侧持仓落位(数量 / 含费均价)+ 台账 1 行 + 现金腿余额联动
///      (LLD-8 反直觉语义照实钉死:现金腿 = price×qty,fee 不走现金腿);
///   ② 投资组合列表出现新持仓(全新 app 进入,富文本感知)。
///
/// 语义出入说明(记报告不修生产):TradeSheet 成功 pop 后持仓列表页不自动
/// 重拉(HoldingsPage 无 pop 回调/RouteAware)→ 列表显示断言放下一个
/// testWidgets(pump 全新 app)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_buy_form_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter/material.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String fundsId; // UI买资金(初始 10,000.00)
  late String investId; // UI买证券账户(asset investment,初始 0)
  late String securityId; // UI买成长混合(F6UI01)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;标的/账户经 DS 铺,UI 只测买入交互。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final holdings = HoldingLocalDataSource(db, txns);
    final accounts = AccountLocalDataSource(db);

    // ---- 自包含夹具(UI买* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('UI买资金', 1000000); // 10,000.00
    final invest = await accounts.create(const CreateAccountParams(
      name: 'UI买证券账户',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    investId = invest.id;
    final sec = await holdings.createSecurity(
      symbol: 'F6UI01',
      name: 'UI买成长混合',
      type: SecurityType.fund,
      exchange: 'CN',
      currency: 'CNY',
    );
    securityId = sec.id;
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('买①买入提交:三下拉 + 数量/价格/费用 → 持仓/台账/现金腿落位', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 10,000.00

    await pumpApp(t);
    await goPage(t, '投资组合');

    // 顶栏「买入持仓」(app_shell 路由感知创建按钮,location==/holdings 才显)。
    final createBtn = find.text('买入持仓');
    expect(createBtn.evaluate(), isNotEmpty, reason: '顶栏买入持仓入口');
    await t.tap(createBtn.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('记录交易'), findsWidgets, reason: '交易 Sheet 页标题');

    // 选择证券(下拉菜单项文案 = 'symbol · name';overlay 渲染在后取 .last)。
    await t.tap(find.byKey(const ValueKey('securityDropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('F6UI01 · UI买成长混合').last);
    await t.pumpAndSettle();

    // 持仓账户 + 资金账户。
    await t.tap(find.byKey(const ValueKey('accountDropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('UI买证券账户').last);
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('fromAccountDropdown')));
    await t.pumpAndSettle();
    await t.tap(find.text('UI买资金').last);
    await t.pumpAndSettle();

    // 数量 100 / 价格 10.50 / 费用 5.00(默认类型 buy,无需切 segmented)。
    await t.enterText(find.byKey(const ValueKey('qtyField')), '100');
    await t.enterText(find.byKey(const ValueKey('priceField')), '10.50');
    await t.enterText(find.byKey(const ValueKey('feeField')), '5');
    await t.pumpAndSettle();

    // 实时预览:买入金额(含费用)= 1,055.00;资金余额充足(fail-fast 不触发)。
    expect(textContainingRich('1,055.00'), findsWidgets,
        reason: '实时金额预览 = 数量×价格 + 费用');

    // 提交按钮在表单底部(可能低于视口)→ 先滚动露出再点,否则 tap 落空。
    await t.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('submitButton')));
    await t.pumpAndSettle(const Duration(seconds: 2));

    // ---- DS 断言(raw drift / 真实 DS 读) ----
    final holdingRows =
        await HoldingLocalDataSource(db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)))
            .listHoldings(accountId: investId);
    final mine = holdingRows.where((h) => h.securityId == securityId).toList();
    expect(mine, hasLength(1), reason: '买入建仓 1 行');
    expect(mine.single.quantity, 100, reason: '数量 100');
    // oracle:均价 = (10.50×100 + 5.00)/100 = 1,055 分(fee 资本化入成本)。
    expect(mine.single.avgCostCents, 1055, reason: '含费均价 = 10.55 元');

    // oracle(LLD-8 照实钉死):现金腿 = price×qty = 105,000 分,fee 不减现金。
    expect(await balanceOf(db, fundsId), beforeFunds - 105000,
        reason: '资金 −price×qty(fee 不走现金腿)');

    // 台账(HoldingTransactions)1 行 buy。
    final ledgerRows = await (db.select(db.holdingTransactions)
          ..where((x) => x.securityId.equals(securityId)))
        .get();
    expect(ledgerRows, hasLength(1), reason: '买入台账 1 行');
  });

  testWidgets('买②列表回看:新持仓入列(全新 app 进入)', (t) async {
    await pumpApp(t);
    await goPage(t, '投资组合');

    expect(textContainingRich('UI买成长混合'), findsWidgets, reason: '持仓卡显示标的名');
    expect(textContainingRich('F6UI01'), findsWidgets, reason: '持仓卡显示代码');
  });
}
