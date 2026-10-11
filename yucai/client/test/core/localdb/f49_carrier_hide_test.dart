// F49 载体户隐藏存量修复验证(FR-2 三场景 + 幂等):并入型载体(名下
// card_loan 借入债挂接卡,collectionAccountId 非空)置 is_system;孤儿
// (notes 精确匹配 + 余额 0 + 无账单日 + 名下无任何 card_loan 借入债)关闭
// (status=2=archived,账户页关闭语义);非零孤儿/带账单日独立户/解挂债
// 仍存户不动。marker 'f49_carrier_hide_v1' 幂等。风格照 e_dai_unhook_test。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_f49_carrier_hide');
    file = File('${dir.path}/fix.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  // 载体/独立贷款户种子(liability=2,category=7;status 1=active)。
  Future<void> acc(
    AppDatabase db,
    String id,
    String name, {
    String notes = '',
    int balance = 0,
    int? billingDay,
  }) =>
      db.accountDao.insertAccount(AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: 2,
        category: 7,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: balance,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: notes,
        goldProductType: '',
        status: 1,
        version: 1,
        creditBillingDay:
            billingDay == null ? const Value.absent() : Value(billingDay),
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      ));

  Future<void> debt(AppDatabase db, String id, String accountId,
          String? collection) =>
      db.debtDao.insertDebt(DebtsCompanion.insert(
        id: id,
        accountId: accountId,
        counterparty: '平安银行',
        interestRate: 0.05,
        amortizationMethod: 1,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 1000000,
        debtType: 1,
        subtype: 'card_loan',
        contact: '',
        contractRef: '',
        collectionAccountId:
            collection == null ? const Value.absent() : Value(collection),
        version: 1,
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      ));

  Future<void> seed() async {
    final db = AppDatabase(NativeDatabase(file));
    // 场景A:平安并入型(挂接卡)→ 标记;e招贷(解挂,collection NULL)→ 不置位。
    await acc(db, 'pazq', '平安现金分期', notes: '信用卡贷款(卡贷)自动创建');
    await acc(db, 'edai', '招行e招贷');
    await debt(db, 'd3', 'pazq', 'card');
    await debt(db, 'd1', 'edai', null);
    // 场景B:孤儿(三重门全过 + 名下无任何 card_loan 债)→ 关闭。
    await acc(db, 'orphan', '广发财智金', notes: '信用卡贷款(卡贷)自动创建');
    // 场景C:非零孤儿 / 带账单日独立户 / 解挂债仍存户 → 不动。
    await acc(db, 'orphanNz', '平安现金分期二期',
        notes: '信用卡贷款(卡贷)自动创建', balance: 840000);
    await acc(db, 'indep', '招行e招贷二期',
        notes: '信用卡贷款(卡贷)自动创建', billingDay: 5);
    await acc(db, 'unhooked', '广发财智金二期', notes: '信用卡贷款(卡贷)自动创建');
    await debt(db, 'd2', 'unhooked', null);
    await db.close();
  }

  // seed 阶段 beforeOpen 已在空库上置过标记;删标记后显式跑被测修复。
  Future<AppDatabase> openAndArm() async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.customStatement(
        "DELETE FROM app_meta WHERE key = 'f49_carrier_hide_v1'");
    await runF49CarrierHideRepair(db);
    return db;
  }

  // (isSystem, status, updatedAt) 全量快照 —— 幂等零变化断言用。
  Future<Map<String, (int, int, String)>> snapshot(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id, is_system, status, updated_at u '
            'FROM accounts')
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): (
          r.read<int>('is_system'),
          r.read<int>('status'),
          r.read<String>('u'),
        ),
    };
  }

  test('场景A 并入型载体置 isSystem,解挂的 e招贷不置位', () async {
    await seed();
    final db = await openAndArm();
    final s = await snapshot(db);
    expect(s['pazq']!.$1, 1, reason: '挂接卡贷的载体户 isSystem=1');
    expect(s['pazq']!.$2, 1, reason: '载体户名下债仍存,不关闭');
    expect(s['edai']!.$1, 0, reason: 'e招贷解挂(collection NULL)不置位');
  });

  test('场景B 孤儿载体关闭(status=2 archived)', () async {
    await seed();
    final db = await openAndArm();
    final s = await snapshot(db);
    expect(s['orphan']!.$2, 2, reason: '孤儿载体关闭 status=2(archived)');
    expect(s['orphan']!.$1, 0, reason: '孤儿名下无债,不触发标记');
  });

  test('场景C 非零孤儿/带账单日独立户/解挂债仍存户不动', () async {
    await seed();
    final db = await openAndArm();
    final s = await snapshot(db);
    expect(s['orphanNz']!.$1, 0, reason: '非零余额孤儿不置位');
    expect(s['orphanNz']!.$2, 1, reason: '非零余额孤儿不关闭');
    expect(s['indep']!.$1, 0, reason: '带账单日独立户不置位');
    expect(s['indep']!.$2, 1, reason: '带账单日独立户不关闭');
    expect(s['unhooked']!.$1, 0, reason: '解挂债仍存户不置位');
    expect(s['unhooked']!.$2, 1,
        reason: '名下仍有 card_loan 借入债(解挂),非孤儿不关闭');
  });

  test('幂等:二次运行零变化(marker 门控)', () async {
    await seed();
    final db = await openAndArm();
    final before = await snapshot(db);

    await runF49CarrierHideRepair(db); // 标记已置 → 直接 return。

    final marker = await (db.select(db.appMeta)
          ..where((t) => t.key.equals('f49_carrier_hide_v1')))
        .getSingleOrNull();
    expect(marker, isNotNull, reason: '标记在,二次执行被门控');
    expect(await snapshot(db), before, reason: '全行零变化(含 updated_at)');
  });
}
