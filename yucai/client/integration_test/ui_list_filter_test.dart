/// F6/F7 UI 链:交易页筛选器点选(ui_list_filter)。
///
/// 链路:DS 预置多笔已知交易(跨类型:支出/收入/转账;跨账户;跨月)→
/// 交易页筛选器点选:
///   ① 类型分段(全部/支出/转账)→ 列表按类型变化;
///   ② 月份下拉(切上月)→ 按月隔离;账户下拉(筛某账户)→ 按账户过滤;重置恢复;
///   ③ 搜索框(F7 FR-2,回车提交制)→ 只剩匹配;清除钮 → 恢复;
///   ④ 排序控件(F7 FR-3)切金额降序 → 金额序≠日期序;切回默认;
///   ⑤ 翻页(F7 FR-4)单页隐藏 → 批量 101 笔后真实翻页(下一页/页码/末页禁用)。
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

import 'package:flutter/material.dart'
    show IconButton, Text, TextField, TextInputAction;
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
    // 排序对照夹具(筛④):同月不同日,金额序与日期序刻意相反 ——
    //   甲 day 20(日期晚)金额小 2,000;乙 day 10(日期早)金额大 9,000。
    //   日期降序:甲先乙后;金额降序:乙先甲后(方向翻转)。同月不同日使两笔
    //   各占一个天分组,翻转不受 UI「按天归组」语义吞掉(列表按 MM-DD 归组,
    //   排序只决定分组首现序与组内序 —— 跨月对比会被归组重排,见筛④ oracle)。
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(now.year, now.month, 20),
      description: '筛UI排序甲',
      entries: [
        TransactionEntry(accountId: cat.id, debitCents: 2000, creditCents: 0),
        TransactionEntry(accountId: walletA, debitCents: 0, creditCents: 2000),
      ],
    ));
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(now.year, now.month, 10),
      description: '筛UI排序乙',
      entries: [
        TransactionEntry(accountId: cat.id, debitCents: 9000, creditCents: 0),
        TransactionEntry(accountId: walletA, debitCents: 0, creditCents: 9000),
      ],
    ));
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
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

  testWidgets('筛③搜索:回车提交过滤 + 清除钮恢复', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    // 基线:六笔夹具在列(rowsInOrder 按渲染顺序收集行描述,排序断言复用)。
    expect(rowsInOrder(t), hasLength(6), reason: '基线:六笔夹具在列');

    // 提交制(FR-2):输入不触发,回车/搜索动作键才离散提交(修复逐键提交的
    // 焦点丢失缺陷)。注意顶栏另有全局搜索框(hint「搜索交易、账户…」)→
    // 用筛选条专属 hint「搜索描述…」经 ancestor 精确定位。
    final searchField = find.ancestor(
        of: find.text('搜索描述…'), matching: find.byType(TextField));
    expect(searchField, findsOneWidget, reason: 'sanity:筛选条搜索框唯一可寻');
    await t.enterText(searchField, '筛UI支出');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump(const Duration(seconds: 1)); // 重载空窗愈合(照筛② flake 注)
    await t.pumpAndSettle(const Duration(seconds: 2));

    expect(rowsInOrder(t), ['筛UI支出'], reason: '搜索:只剩描述匹配的行');
    expect(textContainingRich('筛UI收入'), findsNothing, reason: '搜索:不匹配收入离列');
    expect(textContainingRich('筛UI上月'), findsNothing, reason: '搜索:不匹配上月离列');

    // 清除钮(suffix,提交空串)→ 全量恢复。
    final clearBtn = find.byTooltip('清除搜索');
    expect(clearBtn, findsOneWidget, reason: 'sanity:有词时清除钮出现');
    await t.ensureVisible(clearBtn);
    await t.pumpAndSettle();
    await t.tap(clearBtn);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(rowsInOrder(t), hasLength(6), reason: '清除:六笔全量恢复');
  });

  testWidgets('筛④排序:金额降序重排(金额序≠日期序)+ 切回默认', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    // 基线(默认日期降序):甲(20 日)先乙(10 日),上月笔(上月 15 日)最旧居末。
    // 金额口径 Σdebit oracle:收入 15,000 > 乙 9,000 > 支出 8,800 > 上月 6,600
    // > 转账 3,000 > 甲 2,000 → 金额降序下乙必翻到甲之前(金额序≠日期序)。
    // UI 语义注记:列表按天(MM-DD)归组渲染,排序决定分组首现序与组内序 ——
    // 跨月的转账/上月对比会被归组重排,故对照锚点用同月不同日的甲/乙。
    final before = rowsInOrder(t);
    expect(before, hasLength(6));
    expect(before.first, '筛UI排序甲', reason: '默认日期降序:甲(20 日)居首');
    expect(before.indexOf('筛UI排序甲') < before.indexOf('筛UI排序乙'), isTrue,
        reason: '默认:日期晚的甲在日期早的乙之前');
    expect(before.last, '筛UI上月', reason: '默认日期降序:上月笔(最旧)居末');

    // 点排序控件(显示当前态文案)弹四态菜单 → 选金额降序。
    await t.ensureVisible(find.text('日期降序'));
    await t.pumpAndSettle();
    await t.tap(find.text('日期降序'));
    await t.pumpAndSettle();
    await t.tap(find.text('金额降序').last); // .last = 弹层菜单项(按钮态是日期降序)
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 金额降序渲染序 oracle:平铺金额序 = 收入(09-15)/乙(09-10)/支出(09-15)/
    // 上月(08-15)/转账(09-15)/甲(09-20),按天归组(组按首现)后渲染:
    //   09-15 组[收入,支出,转账] → 09-10 组[乙] → 08-15 组[上月] → 09-20 组[甲]。
    expect(
        rowsInOrder(t),
        [
          '筛UI收入', '筛UI支出', '筛UI转账', '筛UI排序乙', '筛UI上月', '筛UI排序甲'
        ],
        reason: '金额降序:乙(9,000)翻到甲(2,000)之前;天分组按首现重排');
    expect(
        rowsInOrder(t).indexOf('筛UI排序乙') <
            rowsInOrder(t).indexOf('筛UI排序甲'),
        isTrue,
        reason: '金额降序:与默认日期序方向翻转');

    // 切回默认(日期降序):甲回到首位、上月回到末位。
    await t.ensureVisible(find.text('金额降序'));
    await t.pumpAndSettle();
    await t.tap(find.text('金额降序'));
    await t.pumpAndSettle();
    await t.tap(find.text('日期降序').last); // 按钮同名,.last 取菜单项
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 2));
    final after = rowsInOrder(t);
    expect(after.first, '筛UI排序甲', reason: '切回默认:甲回到首位(日期降序)');
    expect(after.last, '筛UI上月', reason: '切回默认:上月笔回到末位');
    expect(after.indexOf('筛UI排序甲') < after.indexOf('筛UI排序乙'), isTrue,
        reason: '切回默认:甲重新在乙之前');
  });

  testWidgets('筛⑤翻页:单页分页条隐藏 → 101 笔真实翻页(下一页/页码/末页禁用)',
      (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    // ① 单页(既有夹具+demo ≪ DS 默认 pageSize 100)且第 1 页 → 分页条整体
    // 隐藏(FR-4 单页隐藏语义;bloc/widget 翻页状态机已有单测兜底)。
    expect(find.text('第 1 页'), findsNothing, reason: '单页:页码指示隐藏');
    expect(find.byTooltip('上一页'), findsNothing, reason: '单页:上一页按钮隐藏');
    expect(find.byTooltip('下一页'), findsNothing, reason: '单页:下一页按钮隐藏');
    expect(find.textContaining('本页'), findsNothing, reason: '单页:页脚整体隐藏');

    // ② 批量建 101 笔(取舍说明:UI 不暴露 pageSize 改小入口,真实翻页需 >100
    // 条;每笔一次本地 DS recordTransaction(2 分录,轻),101 次秒级可行 →
    // 选真实点按断言而非仅隐藏断言)。全部 2026-12-15(未来月,日期降序恒居
    // demo/既有夹具之前 → 第 1 页全为翻页夹具,断言确定)。
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final pagerWallet = await fundsAccount('筛UI翻钱包', 1000000);
    final pagerSource = await fundsAccount('筛UI翻来源', 0);
    for (var i = 0; i < 101; i++) {
      await txns.recordTransaction(RecordTransactionParams(
        transactionDate: DateTime(2026, 12, 15),
        description: '筛UI翻${(i + 1).toString().padLeft(3, '0')}',
        entries: [
          TransactionEntry(
              accountId: pagerWallet, debitCents: 10000, creditCents: 0),
          TransactionEntry(
              accountId: pagerSource, debitCents: 0, creditCents: 10000),
        ],
      ));
    }

    // 触发重载回第 1 页:点类型分段(筛选变化重置第 1 页,FR-4;翻页夹具均为
    // 2 笔平衡 → 粗分类 transfer,与筛①口径一致)。
    await t.tap(find.text('转账'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 3));

    // 第 1 页:恰 100 行翻页夹具 + 分页条出现;上一页禁用、下一页可用。
    expect(pagerRows(t), 100,
        reason: '页 1:pageSize 100 全为 2026-12 翻页夹具(日期降序居前)');
    expect(find.text('第 1 页'), findsWidgets, reason: '多页:页码指示出现');
    expect(find.text('本页 100 条'), findsWidgets, reason: '页 1:本页计数 100');
    expect(pagerBtnEnabled(t, '上一页'), isFalse, reason: '第 1 页:上一页禁用');
    expect(pagerBtnEnabled(t, '下一页'), isTrue, reason: '第 1 页:下一页可用');

    // 下一页 → 第 2 页:仅剩 1 笔翻页夹具(101 = 100+1)+ 旧夹具回列;末页
    // 下一页禁用、上一页可用。
    await t.ensureVisible(find.byTooltip('下一页'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('下一页'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('第 2 页'), findsWidgets, reason: '翻页:页码指示更新');
    expect(pagerRows(t), 1, reason: '页 2:仅剩第 101 笔翻页夹具');
    expect(textContainingRich('筛UI支出'), findsWidgets,
        reason: '页 2:旧夹具回列(翻页换页不丢数据)');
    expect(pagerBtnEnabled(t, '下一页'), isFalse, reason: '末页:下一页禁用');
    expect(pagerBtnEnabled(t, '上一页'), isTrue, reason: '第 2 页:上一页可用');

    // 上一页 → 回第 1 页。
    await t.ensureVisible(find.byTooltip('上一页'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('上一页'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('第 1 页'), findsWidgets, reason: '回翻:页码回第 1 页');
    expect(pagerRows(t), 100, reason: '回翻:第 1 页 100 行恢复');
  });
}

/// 分页按钮可用性:经 tooltip 定位(本版 IconButton 内嵌 RawTooltip,byTooltip
/// 命中的是 Tooltip 而非按钮本体)→ 取其祖先 IconButton 的 onPressed
/// (null = 禁用态:第 1 页禁上一页/末页禁下一页/翻页中双禁)。
bool pagerBtnEnabled(WidgetTester t, String tooltip) =>
    t
        .widget<IconButton>(find.ancestor(
            of: find.byTooltip(tooltip), matching: find.byType(IconButton)))
        .onPressed !=
    null;

/// 翻页夹具行数:描述全匹配 ^筛UI翻\d{3}$ 计数。子串匹配会误计同前缀的
/// 账户名(筛UI翻钱包/筛UI翻来源 出现在转账行账户列与副标题),故用正则
/// 只数行描述本体(每行恰 1 个 Text)。
int pagerRows(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        if (w.data != null && RegExp(r'^筛UI翻\d{3}$').hasMatch(w.data!)) 1
    ].length;

/// 按渲染顺序收集交易列表行描述(仅「筛UI*」已知夹具行;排除同前缀的
/// 账户下拉选项/分类 chip 文案 —— 白名单取行描述精确串)。
/// 排序断言需全序而非集合,故逐 Text 遍历(Element 树序 = 视觉行序)。
List<String> rowsInOrder(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        if (w.data != null &&
            {
              '筛UI支出', '筛UI收入', '筛UI转账', '筛UI上月', '筛UI排序甲', '筛UI排序乙'
            }.contains(w.data))
          w.data!,
    ];
