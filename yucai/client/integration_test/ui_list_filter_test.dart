/// F6 UI 链:交易页筛选器点选(ui_list_filter)。
///
/// 链路:DS 预置多笔已知交易(跨类型:支出/收入/转账;跨账户;跨月)→
/// 交易页筛选器点选:
///   ① 类型分段(全部/支出/转账)→ 列表按类型变化;
///   ② 月份下拉(切上月)→ 按月隔离;账户下拉(筛某账户)→ 按账户过滤;重置恢复。
/// 断言用夹具独有描述串匹配(「筛UI*」前缀,与演示数据零耦合)。
///
/// ⚠️ 语义出入(以代码为准,记报告不修生产):类型分段经本地 DS 的
/// inferFlavour **粗分类** —— 恰 2 笔平衡分录一律归「转账」(收支不分,
/// link_mutation_cascade 已钉死该口径)→ 本地模式下「支出/收入」分段筛出
/// 空列表(空态「本月暂无交易」),「转账」分段反而含全部收支夹具;UI 行
/// 图标/配色用的是账户类型精确判定,与筛选口径不一致。生产缺口记录:
/// typeFilter 未按账户类型细分。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_list_filter_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter/material.dart' show Scrollable;
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
  late String walletA; // 筛UI钱包A(支出/收入/转账均涉及)
  late String walletB; // 筛UI钱包B(仅转账借方)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;跨类型/跨月夹具经 DS 铺。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final accounts = AccountLocalDataSource(db);

    // ---- 自包含夹具(筛UI* 前缀) ----
    walletA = await fundsAccount('筛UI钱包A', 100000);
    walletB = await fundsAccount('筛UI钱包B', 50000);
    final cat = await accounts.create(const CreateAccountParams(
      name: '筛UI餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    final incomeCat = await accounts.create(const CreateAccountParams(
      name: '筛UI进账',
      accountType: AccountType.income,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));

    final now = DateTime.now();
    // 记一笔的复式配对照 demo_seed(支出=借分类/贷资金;收入=借资金/贷收入)。
    // 日期取月中避月界;「筛UI上月」取上月 15 日(跨月夹具)。
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(now.year, now.month, 15),
      description: '筛UI支出',
      entries: [
        TransactionEntry(accountId: cat.id, debitCents: 8800, creditCents: 0),
        TransactionEntry(accountId: walletA, debitCents: 0, creditCents: 8800),
      ],
    ));
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(now.year, now.month, 15),
      description: '筛UI收入',
      entries: [
        TransactionEntry(accountId: walletA, debitCents: 15000, creditCents: 0),
        TransactionEntry(accountId: incomeCat.id, debitCents: 0, creditCents: 15000),
      ],
    ));
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(now.year, now.month, 15),
      description: '筛UI转账',
      entries: [
        TransactionEntry(accountId: walletB, debitCents: 3000, creditCents: 0),
        TransactionEntry(accountId: walletA, debitCents: 0, creditCents: 3000),
      ],
    ));
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(now.year, now.month - 1, 15),
      description: '筛UI上月',
      entries: [
        TransactionEntry(accountId: cat.id, debitCents: 6600, creditCents: 0),
        TransactionEntry(accountId: walletA, debitCents: 0, creditCents: 6600),
      ],
    ));
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

  testWidgets('筛①类型分段:粗分类口径照实断言(转账=2笔平衡,支出筛空)', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    // 基线:四笔夹具全部在列(默认无筛选;列表为 Column 内全量渲染,
    // 视口外的行也已 build,finder 可见)。
    expect(textContainingRich('筛UI支出'), findsWidgets, reason: '基线:支出在列');
    expect(textContainingRich('筛UI收入'), findsWidgets, reason: '基线:收入在列');
    expect(textContainingRich('筛UI转账'), findsWidgets, reason: '基线:转账在列');
    expect(textContainingRich('筛UI上月'), findsWidgets, reason: '基线:上月支出在列');

    // 转账分段:本地 DS 粗分类 = 恰 2 笔平衡分录 → 三笔本月夹具(含收支)全中。
    await t.tap(find.text('转账'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(textContainingRich('筛UI转账'), findsWidgets, reason: '转账筛选:转账在列');
    expect(textContainingRich('筛UI支出'), findsWidgets,
        reason: '转账筛选:粗分类把 2 笔平衡收支也归 transfer(照实钉死)');

    // 支出分段:粗分类无 expense 口味 → 空列表(空态提示;生产缺口见文件头)。
    await t.tap(find.text('支出'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(textContainingRich('筛UI支出'), findsNothing, reason: '支出筛选:收支不分(粗分类缺口)');
    expect(find.text('本月暂无交易'), findsWidgets, reason: '支出筛选:空态提示');

    // 全部 → 恢复。
    await t.tap(find.text('全部'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(textContainingRich('筛UI支出'), findsWidgets, reason: '全部恢复:支出回列');
    expect(textContainingRich('筛UI转账'), findsWidgets, reason: '全部恢复:转账回列');
  });

  testWidgets('筛②月份/账户下拉:切月隔离 + 按账户过滤 + 重置', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    // 月份下拉:点关闭态显示值「全部月份」展开菜单,选上月(label = YYYY年M月,无补零)。
    final lastMonth = DateTime.now().month == 1
        ? DateTime(DateTime.now().year - 1, 12)
        : DateTime(DateTime.now().year, DateTime.now().month - 1);
    final lastMonthLabel = '${lastMonth.year}年${lastMonth.month}月';

    await t.tap(find.text('全部月份'));
    await t.pumpAndSettle();
    await t.tap(find.text(lastMonthLabel).last);
    await t.pumpAndSettle(const Duration(seconds: 2));

    expect(textContainingRich('筛UI上月'), findsWidgets, reason: '上月筛选:上月支出在列');
    expect(textContainingRich('筛UI支出'), findsNothing, reason: '上月筛选:本月支出离列');
    expect(textContainingRich('筛UI转账'), findsNothing, reason: '上月筛选:本月转账离列');

    // 重置回全量,再独立验证账户下拉(不与月份叠加)。
    // flake 缓解:选账户后页面经 Loading→Loaded 重挂,账户下拉的选项来自
    // build 内新建的 FutureBuilder future —— 重挂后 options 有一个异步空窗,
    // DropdownButtonFormField(value≠null, items 空)会瞬时断言闪崩(ErrorWidget
    // 占位),账户 future 完成后自愈(生产缺口记报告)。给足真实时间让其愈合
    // 再做后续交互/断言。
    await t.ensureVisible(find.text('重置'));
    await t.pumpAndSettle();
    await t.tap(find.text('重置'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(textContainingRich('筛UI支出'), findsWidgets, reason: '重置后:本月支出回列');

    // 账户下拉:筛UI钱包B → 仅剩涉 B 的转账(其余夹具只涉 A)。
    await t.ensureVisible(find.text('全部账户'));
    await t.pumpAndSettle();
    await t.tap(find.text('全部账户'));
    await t.pumpAndSettle();
    await t.tap(find.text('筛UI钱包B').last);
    await t.pump(const Duration(seconds: 1)); // 空窗愈合(见上 flake 注)
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(textContainingRich('筛UI转账'), findsWidgets, reason: '账户筛选:涉B转账在列');
    expect(textContainingRich('筛UI支出'), findsNothing, reason: '账户筛选:不涉B支出离列');
    expect(textContainingRich('筛UI上月'), findsNothing, reason: '账户筛选:不涉B上月离列');

    // 重置 → 全部恢复(夹具四笔回列)。
    await t.ensureVisible(find.text('重置'));
    await t.pumpAndSettle();
    await t.tap(find.text('重置'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(textContainingRich('筛UI支出'), findsWidgets, reason: '重置:支出回列');
    expect(textContainingRich('筛UI收入'), findsWidgets, reason: '重置:收入回列');
    expect(textContainingRich('筛UI转账'), findsWidgets, reason: '重置:转账回列');
    expect(textContainingRich('筛UI上月'), findsWidgets, reason: '重置:上月支出回列');
  });
}
