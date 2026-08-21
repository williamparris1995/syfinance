import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/debt_tables.dart';

part 'debt_dao.g.dart';

@DriftAccessor(tables: [Debts, PaymentScheduleEntries])
class DebtDao extends DatabaseAccessor<AppDatabase> with _$DebtDaoMixin {
  DebtDao(super.db);

  Future<void> insertDebt(DebtsCompanion entry) => into(debts).insert(entry);

  Future<Debt?> getDebtById(String id) =>
      (select(debts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Debt>> watchAllDebts() => select(debts).watch();

  Future<int> updateDebt(DebtsCompanion entry) =>
      (update(debts)..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<int> deleteDebtById(String id) =>
      (delete(debts)..where((t) => t.id.equals(id))).go();

  Future<void> insertScheduleEntry(PaymentScheduleEntriesCompanion entry) =>
      into(paymentScheduleEntries).insert(entry);

  Stream<List<PaymentScheduleEntry>> watchScheduleByDebt(String debtId) =>
      (select(paymentScheduleEntries)
            ..where((t) => t.debtId.equals(debtId)))
          .watch();
}
