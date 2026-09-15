/// F6 UI 链:手动收支表单(ui_record_form)。
///
/// 链路:交易页顶栏「新增交易」→ 记一笔表单(真实点按输入:金额 / 选账户 /
/// 选分类 / 商户 / 提交)→ 空提交被校验拦截 → 支出一笔 + 收入一笔落库 →
/// 交易记录列表显示(textContainingRich 富文本感知)。
///
/// 语义出入说明(以代码为准,记报告不修生产):顶栏「新增交易」走
/// context.push('/transactions/new'),表单成功 pop 后列表页**不会自动重拉**
/// (TransactionsPage 仅在自身 _openCreateForm 路径 reload)→ 列表显示
/// 断言放在下一个 testWidgets(pump 全新 app,路由 builder 重跑即拉最新)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_record_form_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter/material.dart'
    show TextFormField, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;UI 前置数据经 DS 铺,UI 只测交互。
    await resetTestDb();
    db = getIt<AppDatabase>();

    // ---- 自包含夹具(UI记* 前缀,与演示数据零耦合) ----
    await fundsAccount('UI记钱包', 200000); // 资产 2,000.00(转出/转入腿)
    final accounts = AccountLocalDataSource(db);
    await accounts.create(const CreateAccountParams(
      name: 'UI记餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    await accounts.create(const CreateAccountParams(
      name: 'UI记工资',
      accountType: AccountType.income,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  /// raw drift 数 description 命中的交易数(独立于 UI 读写管道)。
  Future<int> countOf(String description) async => (await (db.select(db.transactions)
        ..where((x) => x.description.equals(description)))
      .get())
      .length;

  /// raw drift 汇总某交易的 Σdebit(金额断言独立于 UI)。
  Future<int> debitSumOf(String txnId) async => (await (db.select(
          db.transactionEntries)
        ..where((e) => e.transactionId.equals(txnId)))
      .get())
      .fold<int>(0, (s, e) => s + e.debitCents);

  testWidgets('记①支出一笔:空提交被拦 → 真实填表提交 → 落库', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');
    expect(find.text('交易管理'), findsWidgets, reason: '交易列表页地标');

    // 顶栏「新增交易」(app_shell 路由感知创建按钮,location==/transactions 才显)。
    final createBtn = find.text('新增交易');
    expect(createBtn.evaluate(), isNotEmpty, reason: '顶栏新增交易入口');
    await t.tap(createBtn.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('记一笔'), findsWidgets, reason: '记一笔表单页标题');

    // ---- 空提交被拦(Form validator 内联提示,不弹原生对话框) ----
    await t.tap(find.text('保存').first);
    await t.pumpAndSettle();
    expect(find.text('金额必须大于 0'), findsWidgets, reason: '空金额被校验拦截');
    expect(find.text('请选择转出账户'), findsWidgets, reason: '未选账户被校验拦截');
    expect(await countOf('UI记超市'), 0, reason: '空提交未落库');

    // ---- 填表:金额 → 转出账户 → 支出分类 → 商户 ----
    await t.enterText(find.byKey(const ValueKey('hero_amount')), '36.50');
    await t.pumpAndSettle();

    // 转出账户下拉:点下拉 hint 展开菜单,再点菜单项(overlay 渲染在后,取 .last)。
    await t.tap(find.text('例如：招商银行、现金').first);
    await t.pumpAndSettle();
    await t.tap(find.text('UI记钱包').last);
    await t.pumpAndSettle();

    // 支出分类下拉(account-as-category:expense 账户即分类)。
    await t.tap(find.text('例如：餐饮、交通').first);
    await t.pumpAndSettle();
    await t.tap(find.text('UI记餐饮').last);
    await t.pumpAndSettle();

    await t.enterText(
        find.widgetWithText(TextFormField, '交易对象 / 商户'), 'UI记超市');
    await t.pumpAndSettle();

    // 提交。
    await t.tap(find.text('保存').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 落库断言(raw drift):description + 复式金额 36.50 = 3,650 分。
    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('UI记超市')))
        .get();
    expect(rows, hasLength(1), reason: '支出交易落库');
    expect(await debitSumOf(rows.single.id), 3650, reason: '借方合计 = 36.50 元');
  });

  testWidgets('记②收入一笔:类型切「收入」→ 填表提交 → 落库', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    await t.tap(find.text('新增交易').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 类型 tabs 切「收入」(子标题「收进来的钱」作陪衬,精确匹配不冲突)。
    await t.tap(find.text('收入').first);
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const ValueKey('hero_amount')), '1234.56');
    await t.pumpAndSettle();

    // 收入模式字段:转入账户 / 收入分类。
    await t.tap(find.text('例如：招商银行、现金').first);
    await t.pumpAndSettle();
    await t.tap(find.text('UI记钱包').last);
    await t.pumpAndSettle();

    // 收入分类下拉在表单底部(实机曾落视口底缘,tap 命中偏离)→ 先滚动露出。
    await t.ensureVisible(find.text('例如：工资、理财收益').first);
    await t.pumpAndSettle();
    await t.tap(find.text('例如：工资、理财收益').first);
    await t.pumpAndSettle();
    await t.tap(find.text('UI记工资').last);
    await t.pumpAndSettle();

    await t.enterText(
        find.widgetWithText(TextFormField, '交易对象 / 商户'), 'UI记外快');
    await t.pumpAndSettle();

    await t.tap(find.text('保存').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('UI记外快')))
        .get();
    expect(rows, hasLength(1), reason: '收入交易落库');
    expect(await debitSumOf(rows.single.id), 123456,
        reason: '借方合计 = 1,234.56 元');
  });

  testWidgets('记③列表回看:两笔手动交易入列(富文本感知)', (t) async {
    // 顶栏创建路径列表页不自动重拉(见文件头)→ 全新 app 进入交易页即最新。
    await pumpApp(t);
    await goPage(t, '交易记录');

    expect(textContainingRich('UI记超市'), findsWidgets, reason: '支出一笔入列');
    expect(textContainingRich('UI记外快'), findsWidgets, reason: '收入一笔入列');
    // 金额列:支出 ¥36.50 / 收入 ¥1234.56(列表 _formatCents 无千分位分组,
    // 与汇总卡(¥9,234.56 含分组)格式不同 —— 以页面源码为准)。
    expect(textContainingRich('36.50'), findsWidgets, reason: '支出金额可见');
    expect(textContainingRich('1234.56'), findsWidgets, reason: '收入金额可见');
  });
}
