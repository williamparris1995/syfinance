import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  test('debug raw storage', () async {
    final dir = await Directory.systemTemp.createTemp('dbg');
    final file = File('${dir.path}/dbg.db');
    final db = AppDatabase(NativeDatabase(file));
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: 'd1', accountId: 'a1', counterparty: 'X', interestRate: 0.05,
      amortizationMethod: 1, startDate: DateTime.utc(2026, 1, 1),
      dueDate: DateTime.utc(2026, 8, 1), totalPrincipalCents: 100000,
      debtType: 1, subtype: '', contact: '', contractRef: '', version: 1,
      createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1),
    ));
    await db.into(db.paymentScheduleEntries).insert(
          PaymentScheduleEntriesCompanion.insert(
            id: 's1', debtId: 'd1', paymentDate: DateTime.utc(2026, 8, 1),
            principalCents: 80000, interestCents: 4000, totalCents: 84000,
            paidCents: 84000, paid: true, transactionId: const Value('txn1'),
          ),
        );
    final raw = await db.customSelect(
      "SELECT payment_date, typeof(payment_date) t FROM payment_schedule_entries WHERE id='s1'",
    ).getSingle();
    // ignore: avoid_print
    print('DBG stored=${raw.data.values}');
    final now = DateTime.now();
    final todayMid = DateTime(now.year, now.month, now.day);
    // ignore: avoid_print
    print('DBG todayMidEpoch=${todayMid.millisecondsSinceEpoch ~/ 1000}');
    final rows = await db.customSelect(
      'SELECT COUNT(*) c FROM payment_schedule_entries WHERE transaction_id IS NOT NULL AND payment_date < ?',
      variables: [Variable.withInt(todayMid.millisecondsSinceEpoch ~/ 1000)],
    ).getSingle();
    // ignore: avoid_print
    print('DBG match=${rows.read<int>("c")}');
    await db.close();
    dir.deleteSync(recursive: true);
  });
}
