/// 复制交易时区回归 e2e(修「复制交易产生 8 小时时差」)。
///
/// 根因:transactionTime 的 RFC3339 串解析为 UTC DateTime,而列表 HH:MM /
/// 详情「交易日期」行 / 复制表单 TimeOfDay 预填全按墙上时间读 .hour——
/// UTC+8 下偏 8 小时;复制时把 UTC 小时当墙上时间再 toUtc 编码提交,
/// 一来一回净差 8 小时落库。修复 = 读边界(mapper / drift _toEntity)归一
/// toLocal,实体恒为本地墙上时间。
///
/// 链路:种子两笔带墙上时间(21:37)的支出 ——
///   ① 新径:表单同款编码(wall.toUtc().toIso8601String())经 DS 写入
///      (修复后 drift 落 `+08:00` 本地 offset 文本);
///   ② 旧行模拟:同款创建后把 transaction_time 列直写 UTC DateTime
///      (drift 文本模式落 `Z` 文本 = 修复前版本的存量落库形态),
///      验证存量数据被 _toEntity 的 toLocal 修复。
/// → 交易记录列表 HH:MM 显示 21:37 → 详情 meta 行显示 21:37 →
///   「复制交易」→ 记一笔表单时间字段预填 21:37 → 保存 →
///   raw drift 断言副本 wall hour/minute 保持 21:37。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争)。
/// 运行:`flutter test integration_test/ui_copy_tz_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TransactionLocalDataSource ds;
  late String cashId;
  late String foodId;
  late String newPathId;
  const wallText = '21:37'; // 种子墙上时间(UTC 下为 13:37,偏移可辨)

  setUpAll(() async {
    await resetTestDb();
    db = getIt<AppDatabase>();
    cashId = await fundsAccount('复测钱包', 0);
    final accounts = AccountLocalDataSource(db);
    final food = await accounts.create(const CreateAccountParams(
      name: '复测餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    foodId = food.id;
    ds = TransactionLocalDataSource(db, BalanceLocalUpdater(db));

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final wall = DateTime(now.year, now.month, now.day, 21, 37);

    // ① 新径:表单编码 → DS(_parseTime 修复后 toLocal 入库)。
    final t1 = await ds.recordExpense(RecordExpenseParams(
      transactionDate: day,
      expenseAccountId: foodId,
      assetAccountId: cashId,
      amountCents: 3600,
      description: '复制时区新径',
      transactionTime: wall.toUtc().toIso8601String(),
    ));
    newPathId = t1.id;

    // ② 旧行模拟:直写 UTC DateTime → drift 落 `Z` 文本(修复前存量形态)。
    final t2 = await ds.recordExpense(RecordExpenseParams(
      transactionDate: day,
      expenseAccountId: foodId,
      assetAccountId: cashId,
      amountCents: 5200,
      description: '复制时区旧行',
      transactionTime: wall.toUtc().toIso8601String(),
    ));
    await (db.update(db.transactions)
          ..where((x) => x.id.equals(t2.id)))
        .write(TransactionsCompanion(transactionTime: Value(wall.toUtc())));
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  /// 桌面宽窗列表表格行只显示日期(HH:MM 仅窄布局卡片渲染),墙上时间的
  /// 显示面在详情页 meta「交易日期」行(两种布局同构)→ 断言放详情页。
  /// (行可能落在视口下方 → ensureVisible 先滚入,同 ui_record_form_test。)
  Future<void> openDetailAndExpectWall(WidgetTester t, String rowText) async {
    await pumpApp(t);
    await goPage(t, '交易记录');
    final row = textContainingRich(rowText);
    expect(row, findsWidgets, reason: '$rowText 入列');
    await t.ensureVisible(row.first);
    await t.pumpAndSettle();
    await t.tap(row.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(textContainingRich(wallText), findsWidgets,
        reason: '$rowText 详情显示墙上时间');
  }

  testWidgets('复制①详情显示墙上时间(新径 + 旧行 Z 文本修复)', (t) async {
    // 新径:DS 写入(drift 落 +08:00 本地 offset 文本)。
    await openDetailAndExpectWall(t, '复制时区新径');
  });

  testWidgets('复制①b旧行(Z 文本,修复前存量形态)详情同样显示墙上时间',
      (t) async {
    // 旧行:transaction_time 列直写 UTC DateTime → drift 落 Z 文本;
    // 修复前 UTC 小时被当墙上时间显示(13:37),修复后 toLocal → 21:37。
    await openDetailAndExpectWall(t, '复制时区旧行');
  });

  testWidgets('复制②复制表单预填墙上时间,保存后副本往返保持', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');
    final row = textContainingRich('复制时区新径');
    await t.ensureVisible(row.first);
    await t.pumpAndSettle();
    await t.tap(row.first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 快捷操作「复制交易」→ 记一笔表单(isCopy 全字段预填)。
    await t.tap(find.text('复制交易').first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('记一笔'), findsWidgets, reason: '复制打开记一笔表单');
    // 时间字段预填 = 源交易墙上时间(TimePickerInput 直渲染 HH:MM 文本)。
    expect(find.text(wallText), findsWidgets, reason: '复制预填墙上时间(非 UTC 小时)');

    // 保存副本(金额/账户已预填,直接可提交)。
    await t.tap(find.text('保存').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // raw drift 断言:副本已落库且墙上时间保持(修复前会偏 8 小时)。
    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('复制时区新径')))
        .get();
    expect(rows, hasLength(2), reason: '源交易 + 副本');
    final copy = rows.firstWhere((r) => r.id != newPathId);
    expect(copy.transactionTime, isNotNull, reason: '副本带 transaction_time');
    final copyWall = copy.transactionTime!.toLocal();
    expect(copyWall.hour, 21, reason: '副本墙上小时保持(回归:曾偏 8 小时)');
    expect(copyWall.minute, 37, reason: '副本墙上分钟保持');
    // 版本=1:isCopy 提交走创建(非更新)。
    expect(copy.version, 1, reason: '副本为新建(version 1)');
  });
}
