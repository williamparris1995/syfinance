import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/debt_dao.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// Guest-mode data source for the debt module (R6, C-paradigm).
///
/// Double-entry linkage mirrors the server (debt_handler.go:450-462 and
/// buildCreateEntries): repayment borrowedIn = credit from + debit debt
/// account, repayment borrowedOut = debit from + credit debt account;
/// borrowedOut create = credit source (cash−) + debit receivable+.
@LazySingleton()
class DebtLocalDataSource {
  DebtLocalDataSource(this._database, this._txns, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final TransactionLocalDataSource _txns;
  final Uuid _uuid;

  DebtDao get _dao => _database.debtDao;

  Future<List<Debt>> list({DebtType? typeFilter}) async {
    final rows = await _dao.watchAllDebts().first;
    final debts = <Debt>[];
    for (final r in rows) {
      if (typeFilter != null && r.debtType != typeFilter.index + 1) continue;
      debts.add(await _toEntity(r));
    }
    return debts;
  }

  Future<DebtDetail> get(String id) async {
    final row = await _require(id);
    final schedule = await _dao.watchScheduleByDebt(id).first;
    return DebtDetail(
      debt: await _toEntity(row),
      schedule: schedule.map(_paymentView).toList(),
    );
  }

  Future<Debt> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex,
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
    String contact = '',
    String contractRef = '',
    String? collectionAccountId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _dao.insertDebt(db.DebtsCompanion.insert(
        id: id,
        accountId: accountId,
        counterparty: counterparty,
        interestRate: interestRate,
        amortizationMethod: amortizationIndex + 1,
        startDate: DateTime.utc(startDate.year, startDate.month, startDate.day),
        dueDate: DateTime.utc(dueDate.year, dueDate.month, dueDate.day),
        totalPrincipalCents: totalPrincipalCents,
        debtType: type.index + 1,
        subtype: subtype,
        contact: contact,
        contractRef: contractRef,
        collectionAccountId: Value(collectionAccountId),
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      // Amortization schedule at create (server GenerateSchedule): three
      // methods copied verbatim from debt/domain/service.go.
      for (final e in _generateSchedule(
        debtId: id,
        method: amortizationIndex,
        startDate: DateTime.utc(startDate.year, startDate.month, startDate.day),
        dueDate: DateTime.utc(dueDate.year, dueDate.month, dueDate.day),
        totalPrincipalCents: totalPrincipalCents,
        interestRate: interestRate,
      )) {
        await _dao.insertScheduleEntry(e);
      }
      // borrowedOut create double-writes cash out (server buildCreateEntries):
      // credit source (cash−) + debit receivable account (+).
      if (type == DebtType.borrowedOut && (sourceAccountId ?? '').isNotEmpty) {
        final src = await _database.accountDao.getAccountById(sourceAccountId!);
        if (src == null) throw ServerFailure('资金账户不存在');
        await _txns.recordTransaction(RecordTransactionParams(
          transactionDate:
              DateTime.utc(startDate.year, startDate.month, startDate.day),
          description: '借出 $counterparty',
          entries: [
            TransactionEntry(
                accountId: sourceAccountId!,
                debitCents: 0,
                creditCents: totalPrincipalCents),
            TransactionEntry(
                accountId: accountId,
                debitCents: totalPrincipalCents,
                creditCents: 0),
          ],
        ));
      }
    });
    return _toEntity(await _require(id));
  }

