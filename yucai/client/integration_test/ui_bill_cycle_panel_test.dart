/// v5-B「账单周期」面板 UI 链 e2e(2026-09-23 拍板 B 落地验收)。
///
/// 链路:账户管理 → 点信用卡卡面 → 账户详情:
///   ① hero 恒等式 caption「= 上期剩余 ¥2,000.00 + 本期账单(未出账) ¥500.00」;
///   ② stats 语义卡(上期剩余(应还) accent + 本期新增(未出账));
///   ③ B 面板:应答块大字 ¥2,000.00(= 还款对话框全额 = 催办同数)+ 构成条
///      80%/20% + 合计 ¥2,500.00;
///   ④ 「还款日提醒」callout(还款日设为今天 →「今天到期」确定性);
///   ⑤ 还款对话框「全额(上期账单)」¥2,000.00(三处同数闭环);
///   ⑥ 未设账单日卡:hero 全额口径 caption + 面板降级提示 +「去设置」。
///
/// 夹具(同 T7/T8 测试口径):账单 3000 / 还 1000 / 刷 500 → current 2500。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争)。
/// 运行:`flutter test integration_test/ui_bill_cycle_panel_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' show Text, ValueKey;
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
  late String cardId; // 有账单日卡(还款日 = 今天,「今天到期」确定性)

  setUpAll(() async {
    await resetTestDb();
    db = getIt<AppDatabase>();
    final accounts = AccountLocalDataSource(db);

    // 账单日动态选(两种取法都保证 D ≤ 今天 − 5 天,还款/消费落 (D, 今天])。
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bd = today.day >= 8 ? today.day - 7 : 20;
    final d = DateTime(today.year, today.month, bd).isAfter(today)
        ? DateTime(today.year, today.month - 1, bd)
        : DateTime(today.year, today.month, bd);

    // 直写余额(repay e2e setCardDebt 同款):避免开账分录搅进 S。
    Future<void> setBalance(String id, int cents) async {
      final row = await (db.select(db.accounts)..where((a) => a.id.equals(id)))
          .getSingle();
      await (db.update(db.accounts)..where((a) => a.id.equals(id)))
          .write(AccountsCompanion(
        currentBalanceCents: Value(cents),
        version: Value(row.version + 1),
      ));
    }

    final card = await accounts.create(CreateAccountParams(
      name: '账单周期测试卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: 0, // 余额直写(避免开账分录搅进 S)
      ownership: Ownership.personal,
      creditLimitCents: 5000000,
      creditBillingDay: bd,
      creditRepaymentDay: today.day, // 还款日 = 今天 → chip/callout「今天」
    ));
    cardId = card.id;

    await setBalance(cardId, 250000); // current ¥2,500(先建降级卡再落余额)
    final noBilling = await accounts.create(const CreateAccountParams(
      name: '无账单日卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
      creditLimitCents: 5000000,
    ));
    await setBalance(noBilling.id, 320000);

    // 分录:还款 ¥1,000(D+3,debit=负债负向)+ 消费 ¥500(D+5,credit=正向)
    // → S=500,R=1000:上期账单 3000 / 上期剩余 2000 / current 2500。
    Future<void> seedEntry(String id, DateTime date,
        {int debit = 0, int credit = 0}) async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: 't-$id',
            transactionDate: date,
            description: 'v5-B e2e 夹具',
            version: 1,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ));
      await db.into(db.transactionEntries).insert(
            TransactionEntriesCompanion.insert(
              id: 'e-$id',
              transactionId: 't-$id',
              accountId: cardId,
              chartOfAccountCode: '',
              debitCents: debit,
              creditCents: credit,
              note: '',
            ),
          );
    }

    await seedEntry('repay', d.add(const Duration(days: 3)), debit: 100000);
    await seedEntry('spend', d.add(const Duration(days: 5)), credit: 50000);
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  /// 进账户详情:账户管理 → 点卡名。
  Future<void> openDetail(WidgetTester t, String cardName) async {
    await goPage(t, '账户管理');
    await t.ensureVisible(find.text(cardName).first);
    await t.pumpAndSettle();
    await t.tap(find.text(cardName).first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('账户详情'), findsWidgets, reason: '已进详情页');
  }

  /// 详情页 ListView 懒构建:先从内容区坐标逐屏拖动直到目标已构建,再
  /// ensureVisible 对齐。不用 find.byType(ListView) 拖 —— go_router 分支栈
  /// 底下仍挂着账户列表页的 ListView(offstage),`.first` 会拖错对象;
  /// 也不用 scrollUntilVisible(integration binding 与嵌套 Scrollable 不兼容,
  /// e2e 套件惯例是 ensureVisible)。坐标 (700,350) 取侧栏(240px)右侧内容区。
  Future<void> reveal(WidgetTester t, Finder f) async {
    for (var i = 0; i < 8 && f.evaluate().isEmpty; i++) {
      await t.dragFrom(const Offset(700, 350), const Offset(0, -600));
      await t.pumpAndSettle(const Duration(seconds: 1));
    }
    expect(f.evaluate(), isNotEmpty, reason: '目标已构建(拖动最多 8 屏)');
    await t.ensureVisible(f.first);
    await t.pumpAndSettle();
  }

  testWidgets('B①有账单日卡:恒等式 caption + 语义 stats + B 面板 + callout + 对话框同数',
      (t) async {
    await pumpApp(t);
    await openDetail(t, '账单周期测试卡');

    // hero 恒等式 caption(当前欠款 ¥2,500.00 之下)。
    expect(
        find.textContaining('= 上期剩余 ¥2,000.00 + 本期账单(未出账) ¥500.00'),
        findsOneWidget);

    // stats 语义卡(breakdown 已算 → 上期剩余(应还)/本期新增(未出账))。
    // 须在拖动前断言:hero+stats 在首屏,往下滚后 ListView 会把顶部子项卸载。
    expect(find.text('上期剩余(应还)'), findsOneWidget);
    expect(find.text('本期新增(未出账)'), findsOneWidget);

    await reveal(t, find.text('账单周期'));

    final panel = find.byKey(const ValueKey('statementCyclePanel'));
    Finder inPanel(Finder f) => find.descendant(of: panel, matching: f);

    // B 面板应答块:应还大字 ¥2,000.00(与催办/还款对话框同一数字)。
    final big =
        t.widget<Text>(inPanel(find.byKey(const ValueKey('ccAnswerAmount'))));
    expect(big.data, '¥2,000.00');
    // 构成区:合计 = 当前欠款 2500,80%/20%。
    expect(inPanel(find.text('当前欠款构成')), findsOneWidget);
    expect(inPanel(find.text('¥2,500.00')), findsOneWidget);
    expect(inPanel(find.textContaining(' · 80%')), findsOneWidget);
    expect(inPanel(find.textContaining(' · 20%')), findsOneWidget);
    // 还款日 = 今天 → chip「今天」。
    expect(inPanel(find.text('今天')), findsOneWidget);

    // 「还款日提醒」callout(面板之下;还款日=今天 → 确定性文案)。
    await reveal(t, find.text('还款日提醒'));
    expect(find.textContaining('今天到期'), findsOneWidget);
    expect(find.textContaining('均以此数为准'), findsOneWidget);

    // 还款对话框:全额(上期账单)¥2,000.00 —— 与面板应答大字同数闭环。
    await t.tap(find.text('还款').first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('全额(上期账单)'), findsOneWidget);
    expect(find.text('¥2,000.00'), findsWidgets,
        reason: '对话框全额与面板应答/催办三处同数');
    await t.tap(find.text('取消').first);
    await t.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('B②未设账单日卡:hero 全额口径 caption + 面板降级 +「去设置」',
      (t) async {
    await pumpApp(t);
    await openDetail(t, '无账单日卡');

    expect(find.text('未设账单日 · 按全额欠款口径'), findsOneWidget);

    await reveal(t, find.text('账单周期'));
    expect(find.text('设置账单日后可查看账单周期明细'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
    expect(find.byKey(const ValueKey('ccAnswerAmount')), findsNothing);
  });
}
