// e招贷独立口径一次性修复验证:解除「e招贷」名下卡贷债的挂接卡;
// 平安/广发同型卡贷(银行口径确为并入卡账单)不动。marker
// 'card_loan_e_dai_unhook_v1' 幂等。风格照 liability_balance_repair_v2_test。
import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_edai_unhook');
    file = File('${dir.path}/fix.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> seed() async {
    final db = AppDatabase(NativeDatabase(file));
    Future<void> acc(String id, String name) =>
        db.accountDao.insertAccount(AccountsCompanion.insert(
          id: id,
          name: name,
          accountType: 2,
          category: 7,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          currentBalanceCents: 0,
          ownership: 1,
          icon: '',
          color: '',
          chartCode: '',
          isSystem: false,
          sortOrder: 0,
          institution: '',
          cardNumberTail: '',
          notes: '',
          goldProductType: '',
          status: 1,
          version: 1,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        ));
    await acc('edai', '招行e招贷');
    await acc('pazq', '平安现金分期');
    await acc('card', '招商银行信用卡');
    Future<void> debt(String id, String accountId, String subtype,
            String? collection) =>
        db.debtDao.insertDebt(DebtsCompanion.insert(
          id: id,
          accountId: accountId,
          counterparty: '招商银行',
          interestRate: 0.05,
          amortizationMethod: 1,
          startDate: DateTime.utc(2026, 1, 1),
          dueDate: DateTime.utc(2027, 1, 1),
          totalPrincipalCents: 1000000,
          debtType: 1,
          subtype: subtype,
          contact: '',
          contractRef: '',
          collectionAccountId:
              collection == null ? const Value.absent() : Value(collection),
          version: 1,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        ));
    // e招贷卡贷(挂接)→ 解除;e招贷下非卡贷债(挂接)→ subtype 过滤不动。
    await debt('d1', 'edai', 'card_loan', 'card');
    await debt('d2', 'edai', 'other', 'card');
    // 平安现金分期(挂接)→ 银行口径并入,保留。
    await debt('d3', 'pazq', 'card_loan', 'card');
    await db.close();
  }

  Future<AppDatabase> open() async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    return db;
  }

  Future<String?> collectionOf(AppDatabase db, String id) async {
    final r = await db.customSelect(
        'SELECT collection_account_id c FROM debts WHERE id = ?',
        variables: [Variable.withString(id)]).getSingle();
    return r.readNullable<String>('c');
  }

  test('e招贷卡贷解挂,非卡贷/平安分期不动,幂等', () async {
    await seed();
    final db = await open();
    await db.customStatement(
        "DELETE FROM app_meta WHERE key = 'card_loan_e_dai_unhook_v1'");
    await unhookEDaiCardMerges(db);

    expect(await collectionOf(db, 'd1'), isNull, reason: 'e招贷卡贷解挂');
    expect(await collectionOf(db, 'd2'), 'card',
        reason: 'subtype 非 card_loan 不过滤条件,不动');
    expect(await collectionOf(db, 'd3'), 'card', reason: '平安现金分期保留挂接');

    // 幂等:重跑无新变化(无异常即过,标记挡二次执行)。
    await db.customStatement(
        "DELETE FROM app_meta WHERE key = 'card_loan_e_dai_unhook_v1'");
    await unhookEDaiCardMerges(db);
    expect(await collectionOf(db, 'd3'), 'card');
  });
}
