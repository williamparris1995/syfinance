/// F9 FR-6 UI 链 E2E:三模块列表能力页面级抽验(ui_list_unify)。
///
/// 链路:DS 预置自包含夹具(统UI* 前缀,与演示数据零耦合)→ 页面交互点验:
///   统UI① 账户详情:近期交易区(FR-2)—— 101 笔夹具真分页(第 1 页 100 行/
///       末页 1 行/按钮禁用态)+ 搜索收窄(命中 2 笔 → 单页分页条隐藏)+ 清除恢复;
///   统UI② 持仓页(FR-3)—— 搜索收窄(symbol 忽略大小写 / name)+ 单页分页条
///       隐藏(夹具+demo 共 4 只 < 20/页,取舍见用例注释);
///   统UI③ 债务页(FR-4)—— 默认序(到期升序)→ 切金额降序(顺序翻转)+ 搜索收窄;
///   统UI④ 账户管理页(FR-5)—— 搜索收窄(账户名)+ 清除恢复。
/// R8 F8 FR-5 尾追加标签维度三链(标维* 前缀夹具,guest 模式 —— 测试无绑定,
/// tagFilterAvailable 恒可用,标签控件全量挂载):
///   统UI⑤ 标签页跳转(FR-3):设置›标签管理 → 点「标维重点」标签卡 → push
///       /transactions(extra tagId)→ 列表只剩挂该标签的 3 笔(跳转+筛选端到端);
///   统UI⑥ 交易列表标签下拉(FR-2):全部→标维重点(3 笔)→标维次要(1 笔)
///       →全部标签恢复(下拉切换列表变化);
///   统UI⑦ 报表页标签口径(FR-4):锚月(运行当月)汇总条四数字 oracle ——
///       未选(全部)含 demo 口径 / 选「标维重点」只剩挂标签 3 笔 / 选「标维次要」
///       只剩 1 笔 / 切回全部恢复。
///
/// 断言用夹具独有串匹配;排序断言用「统UI 前缀守卫」(demo 数据混排不污染
/// 相对序 oracle,照 link_mutation_cascade 的前缀守卫模式)。
///
/// 两个 Windows 嵌入层实测坑(探针钉死,照实绕行):
///   1. 账户详情 body 是懒构建 ListView:近期交易面板在首屏之下,断言前需
///      scrollUntilVisible 滚入视野(面板作为单一 child,一旦入视 100 行全量 build);
///   2. 提交制搜索框的「第二次」输入:点过清除钮/其他控件后焦点离开输入框,
///      直接 enterText 不重挂输入 client(文本丢失、onSubmitted 不触发)——
///      先 tap 搜索框再输入(真实用户点回输入框的路径)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_list_unify_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口,F9-T4 尾追加进 E2E_UI_FILES。)
library;

