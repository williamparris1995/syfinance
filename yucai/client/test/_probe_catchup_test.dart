// 临时探针(跑完即删):对真库副本直接跑 catchupCardLoanMerges,隔离
// 「代码不并」vs「app 触发链问题」。目标债 1bc53282(平安 35k,counts=0,
// 首未还 09-12,到期=10-12 已过)——F61 删 skip 后应并入。
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

void main() {
  test('PROBE 真库副本 catchup:平安 35k(09-12 到期)应并入', () async {
    final file = File('test/_probe_pa.db');
    expect(await file.exists(), isTrue, reason: '先拷贝 _v.db → test/_probe_pa.db');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());

    Future<int> paBalance() async {
    final r = await (db.select(db.accounts)
          ..where((t) => t.name.equals('平安银行信用卡'))).getSingle();
    return r.currentBalanceCents;
  }
  final before = await paBalance();
    final debts = DebtLocalDataSource(
        db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)));

    await debts.catchupCardLoanMerges(now: DateTime(2026, 10, 14, 12));

    final all = await db.select(db.debts).get();
    final pa = all
        .where((d) =>
            d.subtype == 'card_loan' &&
            (d.collectionAccountId ?? '').isNotEmpty)
        .toList();
    for (final d in pa) {
      final sched = await (db.select(db.paymentScheduleEntries)
            ..where((t) => t.debtId.equals(d.id))
            ..orderBy([(t) => OrderingTerm.asc(t.paymentDate)]))
          .get();
      final firstUnpaid = sched.where((e) => !e.paid).toList();
      // ignore: avoid_print
      print('PROBE ${d.counterparty} ${d.id.substring(0, 8)} '
          'counts=${d.countsTowardCardLimit} '
          'firstUnpaid=${firstUnpaid.isEmpty ? "-" : firstUnpaid.first.paymentDate.toString().substring(0, 10)} '
          'paidCount=${sched.where((e) => e.paid).length}/${sched.length}');
    }
    final after = await paBalance();
    // ignore: avoid_print
    print('PROBE 平安卡 balance: before=$before '
        'after=$after');
  });
}