  Future<Debt> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
    String contact = '',
    String contractRef = '',
    String? collectionAccountId,
  }) async {
    final row = await _require(id);
    if (row.version != version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    await _dao.updateDebt(db.DebtsCompanion(
      id: Value(id),
      counterparty: Value(counterparty),
      interestRate: Value(interestRate),
      contact: Value(contact),
      contractRef: Value(contractRef),
      collectionAccountId: Value(collectionAccountId),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    return _toEntity(await _require(id));
  }

  Future<void> delete(String id) async {
    if (await _dao.getDebtById(id) == null) throw const ServerFailure('债务不存在');
    await _dao.deleteDebtById(id); // schedule cascades
  }

  Future<PaymentEntry> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  }) async {
    final row = await _require(debtId);
    final schedule = await _dao.watchScheduleByDebt(debtId).first;
    final entry = schedule.where((s) => s.id == scheduleEntryId).firstOrNull;
    if (entry == null) throw const ServerFailure('还款期次不存在');
    if (entry.paid) throw const ServerFailure('该期次已还款');

    late PaymentEntry paid;
    await _database.transaction(() async {
      // Double-entry repayment (server debt_handler.go:450-462):
      // borrowedIn = credit from + debit debt (liability−);
      // borrowedOut = debit from + credit debt (receivable−).
      final isBorrowedIn = row.debtType == DebtType.borrowedIn.index + 1;
      final txn = await _txns.recordTransaction(RecordTransactionParams(
        transactionDate: entry.paymentDate,
        description: '还款 $counterpartyOf(row)',
        entries: [
          TransactionEntry(
              accountId: isBorrowedIn ? row.accountId : fromAccountId,
              debitCents: entry.totalCents,
              creditCents: 0),
          TransactionEntry(
              accountId: isBorrowedIn ? fromAccountId : row.accountId,
              debitCents: 0,
              creditCents: entry.totalCents),
        ],
      ));
      await _dao.updateScheduleEntry(db.PaymentScheduleEntriesCompanion(
        id: Value(scheduleEntryId),
        paid: const Value(true),
        paidCents: Value(entry.totalCents),
        transactionId: Value(txn.id),
      ));
      paid = _paymentView(
          (await _dao.getScheduleEntryById(scheduleEntryId))!);
    });
    return paid;
  }

  Future<List<Debt>> upcomingPayments(int daysAhead) async {
    final rows = await _dao.watchAllDebts().first;
    final deadline = DateTime.now().toUtc().add(Duration(days: daysAhead));
    final out = <Debt>[];
    for (final r in rows) {
      final e = await _toEntity(r);
      if (e.nextPaymentDate != null && !e.nextPaymentDate!.isAfter(deadline)) {
        out.add(e);
      }
    }
    return out;
  }

  // ---- amortization (server debt/domain/service.go, verbatim) ----

  List<db.PaymentScheduleEntriesCompanion> _generateSchedule({
    required String debtId,
    required int method, // AmortizationMethod.index
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required double interestRate,
  }) {
    switch (method) {
      case 2: // lumpSum
        return _lumpSum(debtId, startDate, dueDate, totalPrincipalCents, interestRate);
      case 1: // equalPrincipal
        return _equalPrincipal(debtId, startDate, dueDate, totalPrincipalCents, interestRate);
      default: // equalPrincipalInterest (and unknown → default, server same)
        return _equalInstallment(debtId, startDate, dueDate, totalPrincipalCents, interestRate);
    }
  }

  int _termInMonths(DateTime start, DateTime due) {
    final months = (due.year - start.year) * 12 + due.month - start.month;
    return months <= 0 ? 1 : months;
  }

  DateTime _addMonthsClamped(DateTime t, int months) {
    final total = t.month + months;
    var year = t.year + (total - 1) ~/ 12;
    var month = (total - 1) % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = t.day > lastDay ? lastDay : t.day;
    return DateTime.utc(year, month, day);
  }

  List<db.PaymentScheduleEntriesCompanion> _lumpSum(String debtId,
      DateTime start, DateTime due, int principal, double rate) {
    final months = _termInMonths(start, due);
    final interest = (principal * rate * months / 12.0).round();
    return [
      db.PaymentScheduleEntriesCompanion.insert(
        id: _uuid.v4(),
        debtId: debtId,
        paymentDate: due,
        principalCents: principal,
        interestCents: interest,
        totalCents: principal + interest,
        paidCents: 0,
        paid: false,
      )
    ];
  }

  List<db.PaymentScheduleEntriesCompanion> _equalPrincipal(String debtId,
      DateTime start, DateTime due, int principal, double rate) {
    final months = _termInMonths(start, due);
    final monthlyRate = rate / 12.0;
    final monthlyPrincipal = principal ~/ months;
    var remaining = principal.toDouble();
    final out = <db.PaymentScheduleEntriesCompanion>[];
    for (var i = 0; i < months; i++) {
      final interest = (remaining * monthlyRate).round();
      final principalPart =
          i == months - 1 ? remaining.round() : monthlyPrincipal;
      out.add(db.PaymentScheduleEntriesCompanion.insert(
        id: _uuid.v4(),
        debtId: debtId,
        paymentDate: _addMonthsClamped(start, i + 1),
        principalCents: principalPart,
        interestCents: interest,
        totalCents: principalPart + interest,
        paidCents: 0,
        paid: false,
      ));
      remaining -= principalPart;
    }
    return out;
  }

  List<db.PaymentScheduleEntriesCompanion> _equalInstallment(String debtId,
      DateTime start, DateTime due, int principal, double rate) {
    final months = _termInMonths(start, due);
    final monthlyRate = rate / 12.0;
    final p = principal.toDouble();
    double payment;
    if (monthlyRate == 0) {
      payment = p / months;
    } else {
      final factor = _pow(1 + monthlyRate, months);
      payment = p * monthlyRate * factor / (factor - 1);
    }
    var remaining = p;
    final out = <db.PaymentScheduleEntriesCompanion>[];
    for (var i = 0; i < months; i++) {
      final interest = (remaining * monthlyRate).round();
      final principalPart =
          i == months - 1 ? remaining.round() : payment.round() - interest;
      out.add(db.PaymentScheduleEntriesCompanion.insert(
        id: _uuid.v4(),
        debtId: debtId,
        paymentDate: _addMonthsClamped(start, i + 1),
        principalCents: principalPart,
        interestCents: interest,
        totalCents: principalPart + interest,
        paidCents: 0,
        paid: false,
      ));
      remaining -= principalPart;
    }
    return out;
  }

  double _pow(double base, int exp) {
    var r = 1.0;
    for (var i = 0; i < exp; i++) {
      r *= base;
    }
    return r;
  }

  // ---- helpers ----

  String counterpartyOf(db.Debt row) => row.counterparty;

  Future<db.Debt> _require(String id) async {
    final row = await _dao.getDebtById(id);
    if (row == null) throw const ServerFailure('债务不存在');
    return row;
  }

  PaymentEntry _paymentView(db.PaymentScheduleEntry s) => PaymentEntry(
        id: s.id,
        paymentDate: s.paymentDate,
        principalCents: s.principalCents,
        interestCents: s.interestCents,
        totalCents: s.totalCents,
        paid: s.paid,
        paidCents: s.paidCents,
        transactionId: s.transactionId ?? '',
      );

  Future<Debt> _toEntity(db.Debt r) async {
    final schedule = await _dao.watchScheduleByDebt(r.id).first;
    final unpaid = schedule.where((s) => !s.paid).toList()
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final next = unpaid.firstOrNull;
    final paidCents = schedule.fold(0, (a, s) => a + s.paidCents);
    return Debt(
      id: r.id,
      accountId: r.accountId,
      counterparty: r.counterparty,
      interestRate: r.interestRate,
      amortization: AmortizationMethod.values[r.amortizationMethod - 1],
      startDate: r.startDate,
      dueDate: r.dueDate,
      totalPrincipalCents: r.totalPrincipalCents,
      remainingPrincipalCents: r.totalPrincipalCents - paidCents,
      version: r.version,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      type: DebtType.values[r.debtType - 1],
      subtype: r.subtype,
      contact: r.contact,
      contractRef: r.contractRef,
      collectionAccountId: r.collectionAccountId,
      nextPaymentDate: next?.paymentDate,
      nextPaymentAmountCents: next?.totalCents ?? 0,
      nextPaymentPeriodNo: next == null ? 0 : schedule.indexOf(next) + 1,
      remainingTrendCents: r.totalPrincipalCents - paidCents,
    );
  }
}
