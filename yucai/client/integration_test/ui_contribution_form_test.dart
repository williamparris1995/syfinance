/// F6 UI 链:目标注资交互(ui_contribution_form)。
///
/// 链路:DS 预置无链储蓄目标(10,000.00)→ 目标追踪 → 卡片点入目标详情 →
/// 底栏「记一笔贡献」→ dialog 输金额(2,500.00)→「记一笔」提交 → 断言:
///   ① 进度 UI 变化(进度环 0.0% → 25.0%,当前/目标 出现 ¥2,500.00);
///   ② DS 侧 currentAmount 存储列 +250,000 分(无链目标注资不动任何账户,
///      FR-6 语义;raw drift 独立读)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_contribution_form_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter/material.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String goalId; // UI攒目标(无链储蓄目标,10,000.00)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;目标经 DS 铺,UI 只测注资交互。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final goals = GoalLocalDataSource(db, HoldingLocalDataSource(db, txns));

    // ---- 自包含夹具(UI攒* 前缀,与演示数据零耦合) ----
    // 无链(不挂账户/债务):recordContribution 只加存储列,读数即注资结果。
    goalId = (await goals.createGoal(
      name: 'UI攒目标',
      type: GoalType.savings,
      targetAmountCents: 1000000, // 10,000.00
    ))
        .id;
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('注①目标注资:记一笔贡献 → 进度环 25.0% + 存储列落位', (t) async {
    await pumpApp(t);
    await goPage(t, '目标追踪');

    // 目标卡点入详情(卡片 tap → push /goals/:id)。
    final card = find.text('UI攒目标');
    expect(card.evaluate(), isNotEmpty, reason: '预置目标在列');
    await t.tap(card.first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('目标详情'), findsWidgets, reason: '目标详情页地标');
    // 基线:进度 0.0%,当前/目标 ¥0.00 / ¥10,000.00。
    expect(textContainingRich('0.0%'), findsWidgets, reason: '注资前进度 0.0%');

    // 底栏「记一笔贡献」→ dialog 输入金额(元)。
    await t.ensureVisible(find.byKey(const ValueKey('goalContributeBtn')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('goalContributeBtn')));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('记一笔贡献'), findsWidgets, reason: '注资 dialog 标题');

    await t.enterText(find.byKey(const ValueKey('goalContributionInput')), '2500');
    await t.tap(find.byKey(const ValueKey('goalContributionSubmit')));
    await t.pumpAndSettle(const Duration(seconds: 2));

    // ---- UI 断言:进度变化(2,500 / 10,000 = 25.0%) ----
    expect(textContainingRich('25.0%'), findsWidgets, reason: '进度环翻至 25.0%');
    expect(textContainingRich('2,500.00'), findsWidgets,
        reason: '当前/目标显示 ¥2,500.00');

    // ---- DS 断言(raw drift):存储列 +250,000 分 ----
    final row = await (db.select(db.goals)
          ..where((g) => g.id.equals(goalId)))
        .getSingle();
    expect(row.currentAmountCents, 250000, reason: 'currentAmount = 2,500.00');
    expect(row.targetAmountCents, 1000000, reason: 'target 不变');
  });
}
