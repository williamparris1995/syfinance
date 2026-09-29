/// 反馈1a E2E 回归:页身 SelectionArea scope(CurrentRouteSelectionArea)
/// 的**鼠标拖选**在真实 app 两处展示面上的行为 —— ①财务报告正文
/// (报告体 plain Text 区)②交易记录行内描述文本。
///
/// 与 app_chrome_test 的差异:那边只验 chrome 契约与交互不干扰;
/// transactions_page_test 的 widget 拖选虽走完整手势竞技场,但宿主是
/// 测试 harness。本链 pump 真 app(真 DI/真路由/真窗口)用 TestGesture
/// 真实按下-拖动-抬起序列(鼠标),断言 SelectableRegionState 选区几何
/// 非空 —— 拖选链路(arena → TapAndPan → edge update)真实工作。
///
/// 历史:反馈⑥ 全局 scope 时代本链两端点恒 0(复现用户「真机拖选完全
/// 无效」);修复(scope 下沉页面体)后两端点恒 2。
///
/// 夹具:resetTestDb 幂等演示种子 + 一笔唯一描述流水(「拖选诊断样本
/// 流水」,当前月,null 月过滤缺省全量可见);报告面走真实生成流(当前
/// 月 demo 数据,章节标题「资产负债」为报告体 plain Text)。用户真实库
/// (yucai.db)不触碰。桌面窗口 1440x900(≥1100 → desktop 分支形态)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑有设备启动竞争)。
/// 运行:`flutter test integration_test/text_selection_drag_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    hide TransactionEntry;
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    await resetTestDb();
    // 唯一描述流水(当月,任何缺省过滤可见):拖选目标 ②。
    final db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final accounts = AccountLocalDataSource(db);
    final expenseId = (await accounts.create(CreateAccountParams(
      name: '拖选诊断支出',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    )))
        .id;
    final fundsId = await fundsAccount('拖选诊断资金', 50000);
    final now = DateTime.now().toUtc();
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(now.year, now.month, 15, 12),
      description: '拖选诊断样本流水',
      entries: [
        TransactionEntry(
            accountId: expenseId, debitCents: 4200, creditCents: 0),
        TransactionEntry(
            accountId: fundsId, debitCents: 0, creditCents: 4200),
      ],
    ));
  });
  tearDownAll(deleteTestDb);

  /// 真实鼠标拖选:press 于目标中心 → 右移(超 slop)→ release,
  /// 经完整手势竞技场(与真机同链路)。返回选区端点数(2 = 有效拖选)。
  Future<int> dragSelectAlongText(WidgetTester t, Finder text) async {
    final region = t.state<SelectableRegionState>(
        find.byType(SelectableRegion).first);
    final center = t.getCenter(text);
    final gesture = await t.startGesture(center.translate(-6, 0),
        kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 100));
    // 分步拖:小步滞留文本内(章节标题 ~68px 宽;跨出 selectable 的
    // 位置路由是 #153004 家族另一毒面,拖出文本边界即清选)。
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(6, 0));
      await t.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await t.pump(const Duration(milliseconds: 200));
    // 选区可能为空(真实拖选失败时):selectionEndpoints 会在 null 端点上
    // 崩溃 —— 以 context menu 是否出现 Copy 项(有选中内容才备)判存。
    final hasSelection = region.contextMenuButtonItems
        .any((i) => i.type == ContextMenuButtonType.copy);
    return hasSelection ? region.selectionEndpoints.length : 0;
  }




  testWidgets('诊断①:报告正文 plain Text 鼠标拖选 → 选区非空', (t) async {
    // 真机桌面形态(≥1100 宽 → AppShell desktop 分支;缺省 800x600 是
    // mobile 形态,与用户反馈场景不符)。
    t.view.physicalSize = const Size(2880, 1800); // logical 1440x900 @2x
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
    await goPage(t, '报表分析');
    await t.pumpAndSettle(const Duration(seconds: 2));
    await t.tap(find.byKey(const ValueKey('financialReportEntryButton')));
    await t.pumpAndSettle(const Duration(seconds: 2));
    await t.tap(find.text('生成报告').first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    // 报告体 plain Text:固定章节标题(生成后必在,不依赖数值 oracle)。
    // 章节头 + 右缘锚点标签同名两处,取树序首个(章节头)。
    final chapter = find.text('资产负债').first;
    expect(chapter.evaluate(), isNotEmpty, reason: '报告已生成,章节在列');
    // 章节二在首屏之下:滚到可见再拖(getCenter 对离屏文本给出窗外坐标,
    // 指针事件不进 hit-test)。
    await t.ensureVisible(chapter);
    await t.pumpAndSettle(const Duration(milliseconds: 600));

    final endpoints = await dragSelectAlongText(t, chapter);
    expect(endpoints, 2,
        reason: '拖选后选区端点应为 2(start/end);实际 $endpoints —— '
            '真机拖选无效若在此复现,选区手势链路被劫持/未达注册器');
  });

  testWidgets('诊断②:交易记录行内描述鼠标拖选 → 选区非空', (t) async {
    t.view.physicalSize = const Size(2880, 1800); // logical 1440x900 @2x
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
    await goPage(t, '交易记录');
    await t.pumpAndSettle(const Duration(seconds: 2));
    final row = find.text('拖选诊断样本流水');
    expect(row.evaluate(), isNotEmpty, reason: '夹具流水行在列');
    // SelectionArea(AppChrome)确为行文本祖先(层级自查清单 a)。
    expect(
      find.descendant(of: find.byType(SelectionArea), matching: row),
      findsOneWidget,
      reason: '行文本应落在全局 SelectionArea 内',
    );

    final endpoints = await dragSelectAlongText(t, row);
    expect(endpoints, 2,
        reason: '拖选后选区端点应为 2;实际 $endpoints —— 行内手势(InkWell/'
            '滚动)应不抢鼠标 drag,选区链路应胜出竞技场');
  });
}
