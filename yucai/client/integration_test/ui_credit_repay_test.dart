/// 信用卡还款 UI 链 e2e(2026-09 用户需求)。
///
/// 覆盖:
///   ① 全额还款:卡菜单「还款」(信用卡不再显示「转账」)→ 对话框选储蓄卡 →
///      SimpleTransfer 落库(借:信用卡 / 贷:储蓄卡)+ 双方余额联动;
///      储蓄卡余额不足时提交被禁用并内联提示;
///   ② 最低还款:预填 10% 可改 → 部分还款 + 本期催办挂失(ReminderDismissals);
///   ③ 分期还款:期数 + 年利率必填 → 复用债务模块建分期债
///      (restructure-only:卡余额不动、无开账分录),期次 12 条,
///      卡上再点还款时分式禁用;本期催办挂失;
///   ④ 欠款编辑:卡编辑表单「当前欠款」预填 currentBalance,保存后落库
///      (回归:此前编辑金额被静默丢弃)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争)。
/// 运行:`flutter test integration_test/ui_credit_repay_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart' show ElevatedButton, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String cardId; // 测试信用卡(欠款 ¥5,000 = 500,000 分)
  late String richId; // 还款储蓄卡(¥9,000)

  setUpAll(() async {
    await resetTestDb();
    db = getIt<AppDatabase>();
    final accounts = AccountLocalDataSource(db);
    richId = await fundsAccount('还款储蓄卡', 900000);
    await fundsAccount('穷储蓄', 10000); // ¥100,余额不足腿
    final card = await accounts.create(const CreateAccountParams(
      name: '测试信用卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: 500000,
      ownership: Ownership.personal,
      creditLimitCents: 5000000,
    ));
    cardId = card.id;
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  /// 打开信用卡还款对话框:账户页 → 该卡 hover 操作栏「还款」。
  Future<void> openRepayDialog(WidgetTester t) async {
    await goPage(t, '账户管理');
    await t.ensureVisible(find.text('测试信用卡').first);
    await t.pumpAndSettle();
    await t.tap(find.text('还款').first);
    await t.pumpAndSettle(const Duration(seconds: 2));
  }

  /// 直写卡欠款(用新开账通道的 DS 层,供各用例独立起态)。
  Future<void> setCardDebt(int cents) async {
    final row = await (db.select(db.accounts)
          ..where((a) => a.id.equals(cardId)))
        .getSingle();
    await (db.update(db.accounts)
          ..where((a) => a.id.equals(cardId)))
        .write(AccountsCompanion(
      currentBalanceCents: Value(cents),
      version: Value(row.version + 1),
    ));
  }

  testWidgets('还①全额:储蓄卡付款落库复式 + 余额联动;余额不足被拦', (t) async {
    await pumpApp(t);
    await goPage(t, '账户管理');

    // 信用卡卡面菜单是「还款」而非「转账」;储蓄卡仍是「转账」。
    await t.ensureVisible(find.text('测试信用卡').first);
    expect(find.text('还款'), findsWidgets, reason: '信用卡入口是还款');
    expect(find.text('转账'), findsWidgets, reason: '储蓄卡入口仍是转账');

    await t.tap(find.text('还款').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 默认全额 ¥5,000.00;默认选中第一个储蓄卡(还款储蓄卡,余额足)。
    // 先切到穷储蓄验证余额不足拦截。
    await t.tap(find.byKey(const ValueKey('repaySavingsField')));
    await t.pumpAndSettle();
    await t.tap(find.text('穷储蓄（余额 ¥100.00）').last);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('repayInsufficientHint')), findsOneWidget,
        reason: '余额不足内联提示');
    expect(
        t.widget<ElevatedButton>(find.byKey(const ValueKey('repaySubmitBtn')))
            .enabled,
        isFalse,
        reason: '余额不足禁用提交');

    // 切回足额储蓄卡提交。
    await t.tap(find.byKey(const ValueKey('repaySavingsField')));
    await t.pumpAndSettle();
    await t.tap(find.text('还款储蓄卡（余额 ¥9000.00）').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('repaySubmitBtn')));
    await t.pumpAndSettle(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 3)); // AppToast timer 走完
    await t.pumpAndSettle();

    // 落库:借:信用卡 500,000 / 贷:储蓄卡 500,000。
    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('信用卡还款')))
        .get();
    expect(rows, hasLength(1), reason: '还款交易落库');
    final entries = await (db.select(db.transactionEntries)
          ..where((e) => e.transactionId.equals(rows.single.id)))
        .get();
    final debitLeg = entries.firstWhere((e) => e.debitCents > 0);
    final creditLeg = entries.firstWhere((e) => e.creditCents > 0);
    expect(debitLeg.accountId, cardId, reason: '借方 = 信用卡(欠款减少)');
    expect(creditLeg.accountId, richId, reason: '贷方 = 储蓄卡');
    expect(debitLeg.debitCents, 500000);

    // oracle:卡 500,000 → 0;储蓄卡 900,000 → 400,000。
    expect(await balanceOf(db, cardId), 0, reason: '全额还清');
    expect(await balanceOf(db, richId), 400000, reason: '储蓄卡扣款');

    // 全额还清不挂失(无欠款可催)。
    final dismissals = await (db.select(db.reminderDismissals)).get();
    expect(dismissals, isEmpty);
  });

  testWidgets('还②最低:预填 10% → 部分还款 + 本期催办挂失', (t) async {
    await setCardDebt(200000); // ¥2,000
    await pumpApp(t);
    await openRepayDialog(t);

    await t.tap(find.text('最低'));
    await t.pumpAndSettle();
    // 预填 ⌈10% × 2,000⌉ = 200.00。
    expect(find.text('200.00'), findsOneWidget, reason: '最低还款预填 10%');

    // 显式选足额储蓄卡(默认第一项可能是余额不足的穷储蓄)。
    await t.tap(find.byKey(const ValueKey('repaySavingsField')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('还款储蓄卡').last);
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('repaySubmitBtn')));
    await t.pumpAndSettle(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();

    // 卡 200,000 → 180,000;储蓄卡 400,000 → 380,000。
    expect(await balanceOf(db, cardId), 180000, reason: '部分还款');
    expect(await balanceOf(db, richId), 380000);

    // 本期(当月)催办挂失。
    final now = DateTime.now();
    final cycleId =
        creditCardCycleEntryId(cardId, DateTime(now.year, now.month, 1));
    final dismissed = await (db.select(db.reminderDismissals)
          ..where((d) => d.entryId.equals(cycleId)))
        .get();
    expect(dismissed, hasLength(1), reason: '最低还款后本期不再催办');
  });

  testWidgets('还③分期:利率必填 → 建分期债(卡余额不动)+ 挂失;再开分式禁用',
      (t) async {
    final legsBeforeInstallment = (await (db.select(db.transactionEntries)
            ..where((e) => e.accountId.equals(cardId)))
        .get())
        .length;
    await pumpApp(t);
    await openRepayDialog(t);

    // 切分期:利率未填 → 提交禁用。
    await t.tap(find.text('分期'));
    await t.pumpAndSettle();
    expect(
        t.widget<ElevatedButton>(find.byKey(const ValueKey('repaySubmitBtn')))
            .enabled,
        isFalse,
        reason: '利率必填');

    // 期数 12 + 年利率 3.6。
    await t.enterText(find.byKey(const ValueKey('repayRateField')), '3.6');
    await t.pumpAndSettle();
    expect(find.textContaining('每期约 ¥'), findsOneWidget, reason: '每期预览');

    await t.tap(find.byKey(const ValueKey('repaySubmitBtn')));
    await t.pumpAndSettle(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();

    // 分期债落库:borrowedIn + subtype=credit_card + 挂本卡。
    final debtRow = await (db.select(db.debts)
          ..where((d) => d.accountId.equals(cardId)))
        .getSingle();
    expect(debtRow.subtype, 'credit_card');
    expect(debtRow.totalPrincipalCents, 180000, reason: '分期本金 = 当前欠款');

    // restructure-only:卡余额不动 + 无开账分录(卡上分录数不因建分期增加)。
    expect(await balanceOf(db, cardId), 180000, reason: '分期不改卡余额');
    final cardLegs = await (db.select(db.transactionEntries)
          ..where((e) => e.accountId.equals(cardId)))
        .get();
    expect(cardLegs, hasLength(legsBeforeInstallment),
        reason: '分期建债不写开账分录(restructure-only)');

    // 12 期计划 → 期次提醒/每期还款链路可用。
    final schedule = await (db.select(db.paymentScheduleEntries)
          ..where((e) => e.debtId.equals(debtRow.id)))
        .get();
    expect(schedule, hasLength(12));

    // 再开还款:分期已被挂账 → 分段禁用提示。
    await openRepayDialog(t);
    expect(find.text('该卡已有挂账分期/债务，不能再创建分期'), findsOneWidget);
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
  });

  testWidgets('还④欠款编辑:表单预填 currentBalance,保存落库(回归)', (t) async {
    await pumpApp(t);
    await goPage(t, '账户管理');

    // 卡编辑入口:账户页该卡 hover 操作栏的「编辑」(带卡 id 的 key 精确命中)。
    await t.ensureVisible(find.byKey(ValueKey('cardEdit-$cardId')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('cardEdit-$cardId')));
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 「当前欠款」预填 1,800.00(currentBalance,而非 initialBalance 5,000)。
    final amountField = find.byKey(const ValueKey('accountPrimaryAmount'));
    expect(amountField, findsOneWidget);
    expect(find.text('1800.00'), findsOneWidget,
        reason: '预填当前欠款而非初始余额');

    await t.enterText(amountField, '1500');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('保存修改').first);
    await t.pumpAndSettle();
    await t.tap(find.text('保存修改').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    expect(await balanceOf(db, cardId), 150000, reason: '欠款编辑落库');
    final row = await (db.select(db.accounts)
          ..where((a) => a.id.equals(cardId)))
        .getSingle();
    expect(row.initialBalanceCents, 500000, reason: '初始余额不动');
  });
}
