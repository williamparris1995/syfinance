import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/budget_dao.dart';
import 'package:yucai_client/core/localdb/daos/transaction_dao.dart';

/// Guest-mode data source for the budget module (R6, C-paradigm).
///
/// Actuals are computed at READ time with the server's exact rule
/// (budget/domain/repository.go:45-59): per item, sum debit and credit of
/// that account's entries in the month window, then take the LARGER of the
/// two as the "spending direction".
@LazySingleton()
class BudgetLocalDataSource {
  BudgetLocalDataSource(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final Uuid _uuid;

  BudgetDao get _dao => _database.budgetDao;
  TransactionDao get _txns => _database.transactionDao;

  Future<List<BudgetView>> listBudgets({bool activeOnly = false}) async {
    final rows = await _dao.watchAllBudgets().first;
    final views = <BudgetView>[];
    for (final r in rows.where((r) => !activeOnly || r.isActive)) {
      views.add(await _detail(r));
    }
    return views;
  }

  Future<BudgetView> getBudget(String id) async =>
      _detail(await _dao.getBudgetById(id));

  Future<BudgetView> getBudgetByMonth(String month) async {
    final rows = await _dao.watchAllBudgets().first;
    final row = rows.where((r) => r.month == month).firstOrNull;
    if (row == null) throw const ServerFailure('该月份无预算');
    return _detail(row);
  }

  Future<BudgetView> createBudget({
    required String name,
    required String month,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})>
        items,
  }) async {
    _validateMonth(month);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _dao.insertBudget(db.BudgetsCompanion.insert(
        id: id,
        name: name,
        month: month,
        totalAmountCents: items.fold(0, (a, i) => a + i.plannedAmountCents),
        currencyCode: currencyCode,
        isActive: true,
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await _insertItems(id, items);
    });
    return getBudget(id);
  }

  Future<void> deleteBudget(String id) async {
    if (await _dao.getBudgetById(id) == null) throw const ServerFailure('预算不存在');
    await _dao.deleteBudgetById(id); // items cascade
  }

  Future<BudgetView> addItem({
    required String budgetId,
    required String accountId,
    required int plannedAmountCents,
    String? notes,
  }) async {
    final row = await _require(budgetId);
    await _database.transaction(() async {
      await _dao.insertItem(db.BudgetItemsCompanion.insert(
        id: _uuid.v4(),
        budgetId: budgetId,
        accountId: accountId,
        plannedAmountCents: plannedAmountCents,
        actualAmountCents: 0,
        notes: notes ?? '',
      ));
      await _touch(row, row.totalAmountCents + plannedAmountCents);
    });
    return getBudget(budgetId);
  }

  Future<BudgetView> removeItem({
    required String budgetId,
    required String itemId,
  }) async {
    final row = await _require(budgetId);
    final items = await _dao.watchItemsByBudget(budgetId).first;
    final target = items.where((i) => i.id == itemId).firstOrNull;
    if (target == null) throw const ServerFailure('预算项不存在');
    await _database.transaction(() async {
      await _dao.deleteItemById(itemId);
      await _touch(row, row.totalAmountCents - target.plannedAmountCents);
    });
    return getBudget(budgetId);
  }

  Future<BudgetView> updateBudget({
    required String id,
    required String name,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})>
        items,
  }) async {
    final row = await _require(id);
    await _database.transaction(() async {
      // Whole-set replacement (server: month immutable, items fully replaced).
      await _dao.deleteItemsByBudget(id);
      await _insertItems(id, items);
      await _touch(row, items.fold(0, (a, i) => a + i.plannedAmountCents),
          name: name, currencyCode: currencyCode);
    });
    return getBudget(id);
  }

  // ---- helpers ----

  Future<BudgetView> _detail(db.Budget? row) async {
    if (row == null) throw const ServerFailure('预算不存在');
    final itemRows = await _dao.watchItemsByBudget(row.id).first;
    if (itemRows.isEmpty) return _toView(row, const []);

    // Read-time actuals: per item, max(Σdebit, Σcredit) over the account's
    // entries in the month window (server rule, design ADR-3).
    final heads = await _txns.getAllTransactions();
    final entries = await _txns.getAllEntries();
    final dateOf = {for (final h in heads) h.id: h.transactionDate};
    final (from, to) = _monthWindow(row.month);
    final sums = <String, (int, int)>{};
    for (final e in entries) {
      final date = dateOf[e.transactionId];
      if (date == null || date.isBefore(from) || !date.isBefore(to)) continue;
      final (d, c) = sums[e.accountId] ?? (0, 0);
      sums[e.accountId] = (d + e.debitCents, c + e.creditCents);
    }
    final accounts = await _database.accountDao.getAllAccounts();
    final nameOf = {for (final a in accounts) a.id: a.name};

    final items = itemRows.map((i) {
      final (d, c) = sums[i.accountId] ?? (0, 0);
      final actual = d > c ? d : c; // server: larger side wins
      return BudgetItemView(
        id: i.id,
        accountId: i.accountId,
        accountName: nameOf[i.accountId],
        plannedAmountCents: i.plannedAmountCents,
        actualAmountCents: actual,
        notes: i.notes.isEmpty ? null : i.notes,
      );
    }).toList();
    return _toView(row, items);
  }

  (DateTime, DateTime) _monthWindow(String month) {
    final parts = month.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return (DateTime.utc(y, m), DateTime.utc(y, m + 1));
  }

  Future<db.Budget> _require(String id) async {
    final row = await _dao.getBudgetById(id);
    if (row == null) throw const ServerFailure('预算不存在');
    return row;
  }

  Future<void> _insertItems(
      String budgetId,
      List<({String accountId, int plannedAmountCents, String? notes})>
          items) async {
    for (final i in items) {
      await _dao.insertItem(db.BudgetItemsCompanion.insert(
        id: _uuid.v4(),
        budgetId: budgetId,
        accountId: i.accountId,
        plannedAmountCents: i.plannedAmountCents,
        actualAmountCents: 0,
        notes: i.notes ?? '',
      ));
    }
  }

  Future<void> _touch(db.Budget row, int newTotal,
      {String? name, String? currencyCode}) async {
    await _dao.updateBudget(db.BudgetsCompanion(
      id: Value(row.id),
      name: Value(name ?? row.name),
      currencyCode: Value(currencyCode ?? row.currencyCode),
      totalAmountCents: Value(newTotal),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  void _validateMonth(String month) {
    final ok = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month);
    if (!ok) throw const ValidationFailure('月份格式应为 YYYY-MM');
  }

  BudgetView _toView(db.Budget row, List<BudgetItemView> items) {
    final totalActual = items.fold(0, (a, i) => a + i.actualAmountCents);
    return BudgetView(
      id: row.id,
      name: row.name,
      month: row.month,
      currencyCode: row.currencyCode,
      totalAmountCents: row.totalAmountCents,
      totalActualCents: totalActual,
      usagePct: row.totalAmountCents == 0
          ? 0
          : totalActual * 100 / row.totalAmountCents,
      items: items,
    );
  }
}
