import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/core/localdb/daos/transaction_dao.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// Guest-mode data source for the transaction module (R6, C-paradigm).
///
/// Server semantics mirrored verbatim (design.md header):
///  - Simple* entry directions: expense = debit expense/credit asset,
///    income = debit asset/credit income, transfer = debit to/credit from.
///  - summary amounts: income accounts contribute credit, expense accounts
///    contribute debit, everything else 0; dailyAvg = net / distinct active
///    days, month scope only (year scope buckets by day=month, day scope is
///    a single bucket — both leave dailyAvg 0).
@LazySingleton()
class TransactionLocalDataSource {
  TransactionLocalDataSource(this._database, this._balances, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final BalanceLocalUpdater _balances;
  final Uuid _uuid;

  TransactionDao get _dao => _database.transactionDao;
  AccountDao get _accounts => _database.accountDao;

  // ---- writes ----

  Future<Transaction> recordExpense(RecordExpenseParams p) =>
      _insertWithEntries(
        p.transactionDate,
        p.description,
        p.transactionTime,
        _pair(p.expenseAccountId, p.assetAccountId, p.amountCents, p.note),
      );

  Future<Transaction> recordIncome(RecordIncomeParams p) =>
      _insertWithEntries(
        p.transactionDate,
        p.description,
        p.transactionTime,
        _pair(p.assetAccountId, p.incomeAccountId, p.amountCents, p.note),
      );

  Future<Transaction> recordTransfer(RecordTransferParams p) =>
      _insertWithEntries(
        p.transactionDate,
        p.description,
        p.transactionTime,
        _pair(p.toAccountId, p.fromAccountId, p.amountCents, p.note),
      );

  Future<Transaction> recordTransaction(RecordTransactionParams p) =>
      _insertWithEntries(
        p.transactionDate,
        p.description,
        '',
        p.entries,
      );

  /// Head + entries written inside ONE drift transaction: a mid-batch
  /// failure (e.g. unknown account id) rolls the whole packet back.
  Future<Transaction> _insertWithEntries(
    DateTime date,
    String description,
    String transactionTime,
    List<TransactionEntry> entries,
  ) async {
    if (entries.isEmpty) {
      throw const ValidationFailure('至少需要一条分录');
    }
    var sumDebit = 0, sumCredit = 0;
    for (final e in entries) {
      final positive = (e.debitCents > 0) != (e.creditCents > 0);
      if (!positive || (e.debitCents == 0 && e.creditCents == 0)) {
        throw const ValidationFailure('分录借贷必须恰一方大于零');
      }
      sumDebit += e.debitCents;
      sumCredit += e.creditCents;
    }
    // DoubleEntryValidator mirror: Σdebit == Σcredit.
    if (sumDebit != sumCredit) {
      throw const ValidationFailure('分录借贷总额必须相等');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _dao.insertTransaction(db.TransactionsCompanion.insert(
        id: id,
        transactionDate: date,
        transactionTime: Value(_parseTime(transactionTime)),
        description: description,
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      for (final e in entries) {
        await _dao.insertEntry(db.TransactionEntriesCompanion.insert(
          id: e.id.isEmpty ? _uuid.v4() : e.id,
          transactionId: id,
          accountId: e.accountId,
          chartOfAccountCode: '',
          debitCents: e.debitCents,
          creditCents: e.creditCents,
          note: e.note,
        ));
      }
      // Balance linkage (design ADR-1): same tx; a missing account throws
      // and rolls the whole write back.
      final written =
          await _dao.watchEntriesByTransaction(id).first;
      await _balances.applyEntries(written, 1);
    });
    return await getById(id);
  }

  List<TransactionEntry> _pair(
      String debitAccountId, String creditAccountId, int amountCents,
      [String note = '']) => [
        TransactionEntry(
            accountId: debitAccountId,
            debitCents: amountCents,
            creditCents: 0,
            note: note),
        TransactionEntry(
            accountId: creditAccountId,
            debitCents: 0,
            creditCents: amountCents,
            note: note),
      ];

  // ---- reads ----

  Future<ListTransactionsResult> list(ListTransactionsParams p) async {
    final all = await _assembleAll();
    var filtered = all.where((t) {
      if (p.accountId != null &&
          !t.entries.any((e) => e.accountId == p.accountId)) {
        return false;
      }
      if (p.dateFrom != null && t.transactionDate.isBefore(p.dateFrom!)) {
        return false;
      }
      if (p.dateTo != null && t.transactionDate.isAfter(p.dateTo!)) {
        return false;
      }
      if (p.typeFilter != null && inferFlavour(t) != p.typeFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final byDate = b.transactionDate.compareTo(a.transactionDate);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

    final offset = int.tryParse(p.pageToken ?? '') ?? 0;
    final pageSize = p.pageSize <= 0 ? 100 : p.pageSize;
    final end = (offset + pageSize).clamp(0, filtered.length);
    final page = offset >= filtered.length ? <Transaction>[] : filtered.sublist(offset, end);
    return ListTransactionsResult(
      transactions: page,
      nextPageToken: end < filtered.length ? '$end' : '',
      totalCount: filtered.length,
    );
  }

  Future<Transaction> getById(String id) async {
    final head = await _dao.getTransactionById(id);
    if (head == null) throw const ServerFailure('交易不存在');
    final entries = (await _dao.watchEntriesByTransaction(id).first)
        .map((e) => TransactionEntry(
              id: e.id,
              accountId: e.accountId,
              debitCents: e.debitCents,
              creditCents: e.creditCents,
              note: e.note,
            ))
        .toList();
    return _toEntity(head, entries);
  }

  // ---- update / delete ----

  Future<Transaction> update(UpdateTransactionParams p) async {
    final head = await _dao.getTransactionById(p.id);
    if (head == null) throw const ServerFailure('交易不存在');
    if (head.version != p.version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    final entries = p.entries;
    if (entries.isEmpty) {
      throw const ValidationFailure('至少需要一条分录');
    }
    // Balance-linked update validates the NEW packet like the server's
    // DoubleEntryValidator (service.go:276) — balances are real now, an
    // unbalanced packet would move assets out of thin air.
    var sumDebit = 0, sumCredit = 0;
    for (final e in entries) {
      final positive = (e.debitCents > 0) != (e.creditCents > 0);
      if (!positive || (e.debitCents == 0 && e.creditCents == 0)) {
        throw const ValidationFailure('分录借贷必须恰一方大于零');
      }
      sumDebit += e.debitCents;
      sumCredit += e.creditCents;
    }
    if (sumDebit != sumCredit) {
      throw const ValidationFailure('分录借贷总额必须相等');
    }
    await _database.transaction(() async {
      // Reverse the OLD entries' balance effect first (server update =
      // ReverseBalances(old) + UpdateBalances(new), same tx).
      final oldEntries =
          await _dao.watchEntriesByTransaction(p.id).first;
      await _balances.applyEntries(oldEntries, -1);
      await _dao.updateTransaction(db.TransactionsCompanion(
        id: Value(p.id),
        transactionDate: Value(p.transactionDate ?? head.transactionDate),
        description: Value(p.description), // full-replace, mirrors remote
        version: Value(head.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      // Whole-entry-set replacement (design ADR-1).
      await _dao.deleteEntriesByTransaction(p.id);
      for (final e in entries) {
        await _dao.insertEntry(db.TransactionEntriesCompanion.insert(
          id: e.id.isEmpty ? _uuid.v4() : e.id,
          transactionId: p.id,
          accountId: e.accountId,
          chartOfAccountCode: '',
          debitCents: e.debitCents,
          creditCents: e.creditCents,
          note: e.note,
        ));
      }
      final written = await _dao.watchEntriesByTransaction(p.id).first;
      await _balances.applyEntries(written, 1);
    });
    return (await getById(p.id));
  }

  Future<void> delete(String id) async {
    if (await _dao.getTransactionById(id) == null) {
      throw const ServerFailure('交易不存在');
    }
    await _database.transaction(() async {
      // Reverse the balance effect before the rows cascade away (server
      // delete = ReverseBalances(old), same tx).
      final oldEntries = await _dao.watchEntriesByTransaction(id).first;
      await _balances.applyEntries(oldEntries, -1);
      await _dao.deleteTransactionById(id); // entries cascade via FK
    });
  }

  // ---- summary (server CASE semantics mirrored) ----

  Future<MonthlySummary> summary(
    int year,
    int month, {
    String? accountId,
    SummaryScope scope = SummaryScope.month,
    int? day,
  }) async {
    final window = _windowFor(year, month, scope, day);
    final accounts = {
      for (final a in await _accounts.getAllAccounts())
        a.id: a.accountType, // contract int: 1 asset .. 4 income 5 expense
    };
    final all = await _assembleAll();
    final scoped = all.where((t) {
      if (t.transactionDate.isBefore(window.$1) ||
          !t.transactionDate.isBefore(window.$2)) {
        return false;
      }
      if (accountId != null &&
          !t.entries.any((e) => e.accountId == accountId)) {
        return false;
      }
      return true;
    });

    var income = 0, expense = 0;
    final dayBuckets = <String, Map<String, int>>{}; // date -> {accountId: amt}
    final catNames = <String, (String, int)>{};

    for (final t in scoped) {
      for (final e in t.entries) {
        final type = accounts[e.accountId];
        int amount;
        if (type == 4) {
          amount = e.creditCents; // income accounts: credit side counts
        } else if (type == 5) {
          amount = e.debitCents; // expense accounts: debit side counts
        } else {
          continue;
        }
        if (type == 4) {
          income += amount;
        } else {
          expense += amount;
        }
        final key = _bucketKey(t.transactionDate, scope);
        dayBuckets.putIfAbsent(key, () => {});
        dayBuckets[key]![e.accountId] =
            (dayBuckets[key]![e.accountId] ?? 0) + amount;
        catNames.putIfAbsent(
            e.accountId, () => ('', type ?? 0));
      }
    }
    // Account display names for the category buckets.
    for (final a in await _accounts.getAllAccounts()) {
      if (catNames.containsKey(a.id)) catNames[a.id] = (a.name, catNames[a.id]!.$2);
    }

    final byDay = dayBuckets.entries.map((d) {
      final cats = d.value.entries.map((c) => CategoryTotal(
            categoryId: c.key,
            name: catNames[c.key]?.$1 ?? '',
            accountType: catNames[c.key]?.$2 == 4 ? 'income' : 'expense',
            amountCents: c.value,
          )).toList()
        ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
      return DailySummary(
        date: d.key,
        totalIncomeCents:
            d.value.entries.where((c) => catNames[c.key]?.$2 == 4).map((c) => c.value).fold(0, (a, b) => a + b),
        byCategory: cats,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final net = income - expense;
    // dailyAvg: net / distinct active days, month scope only (server rule).
    var dailyAvg = 0;
    if (scope == SummaryScope.month && byDay.isNotEmpty) {
      dailyAvg = net ~/ byDay.length;
    }
    return MonthlySummary(
      year: year,
      month: month,
      incomeCents: income,
      expenseCents: expense,
      netCents: net,
      dailyAvgCents: dailyAvg,
      byDay: byDay,
      scope: scope,
    );
  }

  (DateTime, DateTime) _windowFor(
      int year, int month, SummaryScope scope, int? day) {
    if (scope == SummaryScope.day) {
      final start = DateTime.utc(year, month, day ?? 1);
      return (start, start.add(const Duration(days: 1)));
    }
    if (scope == SummaryScope.year) {
      return (DateTime.utc(year), DateTime.utc(year + 1));
    }
    final start = DateTime.utc(year, month);
    return (start, DateTime.utc(year, month + 1));
  }

  String _bucketKey(DateTime date, SummaryScope scope) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    // Year scope buckets per month; 'YYYY-MM-01' keeps the key parseable by
    // DateTime.parse like the server's daily keys.
    return scope == SummaryScope.year
        ? '${date.year}-$m-01'
        : '${date.year}-$m-$d';
  }

  // ---- helpers ----

  Future<List<Transaction>> _assembleAll() async {
    final heads = await _dao.getAllTransactions();
    if (heads.isEmpty) return [];
    final entriesByTxn = <String, List<TransactionEntry>>{};
    for (final e in await _dao.getAllEntries()) {
      entriesByTxn.putIfAbsent(e.transactionId, () => []).add(TransactionEntry(
            id: e.id,
            accountId: e.accountId,
            debitCents: e.debitCents,
            creditCents: e.creditCents,
            note: e.note,
          ));
    }
    return heads
        .map((h) => _toEntity(h, entriesByTxn[h.id] ?? []))
        .toList();
  }

  Transaction _toEntity(db.Transaction head, List<TransactionEntry> entries) =>
      Transaction(
        id: head.id,
        transactionDate: head.transactionDate,
        description: head.description,
        entries: entries,
        version: head.version,
        transactionTime: head.transactionTime,
        createdAt: head.createdAt,
        updatedAt: head.updatedAt,
      );

  DateTime? _parseTime(String rfc3339) =>
      rfc3339.isEmpty ? null : DateTime.tryParse(rfc3339);
}
