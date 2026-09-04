/// F6 UI 链:债权收回交互(ui_collect_form)。
///
/// 链路:DS 预置应收(borrowedOut 借出链产物:资金腿 + 应收账户双写)→
/// 打开债权详情(债权管理 → 卡片点入)→ 收回第一期:
///   行内「确认收款」→ DebtRecordDialog(收款金额只读 + 收款至账户下拉)→
///   选「UI收资金」→ 确认收款 → 期次状态 UI 变化(已收徽标 + 已确认行)。
/// DS 侧断言期次 paid 持久化 + 资金/应收余额双向联动(raw drift,oracle 差值)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_collect_form_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter/material.dart'
    show DropdownButtonFormField, Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String fundsId; // UI收资金(收回到账账户,初始 20,000.00)
  late String recvId; // UI收应收(借出方向应收账户)
  late String debtId; // UI收好友(3,000 / 3 期等额本息)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;借出链产物经 DS 铺,UI 只测收回交互。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final debts = DebtLocalDataSource(db, txns);
    final accounts = AccountLocalDataSource(db);

    // ---- 自包含夹具(UI收* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('UI收资金', 2000000); // 20,000.00
    final recv = await accounts.create(const CreateAccountParams(
      name: 'UI收应收',
      accountType: AccountType.asset,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    recvId = recv.id;

    // 借出 3,000(3 个月 / 3% 等额本息):相对真实 now(首期 = now+1 月,未逾期);
    // create 不设收款账户 → 详情行走 DebtRecordDialog 表单交互(而非行内直发)。
    final now = DateTime.now();
    final debt = await debts.create(
      accountId: recvId,
      counterparty: 'UI收好友',
      interestRate: 0.03,
      amortizationIndex: 0, // 等额本息
      startDate: DateTime(now.year, now.month, now.day - 1),
      dueDate: DateTime(now.year, now.month + 3, 1),
      totalPrincipalCents: 300000, // 3,000.00
      type: DebtType.borrowedOut,
      sourceAccountId: fundsId,
    );
    debtId = debt.id;
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  // 侧栏导航 helper(照 full_audit_test.goPage)。
  Future<void> goPage(WidgetTester t, String sidebarLabel) async {
    var finder = find.text(sidebarLabel);
    if (finder.evaluate().isEmpty) {
      try {
        await t.scrollUntilVisible(
          finder,
          80,
          scrollable: find.byType(Scrollable).first,
          duration: const Duration(milliseconds: 150),
        );
      } catch (_) {}
      await t.pumpAndSettle();
      finder = find.text(sidebarLabel);
    }
    expect(finder.evaluate(), isNotEmpty, reason: '侧栏项「$sidebarLabel」可达');
    await t.tap(finder.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('收①收回第一期:详情 → 确认收款 dialog → 期次已收 + 余额联动', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 17,000.00(借出后)
    final beforeRecv = await balanceOf(db, recvId); // 3,000.00

    // 取第一个未付期次(按还款日排序;oracle:利息口径以 entry.totalCents 为准)。
    final schedule = await db.debtDao.getScheduleByDebt(debtId);
    schedule.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final first = schedule.firstWhere((e) => !e.paid);
    final firstTotal = first.totalCents;

    await pumpApp(t);
    await goPage(t, '债权管理');

    // 债权卡点入详情(卡片 tap → push /receivables/:id)。
    final card = find.text('UI收好友');
    expect(card.evaluate(), isNotEmpty, reason: '借出债权在列');
    // F9 在债权页头部加了搜索/排序控件行,夹具卡被推到首屏之下——
    // tap 前必须滚入视口(否则 tap 落空、详情不开,后续 finder 全扑空)。
    await t.ensureVisible(card.first);
    await t.pumpAndSettle(const Duration(seconds: 1));
    await t.tap(card.first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 详情:收款计划的首期「确认收款」行按钮(可能需滚动露出)。
    final rowBtn = find.text('确认收款');
    await t.ensureVisible(rowBtn.first);
    await t.pumpAndSettle();
    await t.tap(rowBtn.first);
    await t.pumpAndSettle(const Duration(seconds: 1));

    // DebtRecordDialog:收款金额只读 + 收款至账户下拉(Material 对话框,可测)。
    expect(find.text('收款至账户（别人还我入账的账户）'), findsWidgets,
        reason: '确认收款 dialog 打开');
    final dropdown = find.byType(DropdownButtonFormField<String>);
    expect(dropdown.evaluate(), isNotEmpty, reason: 'dialog 账户下拉存在');
    await t.tap(dropdown.first);
    await t.pumpAndSettle();
    await t.tap(find.textContaining('UI收资金').last);
    await t.pumpAndSettle();

    // dialog 提交(overlay 渲染在后,取 .last 与行按钮区分)。
    await t.tap(find.text('确认收款').last);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // ---- UI 断言:期次状态变化(已收徽标 + 已确认行) ----
    expect(textContainingRich('已确认'), findsWidgets, reason: '首期行变为「已确认」');
    expect(find.text('已收'), findsWidgets, reason: '期次状态徽标「已收」');

    // ---- DS 断言(raw drift):期次持久化 + 复式余额联动 ----
    final after = await db.debtDao.getScheduleByDebt(debtId);
    final entry = after.firstWhere((e) => e.id == first.id);
    expect(entry.paid, isTrue, reason: '期次已收回持久化');
    expect(entry.paidCents, firstTotal, reason: '实收 = 期次总额');
    expect(entry.transactionId, isNotNull, reason: '期次关联交易 id 落位');
    // oracle:borrowedOut 收回 = debit 资金(+) / credit 应收(−)。
    expect(await balanceOf(db, fundsId), beforeFunds + firstTotal,
        reason: '收回入账:资金 +期次总额');
    expect(await balanceOf(db, recvId), beforeRecv - firstTotal,
        reason: '应收核销:应收 −期次总额');
  });
}
