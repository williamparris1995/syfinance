/// F6 UI 链:模板一键记账(ui_template_record;FR-12「手动触发记一笔」枚举项
/// 补齐,fix round 1 review ① —— 此前十文件未覆盖 TemplateCard.onRecord)。
///
/// 链路:DS 预置 autoRecord=false 月度支出模板(手动模式)→ 设置 → 周期模板
/// → 模板卡 trailing「立即记账」按钮(template_page.dart onRecord →
/// RecordTemplateRequested → bloc _onRecord → DS record)→ 断言:
///   ① DS 侧交易按 nextDate 落账(description=模板名;方向配对复式:
///      debit 分类账户 / credit 资金账户;raw drift 独立读);
///   ② 模板 nextDate 推进一个周期(月度 = +1 月,billingDay=0 取发生日;
///      夹具日固定 12 号,无月末钳位歧义)+ lastTransactionId 关联 + version+1;
///   ③ 页面反馈:SnackBar「已记录(下次 ...)」+ 卡片「下次 」游标刷新。
/// 资金余额 oracle:支出模板 credit 资金腿 → balanceOf −amountCents。
///
/// 注:侧栏「订阅管理」当前指向 /accounts/templates(路由缺口,见
/// ui_boot_subscription 文件头),本测试同它经 设置 → 周期模板 进入;
/// endDate 显式传未来值(DS create 对 endDate=null 兜底「UTC 今天」会把
/// 推进截断 —— 生产语义缺口照 boot 文件绕开,记报告不修生产)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_template_record_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String fundsId; // UI模资金(初始 3,000.00,支出模板资金腿)
  late String catId; // UI模餐饮(expense 分类账户,复式 debit 腿)
  late String tplId; // UI模订阅(88.00 月度支出,autoRecord=false)
  late String beforeNext; // 记录前 nextDate(YYYY-MM-DD;交易应落在这个日期)
  late String afterNext; // 记录后 nextDate(= beforeNext +1 月,推进 oracle)

  // date-only 字符串夹具帮手(模板 create 的 startDate/endDate 契约;
  // 与 DS _formatDate / formatDate 同构:YYYY-MM-DD 月日补零)。
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;账户/模板经 DS 铺,UI 只测一键记账交互。
    await resetTestDb();
    db = getIt<AppDatabase>();
    fundsId = await fundsAccount('UI模资金', 300000); // 3,000.00
    final accounts = AccountLocalDataSource(db);
    final cat = await accounts.create(const CreateAccountParams(
      name: 'UI模餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    catId = cat.id;

    // 手动模板(autoRecord=false):startDate = 真实 now −2 月、日固定 12 →
    // create 时 nextDate = start +1 月(= now −1 月,已到期,贴合「到期点记一笔」);
    // 记录后 nextDate 再 +1 月(= now 当月 12 号)。billingDay=0 取发生日,
    // 日 12 ≤28 → 无月末钳位,oracle 确定可算。
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 2, 12);
    beforeNext = iso(DateTime(start.year, start.month + 1, 12));
    afterNext = iso(DateTime(start.year, start.month + 2, 12));
    tplId = (await TemplateLocalDataSource(
            db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)))
        .create(
      name: 'UI模订阅',
      amountCents: 8800, // 88.00
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 0,
      startDate: iso(start),
      endDate: iso(DateTime(now.year + 1, now.month, now.day)),
      autoRecord: false,
      category: catId,
    ))
        .id;
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('模①一键记账:模板卡「立即记账」→ 落账 + nextDate 推进 + 页面反馈', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 3,000.00

    await pumpApp(t);
    await goPage(t, '设置');
    expect(find.text('偏好设置'), findsWidgets, reason: '设置页地标');

    // 设置页「周期模板」导航行(可能需滚动露出;同 ui_boot_subscription 路径)。
    final tplEntry = find.text('周期模板');
    await t.ensureVisible(tplEntry.first);
    await t.pumpAndSettle();
    await t.tap(tplEntry.first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 模板页地标 + 夹具卡在列(演示种子两模板同页,故全部按钮断言按卡范围限定)。
    expect(find.text('周期模板'), findsWidgets, reason: '周期模板页地标');
    final card = find.ancestor(
        of: find.text('UI模订阅'), matching: find.byType(DataCard));
    expect(card.evaluate(), isNotEmpty, reason: '手动模板卡在列');
    // 基线:卡显示记录前游标。
    expect(textContainingRich('下次 $beforeNext'), findsWidgets,
        reason: '记录前 nextDate=$beforeNext');

    // 点夹具卡 trailing「立即记账」(tooltip 定位;种子卡同按钮,必须卡内限定)。
    await t.ensureVisible(find.text('UI模订阅'));
    await t.pumpAndSettle();
    await t.tap(find
        .descendant(of: card, matching: find.byTooltip('立即记账'))
        .first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // ---- ③ 页面反馈:SnackBar 成功消息 + 卡片游标刷新(bloc 成功即重拉列表) ----
    expect(textContainingRich('已记录'), findsWidgets,
        reason: 'SnackBar 反馈「已记录(下次 ...)」');
    expect(textContainingRich('下次 $afterNext'), findsWidgets,
        reason: '卡片「下次 」刷新为推进后游标 $afterNext');

    // ---- ① DS 落账断言(raw drift):description=模板名,方向配对复式 ----
    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('UI模订阅')))
        .get();
    expect(rows, hasLength(1), reason: '一键记账落账 1 笔');
    final entries = await (db.select(db.transactionEntries)
          ..where((e) => e.transactionId.equals(rows.single.id)))
        .get();
    expect(entries, hasLength(2), reason: '支出模板 = 2 腿复式');
    final debitLeg = entries.firstWhere((e) => e.debitCents > 0);
    final creditLeg = entries.firstWhere((e) => e.creditCents > 0);
    expect(debitLeg.accountId, catId, reason: '借方 = 分类账户');
    expect(creditLeg.accountId, fundsId, reason: '贷方 = 资金账户');
    expect(debitLeg.debitCents, 8800, reason: '金额 = 88.00 元');

    // ---- ② 模板推进断言:nextDate +1 月 / lastTransactionId 关联 / version+1 ----
    final after =
        await TemplateLocalDataSource(db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)))
            .get(tplId);
    expect(after.nextDate, afterNext,
        reason: 'nextDate 推进一个周期($beforeNext → $afterNext)');
    expect(after.lastTransactionId, rows.single.id,
        reason: 'lastTransactionId 关联本次交易');
    expect(after.version, 2, reason: 'version 1 → 2(乐观锁推进)');

    // ---- 资金余额 oracle:支出 credit 资金腿 −88.00 ----
    expect(await balanceOf(db, fundsId), beforeFunds - 8800,
        reason: '资金账户余额 −88.00');
  });
}
