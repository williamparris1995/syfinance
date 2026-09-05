/// F6 UI 链:预算页新建 + 消耗显示(ui_budget_page)。
///
/// 链路:① 预算管理 → 顶栏「新建预算」→ 表单(名称 + 分类账户 chip + 计划
/// 金额)→「保存预算」→ 列表出现新预算卡(剩余 ¥800.00);
/// ② DS 记一笔该分类支出(200.00)→ 全新 app 进入预算管理 → 卡片已用/进度
/// 显示变化(25% pill + 剩余 ¥600.00)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_budget_page_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
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
import 'package:yucai_client/core/localdb/app_database.dart' hide TransactionEntry;
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String fundsId; // UI算资金(DS 支出的资金腿,初始 2,000.00)
  late String catId; // UI算餐饮(expense 分类账户,预算行绑定它)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;分类/资金账户经 DS 铺,UI 只测预算交互。
    await resetTestDb();
    db = getIt<AppDatabase>();
    fundsId = await fundsAccount('UI算资金', 200000);
    final accounts = AccountLocalDataSource(db);
    final cat = await accounts.create(const CreateAccountParams(
      name: 'UI算餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    catId = cat.id;
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('算①新建预算:表单(chip 选分类 + 计划金额)→ 列表出现', (t) async {
    await pumpApp(t);
    await goPage(t, '预算管理');
    expect(find.text('预算管理'), findsWidgets, reason: '预算管理页地标');

    // 顶栏「新建预算」(app_shell 路由感知创建按钮,location==/budgets 才显)。
    final createBtn = find.text('新建预算');
    expect(createBtn.evaluate(), isNotEmpty, reason: '顶栏新建预算入口');
    await t.tap(createBtn.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('新建预算'), findsWidgets, reason: '预算表单页标题');

    // 名称(月份默认真实当月,与列表默认视图一致,无需改)。
    await t.enterText(find.byKey(const ValueKey('nameField')), 'UI算预算');
    await t.pumpAndSettle();

    // 预算条目:分类账户 chip(account-as-category:expense 账户即分类)。
    await t.ensureVisible(find.text('UI算餐饮'));
    await t.pumpAndSettle();
    await t.tap(find.text('UI算餐饮'));
    await t.pumpAndSettle();

    // 计划金额 800.00。
    await t.ensureVisible(find.byKey(const ValueKey('itemAmount-0')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('itemAmount-0')), '800');
    await t.pumpAndSettle();

    // 提交(topbar btn-gold;禁用态在字段补齐后自动解锁)。
    await t.ensureVisible(find.byKey(const ValueKey('budgetFormSubmit')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('budgetFormSubmit')));
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 列表出现(共享单例 BudgetBloc 创建成功即重拉,列表页在栈下自动刷新)。
    expect(find.text('UI算预算'), findsWidgets, reason: '新预算入列');
    expect(textContainingRich('剩余 ¥800.00'), findsWidgets,
        reason: '未消耗:剩余 = 计划 800.00');
  });

  testWidgets('算②消耗显示:DS 记支出 200 → 预算卡 25% + 剩余 ¥600.00', (t) async {
    // DS 记一笔该分类支出(月中日期,避开 UTC/本地月界窗口):
    // debit UI算餐饮 200.00 / credit UI算资金。
    final now = DateTime.now();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(now.year, now.month, 15),
      description: 'UI算支出',
      entries: [
        TransactionEntry(accountId: catId, debitCents: 20000, creditCents: 0),
        TransactionEntry(accountId: fundsId, debitCents: 0, creditCents: 20000),
      ],
    ));

    // 全新 app 进入预算管理(读时聚合 actual = max(Σdebit, Σcredit))。
    await pumpApp(t);
    await goPage(t, '预算管理');

    // oracle:200 / 800 = 25%(pill 整数百分比);剩余 800 − 200 = 600.00。
    expect(find.text('UI算预算'), findsWidgets, reason: '预算卡仍在列');
    expect(find.text('25%'), findsWidgets, reason: '已用 25% 进度 pill');
    expect(textContainingRich('剩余 ¥600.00'), findsWidgets,
        reason: '剩余 = 800.00 − 200.00');
  });
}