import 'package:flutter/material.dart'
    show IconButton, Scrollable, Text, TextField, TextInputAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide TransactionEntry;
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String detailWalletId; // 统UI钱包(账户详情近期交易夹具账户,101 笔)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;各页夹具经 DS 铺。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final accounts = AccountLocalDataSource(db);
    final holdings = HoldingLocalDataSource(db, txns);
    final debts =
        DebtLocalDataSource(db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)));

    // ---- 统UI① 账户详情夹具:统UI钱包 + 101 笔(每笔 ¥100,借钱包/贷分类) ----
    // 日期逐笔递增(2026-01-01 + i 天):默认日期降序下 统UI翻101(2026-04-11)
    // 恒居首、统UI翻001(2026-01-01)恒居末 → 第 2 页唯一行 = 统UI翻001,
    // 断言确定(同日 tie 会落 id 序,uuid 不可预测,故逐笔不同日)。
    detailWalletId = await fundsAccount('统UI钱包', 1000000); // ¥10,000
    final expenseCat = await accounts.create(const CreateAccountParams(
      name: '统UI翻分类',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    for (var i = 1; i <= 101; i++) {
      await txns.recordTransaction(RecordTransactionParams(
        transactionDate: DateTime.utc(2026, 1, 1).add(Duration(days: i - 1)),
        description: '统UI翻${i.toString().padLeft(3, '0')}',
        entries: [
          TransactionEntry(
              accountId: detailWalletId, debitCents: 10000, creditCents: 0),
          TransactionEntry(
              accountId: expenseCat.id, debitCents: 0, creditCents: 10000),
        ],
      ));
    }

    // ---- 统UI② 持仓夹具:统UI证券账户 + 3 只(市值无现价 = qty×price) ----
    //   F9uiOne/统UI一号   10×10,000 = 100,000 分
    //   F9uiTwo/统UI二号   20× 8,000 = 160,000 分
    //   F9uiThree/统UI三号 30× 5,000 = 150,000 分
    // 持仓页全集 = demo 茅台(1,100,000 分)+ 3 只 = 4 只 < 20/页 → 单页分页条隐藏。
    final investFunds = await fundsAccount('统UI投资资金', 1000000); // ¥10,000
    final invest = await accounts.create(const CreateAccountParams(
      name: '统UI证券账户',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    Future<void> buyOne(String symbol, String name, double qty, int price) async {
      final sec = await holdings.createSecurity(
        symbol: symbol,
        name: name,
        type: SecurityType.fund,
        exchange: 'CN',
        currency: 'CNY',
      );
      await holdings.buy(
        accountId: invest.id,
        securityId: sec.id,
        fromAccountId: investFunds,
        quantity: qty,
        priceCents: price,
        tradeDate: '2026-08-20',
      );
    }

    await buyOne('F9uiOne', '统UI一号', 10, 10000);
    await buyOne('F9uiTwo', '统UI二号', 20, 8000);
    await buyOne('F9uiThree', '统UI三号', 30, 5000);

    // ---- 统UI③ 债务夹具:4 笔借入(lumpSum 无还款 → 全部未结清,默认
    // 「进行中」分段可见;金额/到期刻意反相关 → 两序对照必翻转) ----
    //   统UI债甲 500,000 分 due 2027-03-01
    //   统UI债乙 900,000 分 due 2026-12-01
    //   统UI债丙 300,000 分 due 2027-06-01
    //   统UI债丁 700,000 分 due 2026-10-01
    final loanAcc = await accounts.create(const CreateAccountParams(
      name: '统UI负债账户',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    Future<void> createDebt(String counterparty, int principal, DateTime due) async {
      await debts.create(
        accountId: loanAcc.id,
        counterparty: counterparty,
        interestRate: 0,
        amortizationIndex: 2, // lumpSum
        startDate: DateTime.utc(2026, 9, 1),
        dueDate: due,
        totalPrincipalCents: principal,
        type: DebtType.borrowedIn,
      );
    }

    await createDebt('统UI债甲', 500000, DateTime.utc(2027, 3, 1));
    await createDebt('统UI债乙', 900000, DateTime.utc(2026, 12, 1));
    await createDebt('统UI债丙', 300000, DateTime.utc(2027, 6, 1));
    await createDebt('统UI债丁', 700000, DateTime.utc(2026, 10, 1));

    // ---- 统UI⑤⑥⑦(F8 FR-5 标签维度)夹具:标维* 前缀 + 当月 4 笔 + 2 标签 ----
    // 当月月中(10/12/20 日)避开月界;标签挂载经 TagLocalDataSource 真管道。
    //   u1 标维支出甲  expense  12,000(当月 10 日)挂「标维重点」
    //   u2 标维支出乙  expense  34,500(当月 20 日)挂「标维重点」
    //   u3 标维收入丙  income  500,000(当月 20 日)挂「标维重点」
    //   u4 标维支出丁  expense   7,700(当月 12 日)挂「标维次要」
    // 报表页(锚月=运行当月,scope month)汇总条 oracle(统UI⑦,demo 口径在内):
    //   未选(全部):income = demo 工资 800,000 + 丙 500,000 = 1,300,000;
    //                expense = demo 午餐 5,000 + 甲 12,000 + 乙 34,500 + 丁 7,700 = 59,200
    //                (净额/日均依赖运行日与月初/今日的活跃日并集 → 只断收入/支出)。
    //   选「标维重点」:income 500,000 / expense 46,500 / net 453,500;
    //                活跃日 {10, 20} → 日均 453,500 ~/ 2 = 226,750。
    //   选「标维次要」:income 0 / expense 7,700 / net −7,700;
    //                单活跃日 {12} → 日均 = 净额 −7,700。
    final dimTags = TagLocalDataSource(db);
    final tagFocus = await dimTags.create(name: '标维重点', color: '#6A1B9A');
    final tagSide = await dimTags.create(name: '标维次要', color: '#00695C');
    final dimFunds = await fundsAccount('标维钱包', 200000);
    final dimDining = await accounts.create(const CreateAccountParams(
      name: '标维餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    final dimIncomeCat = await accounts.create(const CreateAccountParams(
      name: '标维进账',
      accountType: AccountType.income,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    final dimNow = DateTime.now();
    // 借记分类/贷记资金(配对复式,照 demo_seed);返回交易 id 供挂标签。
    Future<String> dimExpense(int day, String desc, int cents) async =>
        (await txns.recordTransaction(RecordTransactionParams(
          transactionDate: DateTime(dimNow.year, dimNow.month, day),
          description: desc,
          entries: [
            TransactionEntry(
                accountId: dimDining.id, debitCents: cents, creditCents: 0),
            TransactionEntry(
                accountId: dimFunds, debitCents: 0, creditCents: cents),
          ],
        )))
            .id;
    final u1Id = await dimExpense(10, '标维支出甲', 12000);
    final u2Id = await dimExpense(20, '标维支出乙', 34500);
    final u4Id = await dimExpense(12, '标维支出丁', 7700);
    final u3Id = (await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime(dimNow.year, dimNow.month, 20),
      description: '标维收入丙',
      entries: [
        TransactionEntry(
            accountId: dimFunds, debitCents: 500000, creditCents: 0),
        TransactionEntry(
            accountId: dimIncomeCat.id, debitCents: 0, creditCents: 500000),
      ],
    )))
        .id;
    for (final id in [u1Id, u2Id, u3Id]) {
      await dimTags.addTagToTransaction(tagId: tagFocus.id, transactionId: id);
    }
    await dimTags.addTagToTransaction(tagId: tagSide.id, transactionId: u4Id);
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

  // 提交制搜索 helper(照 ui_list_filter 筛③的输入+回车提交;先 tap 回输入框
  // 再输入 —— 见文件头坑 2:点过其他控件后 enterText 不重挂输入 client)。
  Future<void> commitSearch(WidgetTester t, Finder field, String text) async {
    await t.ensureVisible(field);
    await t.pumpAndSettle();
    await t.tap(field);
    await t.pumpAndSettle();
    await t.enterText(field, text);
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump(const Duration(seconds: 1)); // 重载空窗愈合(照筛② flake 注)
    await t.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('统UI①账户详情近期交易:默认可见 + 真翻页(100+1)+ 搜索收窄单页隐藏',
      (t) async {
    await pumpApp(t);
    await goPage(t, '账户管理');

    // 进统UI钱包详情(brief 口径「第一张卡详情」:取统UI夹具账户卡 —— 101 笔
    // 夹具全落在本账户,页 1/页 2 行数 oracle 恰为 100/1,demo 零混入)。
    final card = find.text('统UI钱包');
    expect(card, findsWidgets, reason: 'sanity:统UI钱包卡在列');
    await t.ensureVisible(card.first);
    await t.pumpAndSettle();
    await t.tap(card.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('账户详情'), findsWidgets, reason: 'sanity:已进入详情页');

    // 滚到近期交易区(详情 body 为懒构建 ListView,面板在首屏 hero/统计行之下;
    // Scrollable.last = body 列表 —— 嵌套 GridView 均为 NeverScrollable,拖拽
    // 手势落回外层,探针实测可达)。
    await t.scrollUntilVisible(
      find.text('近期交易'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pumpAndSettle();

    // ---- 默认近期交易可见(FR-2/NFR-2 首屏语义):第 1 页 100 行 ----
    expect(find.text('近期交易'), findsOneWidget, reason: '近期交易区存在');
    expect(find.text('本页 100 笔'), findsOneWidget,
        reason: '默认:本页计数 100(pageSize 100)');
    expect(detailRowsInOrder(t), hasLength(100), reason: '默认:第 1 页 100 行夹具');
    expect(detailRowsInOrder(t).first, '统UI翻101',
        reason: '默认日期降序:最晚(2026-04-11)居首');
    expect(find.text('第 1 页'), findsOneWidget, reason: '多页:页码指示出现');
    expect(pagerBtnEnabled(t, '上一页'), isFalse, reason: '第 1 页:上一页禁用');
    expect(pagerBtnEnabled(t, '下一页'), isTrue, reason: '第 1 页:下一页可用');

    // ---- 搜索收窄:命中 统UI翻100/统UI翻101 两笔 → 单页分页条隐藏 ----
    // (放翻页前做:搜索字段在面板顶部,此刻在视野内;翻页后会滚到面板底部。)
    final searchField = find.ancestor(
        of: find.text('搜索描述…'), matching: find.byType(TextField));
    expect(searchField, findsOneWidget, reason: 'sanity:近期交易搜索框唯一可寻');
    await commitSearch(t, searchField, '统UI翻10');
    expect(detailRowsInOrder(t), ['统UI翻101', '统UI翻100'],
        reason: '搜索:「统UI翻10」恰命中 101/100 两行(日期降序)');
    expect(find.text('本页 2 笔'), findsOneWidget, reason: '搜索后:本页计数 2');
    expect(find.text('第 1 页'), findsNothing,
        reason: '搜索后单页:分页条整体隐藏(单页隐藏语义)');
    expect(find.byTooltip('下一页'), findsNothing, reason: '搜索后单页:下一页按钮隐藏');

    // 清除钮(提交空串)→ 全量恢复。
    final clearBtn = find.byTooltip('清除搜索');
    expect(clearBtn, findsOneWidget, reason: 'sanity:有词时清除钮出现');
    await t.ensureVisible(clearBtn);
    await t.pumpAndSettle();
    await t.tap(clearBtn);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('本页 100 笔'), findsOneWidget, reason: '清除:第 1 页 100 行恢复');
    expect(detailRowsInOrder(t), hasLength(100), reason: '清除:100 行回列');
    expect(find.text('第 1 页'), findsOneWidget, reason: '清除:多页分页条回显');

    // ---- 翻页:滚到分页条 → 第 2 页仅剩最早 1 笔(FR-6「账户详情翻页」抽验) ----
    await t.scrollUntilVisible(
      find.byTooltip('下一页'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('下一页'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('第 2 页'), findsOneWidget, reason: '翻页:页码指示更新');
    expect(find.text('本页 1 笔'), findsOneWidget, reason: '页 2:本页计数 1');
    expect(detailRowsInOrder(t), ['统UI翻001'],
        reason: '页 2:仅剩日期最早的第 001 笔');
    expect(pagerBtnEnabled(t, '下一页'), isFalse, reason: '末页:下一页禁用');
    expect(pagerBtnEnabled(t, '上一页'), isTrue, reason: '第 2 页:上一页可用');

    // 上一页 → 回第 1 页(游标栈回退)。
    await t.tap(find.byTooltip('上一页'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('第 1 页'), findsOneWidget, reason: '回翻:页码回第 1 页');
    expect(find.text('本页 100 笔'), findsOneWidget, reason: '回翻:第 1 页 100 行恢复');
  });

  testWidgets('统UI②持仓页:搜索收窄(忽略大小写)+ 单页分页条隐藏', (t) async {
    await pumpApp(t);
    await goPage(t, '投资组合');

    // 基线:demo 茅台 + 统UI 3 只 = 4 只(区头计数);< 20/页 → 分页条隐藏。
    // (取舍说明:未铺 >20 只夹具做真实翻页 —— 持仓页 PagerBar 与 F7 交易页/
    // 统UI① 共享同一 core 组件,翻页点按已由两处覆盖;此处按 brief 断言
    // 「夹具 <20 只 → 单页分页条隐藏」的可见性语义。)
    expect(find.text('4 笔 · 按市值'), findsOneWidget,
        reason: '基线:4 只持仓(茅台 + 统UI 三只)');
    expect(textContainingRich('贵州茅台'), findsWidgets, reason: '基线:demo 茅台在列');
    expect(find.text('统UI一号'), findsWidgets, reason: '基线:统UI一号在列');
    expect(find.text('第 1 页'), findsNothing,
        reason: '单页(4 < 20/页):页码指示隐藏');
    expect(find.byTooltip('下一页'), findsNothing, reason: '单页:下一页按钮隐藏');

    // 搜索收窄:symbol 忽略大小写(F9uiTwo ← F9UITWO)。
    final searchField = find.ancestor(
        of: find.text('搜索 symbol / 名称…'), matching: find.byType(TextField));
    expect(searchField, findsOneWidget, reason: 'sanity:持仓搜索框唯一可寻');
    await commitSearch(t, searchField, 'F9UITWO');
    expect(find.text('统UI二号'), findsWidgets, reason: '搜索(F9UITWO):二号在列');
    expect(find.text('统UI一号'), findsNothing, reason: '搜索:一号离列');
    expect(find.text('统UI三号'), findsNothing, reason: '搜索:三号离列');
    expect(textContainingRich('贵州茅台'), findsNothing, reason: '搜索:demo 茅台离列');

    // 清除 → 恢复全量,再验 name 段中文搜索(统UI → 恰 3 只)。
    final clearBtn = find.byTooltip('清除搜索');
    await t.ensureVisible(clearBtn);
    await t.pumpAndSettle();
    await t.tap(clearBtn);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('4 笔 · 按市值'), findsOneWidget, reason: '清除:4 只全量恢复');

    await commitSearch(t, searchField, '统UI');
    expect(find.text('3 笔 · 按市值'), findsOneWidget,
        reason: '搜索(统UI):只剩统UI 三只(demo 茅台不含)');
    expect(find.text('统UI一号'), findsWidgets);
    expect(find.text('统UI二号'), findsWidgets);
    expect(find.text('统UI三号'), findsWidgets);
    expect(textContainingRich('贵州茅台'), findsNothing, reason: '搜索:茅台离列');

    // 无命中 → 友好空提示(搜索后空态,非全量空态)。
    await commitSearch(t, searchField, '统UI无此串');
    expect(find.text('未找到匹配的持仓'), findsOneWidget, reason: '无命中:空提示');
  });

  testWidgets('统UI③债务页:排序切换顺序翻转 + 搜索收窄', (t) async {
    await pumpApp(t);
    await goPage(t, '债务管理');

    // 基线(默认 到期日升序 = debtCompareList):统UI 相对序 [丁,乙,甲,丙]
    // (2026-10 < 2026-12 < 2027-03 < 2027-06);demo 招商银行(2036)居末。
    expect(debtRowsInOrder(t), ['统UI债丁', '统UI债乙', '统UI债甲', '统UI债丙'],
        reason: '默认到期升序:统UI 夹具按到期序');
    expect(debtRowsInOrder(t, includeDemo: true).last, '招商银行',
        reason: '默认序:demo 招商银行(2036 到期)沉底');

    // 排序控件:点当前态按钮弹四态菜单 → 选金额降序。
    await t.ensureVisible(find.text('到期日升序'));
    await t.pumpAndSettle();
    await t.tap(find.text('到期日升序'));
    await t.pumpAndSettle();
    await t.tap(find.text('金额降序').last); // .last = 弹层菜单项(按钮态同名)
    await t.pumpAndSettle(const Duration(seconds: 2));

    // oracle(金额降序,前缀守卫):乙 900,000 > 丁 700,000 > 甲 500,000 > 丙 300,000
    // —— 与到期升序 [丁,乙,甲,丙] 不同序(金额/到期反相关 → 翻转可见);
    // demo 招商银行(¥100,000 最大)翻到最前。
    expect(debtRowsInOrder(t), ['统UI债乙', '统UI债丁', '统UI债甲', '统UI债丙'],
        reason: '金额降序:与默认到期序顺序变化(乙/丁 互换)');
    expect(debtRowsInOrder(t, includeDemo: true).first, '招商银行',
        reason: '金额降序:demo 招商银行(最大额)居首');
    expect(find.text('金额降序'), findsWidgets, reason: '控件态文案更新为金额降序');

    // 搜索收窄:对手方「统UI债乙」→ 只剩乙(甲/丙/丁 与 demo 招商银行全离列)。
    final searchField = find.ancestor(
        of: find.text('搜索对手方…'), matching: find.byType(TextField));
    expect(searchField, findsOneWidget, reason: 'sanity:债务搜索框唯一可寻');
    await commitSearch(t, searchField, '统UI债乙');
    expect(debtRowsInOrder(t, includeDemo: true), ['统UI债乙'],
        reason: '搜索:只剩统UI债乙一张卡(含 demo 守卫)');
  });

  testWidgets('统UI④账户管理页:搜索收窄 + 清除恢复', (t) async {
    await pumpApp(t);
    await goPage(t, '账户管理');

    // 基线:demo 储蓄卡与统UI钱包都在列。
    expect(find.text('储蓄卡'), findsWidgets, reason: '基线:demo 储蓄卡在列');
    expect(find.text('统UI钱包'), findsWidgets, reason: '基线:统UI钱包在列');

    // 搜索「统UI钱包」:名称 contains 恰命中 1 张卡(统UI翻分类/统UI证券账户/
    // 统UI投资资金/统UI负债账户均不含该连续串;demo 账户名全无「统UI」)。
    final searchField = find.ancestor(
        of: find.text('搜索账户名…'), matching: find.byType(TextField));
    expect(searchField, findsOneWidget, reason: 'sanity:账户搜索框唯一可寻');
    await commitSearch(t, searchField, '统UI钱包');
    expect(find.text('统UI钱包'), findsWidgets, reason: '搜索:统UI钱包卡保留');
    expect(find.text('储蓄卡'), findsNothing, reason: '搜索:demo 储蓄卡离列');
    expect(find.text('统UI翻分类'), findsNothing, reason: '搜索:不匹配的统UI账户离列');

    // 清除 → 全量恢复。
    final clearBtn = find.byTooltip('清除搜索');
    await t.ensureVisible(clearBtn);
    await t.pumpAndSettle();
    await t.tap(clearBtn);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('储蓄卡'), findsWidgets, reason: '清除:demo 储蓄卡回列');
    expect(find.text('统UI钱包'), findsWidgets, reason: '清除:统UI钱包回列');
  });

  // ---- F8 FR-5 标签维度三链(标维* 夹具,guest 模式标签控件恒挂载) ----

  testWidgets('统UI⑤标签页跳转:点「标维重点」卡 → 交易列表只剩挂标签 3 笔(端到端)',
      (t) async {
    await pumpApp(t);
    // 标签页路径照 ui_tag_page:设置 → 标签管理。
    await goPage(t, '设置');
    final navRow = find.text('标签管理');
    await t.ensureVisible(navRow.first);
    await t.pumpAndSettle();
    await t.tap(navRow.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('新建标签'), findsWidgets, reason: 'sanity:标签管理页可达');

    // 点「标维重点」标签卡整卡(FR-3:TagCard onOpen → push /transactions 携
    // tagId extra;guest 模式 tagFilterAvailable 恒 true,入口可点)。
    expect(find.text('标维重点'), findsWidgets, reason: 'sanity:标维重点卡在列');
    await t.tap(find.text('标维重点').first);
    await t.pumpAndSettle(const Duration(seconds: 3));

    // 跳转落地:交易列表页 H1 地标 + 初始筛选已生效(路由 extra → 首查带 tagId)。
    expect(find.text('交易管理'), findsWidgets, reason: '跳转:交易列表页地标');
    expect(textContainingRich('标维支出甲'), findsWidgets, reason: '筛选:挂标签甲在列');
    expect(textContainingRich('标维支出乙'), findsWidgets, reason: '筛选:挂标签乙在列');
    expect(textContainingRich('标维收入丙'), findsWidgets, reason: '筛选:挂标签丙在列');
    expect(textContainingRich('标维支出丁'), findsNothing,
        reason: '筛选:挂「标维次要」的丁离列');
    expect(textContainingRich('统UI翻101'), findsNothing,
        reason: '筛选:无标签的统UI翻夹具离列(跨夹具守卫)');
    expect(find.text('工资'), findsNothing, reason: '筛选:无标签的 demo 工资离列');
    // 筛选条标签下拉关闭态回显已选标签名(受控状态随初始筛选注入)。
    expect(find.text('标维重点'), findsWidgets, reason: '筛选条:标签下拉回显已选');
  });

  testWidgets('统UI⑥交易列表标签下拉:全部→重点(3 笔)→次要(1 笔)→全部恢复', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    // 基线(全部):标维四笔 + 无标签夹具/demo 全量在列(当月+统UI翻 均在第 1 页)。
    expect(textContainingRich('标维支出甲'), findsWidgets, reason: '基线:甲在列');
    expect(textContainingRich('标维支出丁'), findsWidgets, reason: '基线:丁在列');
    expect(textContainingRich('统UI翻101'), findsWidgets, reason: '基线:统UI翻101在列');
    expect(find.text('工资'), findsWidgets, reason: '基线:demo 工资在列');

    // 选「标维重点」:只剩挂标签甲/乙/丙 3 笔(FR-2 标签反查)。
    await pickTag(t, closedLabel: '全部标签', itemLabel: '标维重点');
    expect(textContainingRich('标维支出甲'), findsWidgets, reason: '重点:甲在列');
    expect(textContainingRich('标维支出乙'), findsWidgets, reason: '重点:乙在列');
    expect(textContainingRich('标维收入丙'), findsWidgets, reason: '重点:丙在列');
    expect(textContainingRich('标维支出丁'), findsNothing, reason: '重点:丁离列');
    expect(textContainingRich('统UI翻101'), findsNothing, reason: '重点:统UI翻101离列');
    expect(find.text('工资'), findsNothing, reason: '重点:demo 工资离列');
    expect(find.text('标维重点'), findsWidgets, reason: '重点:下拉关闭态回显');

    // 切「标维次要」:列表翻转成只剩丁 1 笔(下拉切换列表变化)。
    await pickTag(t, closedLabel: '标维重点', itemLabel: '标维次要');
    expect(textContainingRich('标维支出丁'), findsWidgets, reason: '次要:丁在列');
    expect(textContainingRich('标维支出甲'), findsNothing, reason: '次要:甲离列');
    expect(textContainingRich('标维收入丙'), findsNothing, reason: '次要:丙离列');

    // 切回「全部标签」:全量恢复(甲乙丙丁 + 无标签夹具/demo)。
    await pickTag(t, closedLabel: '标维次要', itemLabel: '全部标签');
    expect(textContainingRich('标维支出甲'), findsWidgets, reason: '恢复:甲回列');
    expect(textContainingRich('标维支出丁'), findsWidgets, reason: '恢复:丁回列');
    expect(textContainingRich('统UI翻101'), findsWidgets, reason: '恢复:统UI翻101回列');
    expect(find.text('工资'), findsWidgets, reason: '恢复:demo 工资回列');
  });

  testWidgets('统UI⑦报表页标签口径:选标签汇总条四数字变化(oracle 夹具)', (t) async {
    await pumpApp(t);
    await goPage(t, '报表分析');
    expect(find.text('报表分析'), findsWidgets, reason: 'sanity:报表页可达');

    // 基线(全部标签,锚月=运行当月,scope month;含 demo 种子口径,见
    // setUpAll 注释 oracle):income 800,000(demo 工资)+500,000(丙)
    // = ¥13,000.00;expense 5,000(午餐)+12,000+34,500+7,700 = ¥592.00。
    // 净额/日均依赖运行日并集活跃日数 → 基线只断收入/支出两口径。
    expect(find.text('¥ 13,000.00'), findsWidgets,
        reason: '基线:当月收入 = demo 工资 + 丙(未选标签全量口径)');
    expect(find.text('¥ 592.00'), findsWidgets,
        reason: '基线:当月支出 = demo 午餐 + 甲乙丁四笔');

    // 选「标维重点」(FR-4:summary 聚合前按 junction 关联集过滤):
    // income 500,000 / expense 46,500 / net 453,500 / 日均 453,500~/2=226,750。
    await pickTag(t, closedLabel: '全部标签', itemLabel: '标维重点');
    expect(find.text('¥ 5,000.00'), findsWidgets, reason: '重点:收入只剩丙 5,000');
    expect(find.text('¥ 465.00'), findsWidgets,
        reason: '重点:支出只剩甲+乙 465(demo 午餐/丁被剔出)');
    expect(find.text('¥ 4,535.00'), findsWidgets, reason: '重点:结余 = 5,000−465');
    expect(find.text('¥ 2,267.50'), findsWidgets,
        reason: '重点:日均 = 453,500 ~/ 2 活跃日(10/20)');
    expect(find.text('¥ 13,000.00'), findsNothing,
        reason: '重点:全量口径收入离屏(数字确已变化)');

    // 切「标维次要」:只剩丁 1 笔 —— income 0 / expense 77 / 单活跃日
    // → 结余=日均=−77(负号口径一并钉死)。
    await pickTag(t, closedLabel: '标维重点', itemLabel: '标维次要');
    expect(find.text('¥ 0.00'), findsWidgets, reason: '次要:收入 0(无挂标签收入)');
    expect(find.text('¥ 77.00'), findsWidgets, reason: '次要:支出只剩丁 77');
    expect(find.text('-¥ 77.00'), findsWidgets,
        reason: '次要:结余与日均均 −77(单活跃日,日均=净额)');

    // 切回「全部标签」:全量口径恢复(变化可逆,锚月不动)。
    await pickTag(t, closedLabel: '标维次要', itemLabel: '全部标签');
    expect(find.text('¥ 13,000.00'), findsWidgets, reason: '恢复:全量收入回屏');
    expect(find.text('¥ 592.00'), findsWidgets, reason: '恢复:全量支出回屏');
  });
}

/// 分页按钮可用性(照 ui_list_filter.pagerBtnEnabled):经 tooltip 定位祖先
/// IconButton,onPressed null = 禁用态。
bool pagerBtnEnabled(WidgetTester t, String tooltip) =>
    t
        .widget<IconButton>(find.ancestor(
            of: find.byTooltip(tooltip), matching: find.byType(IconButton)))
        .onPressed !=
    null;

/// 账户详情近期交易行(统UI翻\d{3} 精确描述,按渲染顺序)。子串匹配会误计
/// 同前缀账户名(统UI翻分类 出现在行副标题),故用正则只数行描述本体。
List<String> detailRowsInOrder(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        if (w.data != null && RegExp(r'^统UI翻\d{3}$').hasMatch(w.data!)) w.data!,
    ];

/// 债务页卡序(统UI债甲/乙/丙/丁 精确 Text,按渲染顺序)。卡片 counterparty
/// 是裸 Text(exact data);总览脚注里的对手方是 Text.rich 组合串,exact
/// 匹配天然排除 —— 不会重复计数。includeDemo 时并入 demo 招商银行守卫断言。
List<String> debtRowsInOrder(WidgetTester t, {bool includeDemo = false}) {
  const names = {'统UI债甲', '统UI债乙', '统UI债丙', '统UI债丁'};
  final all = includeDemo ? {...names, '招商银行'} : names;
  return [
    for (final w in t.widgetList<Text>(find.byType(Text)))
      if (w.data != null && all.contains(w.data)) w.data!,
  ];
}

/// 标签下拉切换 helper(F8 FR-2 交易筛选条 / FR-4 报表顶栏共用 TxnTagPicker):
/// 点关闭态(closedLabel = 当前回显:「全部标签」或已选标签名)展开菜单 →
/// 点目标菜单项(.last:弹层菜单项在树序靠后,与关闭态同名时取后者)→
/// 给足真实时间让重载空窗愈合(照 ui_list_filter 筛② flake 注:切换后页面经
/// Loading→Loaded 重挂,标签选项经 initState 异步预取,Dropdown 的 value 需
/// 等选项就位后才回显)。
Future<void> pickTag(WidgetTester t,
    {required String closedLabel, required String itemLabel}) async {
  final closed = find.text(closedLabel).first;
  await t.ensureVisible(closed);
  await t.pumpAndSettle();
  await t.tap(closed);
  await t.pumpAndSettle();
  await t.tap(find.text(itemLabel).last);
  await t.pump(const Duration(seconds: 1));
  await t.pumpAndSettle(const Duration(seconds: 2));
}
