import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/template_dao.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// Guest-mode data source for the template module (R6, C-paradigm).
///
/// `record` mirrors the server's RecordTransaction (template service
/// autoRecord): one drift transaction that (1) creates the double-entry
/// transaction at nextDate with the direction-paired entries, (2) advances
/// nextDate via the same AdvanceNextDate rules, (3) bumps the version and
/// records lastTransactionId. The server's UNIQUE idempotency log targets
/// scheduler retries; the guest is a single writer, so it is intentionally
/// omitted (design ADR-4, accepted simplification).
@LazySingleton()
class TemplateLocalDataSource {
  TemplateLocalDataSource(this._database, this._txnLocal, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final TransactionLocalDataSource _txnLocal;
  final Uuid _uuid;

  TemplateDao get _dao => _database.templateDao;

  Future<List<Template>> list({bool? paused}) async =>
      (await _dao.watchAllTemplates().first)
          .map(_toEntity)
          .where((t) => paused == null || t.paused == paused)
          .toList();

  Future<Template> create({
    required String name,
    String description = '',
    required int amountCents,
    TemplateDirection direction = TemplateDirection.unspecified,
    String? sourceAccountId,
    String? destinationAccountId,
    TemplateCycle cycle = TemplateCycle.unspecified,
    int cycleDays = 0,
    int billingDay = 0,
    String? startDate,
    String? endDate,
    bool autoRecord = false,
    String? category,
  }) async {
    if (name.trim().isEmpty) throw const ValidationFailure('模板名不能为空');
    if (amountCents <= 0) throw const ValidationFailure('金额必须大于零');
    if (direction == TemplateDirection.unspecified) {
      throw const ValidationFailure('模板方向未指定');
    }
    if (cycle == TemplateCycle.unspecified) {
      throw const ValidationFailure('模板周期未指定');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    // nextDate mirrors the server's CalculateNextDate(startDate, cycle,
    // billingDay, 1): first occurrence one period after the start date
    // (custom = daily default server-side).
    final start = _parseDate(startDate);
    final next = _calculateNextDate(start, cycle, billingDay);
    await _dao.insertTemplate(db.TransactionTemplatesCompanion.insert(
      id: id,
      name: name,
      description: description,
      amountCents: amountCents,
      direction: direction.index,
      sourceAccountId: sourceAccountId ?? '',
      destinationAccountId: Value(destinationAccountId),
      cycle: cycle.index,
      cycleDays: cycleDays,
      billingDay: billingDay,
      nextDate: next,
      startDate: start,
      endDate: Value(_parseDate(endDate)),
      autoRecord: autoRecord,
      paused: false,
      category: category ?? '',
      version: 1,
      createdAt: now,
      updatedAt: now,
    ));
    return _toEntity((await _dao.getTemplateById(id))!);
  }

  Future<Template> update({
    required String id,
    required int version,
    String? name,
    String? description,
    int? amountCents,
    TemplateCycle? cycle,
    int? cycleDays,
    String? endDate,
    bool? autoRecord,
  }) async {
    final row = await _dao.getTemplateById(id);
    if (row == null) throw const ServerFailure('模板不存在');
    if (row.version != version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    await _dao.updateTemplate(db.TransactionTemplatesCompanion(
      id: Value(id),
      name: Value(name ?? row.name),
      description: Value(description ?? row.description),
      amountCents: Value(amountCents ?? row.amountCents),
      cycle: Value(cycle == null ? row.cycle : cycle.index),
      cycleDays: Value(cycleDays ?? row.cycleDays),
      endDate: Value(endDate == null ? row.endDate : _parseDate(endDate)),
      autoRecord: Value(autoRecord ?? row.autoRecord),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    return _toEntity((await _dao.getTemplateById(id))!);
  }

  Future<void> delete(String id) async {
    if (await _dao.getTemplateById(id) == null) throw const ServerFailure('模板不存在');
    await _dao.deleteTemplateById(id);
  }

  Future<Template> pause(String id) => _flipPaused(id, true);
  Future<Template> resume(String id) => _flipPaused(id, false);

  Future<Template> _flipPaused(String id, bool paused) async {
    final row = await _dao.getTemplateById(id);
    if (row == null) throw const ServerFailure('模板不存在');
    await _dao.updateTemplate(db.TransactionTemplatesCompanion(
      id: Value(id),
      paused: Value(paused),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    return _toEntity((await _dao.getTemplateById(id))!);
  }

  Future<Template> get(String id) async =>
      _toEntityOrNull(await _dao.getTemplateById(id)) ??
      (throw const ServerFailure('模板不存在'));

  Future<RecordResult> record(String templateId) async {
    final row = await _dao.getTemplateById(templateId);
    if (row == null) throw const ServerFailure('模板不存在');
    if (row.paused) throw const ServerFailure('模板已暂停');

    final next = row.nextDate;
    String? txnId;
    await _database.transaction(() async {
      txnId = await _createTxnForRow(row, next);
      await _dao.updateTemplate(db.TransactionTemplatesCompanion(
        id: Value(templateId),
        nextDate: Value(_advance(next, row.cycle, row.cycleDays)),
        lastTransactionId: Value(txnId),
        version: Value(row.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
    });
    final updated = await _dao.getTemplateById(templateId);
    return RecordResult(
      transactionId: txnId!,
      nextDate: updated?.nextDate,
    );
  }

  /// Direction-paired entries, mirroring the server's recorder adapter:
  /// expense = debit category(expense) / credit source(asset);
  /// income = debit source(asset) / credit category(income);
  /// transfer = debit destination / credit source.
  Future<String> _createTxnForRow(
      db.TransactionTemplate row, DateTime date) async {
    final entries = <TransactionEntry>[];
    switch (row.direction) {
      case 1: // expense: debit category / credit source
        entries
          ..add(TransactionEntry(
              accountId: row.category,
              debitCents: row.amountCents,
              creditCents: 0))
          ..add(TransactionEntry(
              accountId: row.sourceAccountId,
              debitCents: 0,
              creditCents: row.amountCents));
      case 2: // income: debit source / credit category
        entries
          ..add(TransactionEntry(
              accountId: row.sourceAccountId,
              debitCents: row.amountCents,
              creditCents: 0))
          ..add(TransactionEntry(
              accountId: row.category,
              debitCents: 0,
              creditCents: row.amountCents));
      case 3: // transfer: debit destination / credit source
        if ((row.destinationAccountId ?? '').isEmpty) {
          throw const ValidationFailure('转账方向模板缺少目标账户');
        }
        entries
          ..add(TransactionEntry(
              accountId: row.destinationAccountId!,
              debitCents: row.amountCents,
              creditCents: 0))
          ..add(TransactionEntry(
              accountId: row.sourceAccountId,
              debitCents: 0,
              creditCents: row.amountCents));
      default:
        throw const ValidationFailure('模板方向未指定');
    }
    final txn = await _txnLocal.recordTransaction(RecordTransactionParams(
      transactionDate: date,
      description: row.name,
      entries: entries,
    ));
    return txn.id;
  }

  /// CalculateNextDate copied from the server (entity.go): first occurrence
  /// one period after base — weekly +7d / monthly clamped (billingDay wins) /
  /// yearly +1y / custom defaults to DAILY server-side / unspecified +1m.
  DateTime _calculateNextDate(
      DateTime base, TemplateCycle cycle, int billingDay) {
    switch (cycle) {
      case TemplateCycle.weekly:
        return base.add(const Duration(days: 7));
      case TemplateCycle.monthly:
        return _addMonthsClamped(base, 1, billingDay);
      case TemplateCycle.yearly:
        return DateTime.utc(base.year + 1, base.month, base.day);
      case TemplateCycle.custom:
        return base.add(const Duration(days: 1));
      default:
        return _addMonthsClamped(base, 1, billingDay);
    }
  }

  DateTime _addMonthsClamped(DateTime base, int months, int billingDay) {
    final targetMonth = base.month + months;
    final targetYear = base.year + (targetMonth - 1) ~/ 12;
    final m = (targetMonth - 1) % 12 + 1;
    var day = billingDay <= 0 ? base.day : billingDay;
    final lastDay = DateTime.utc(targetYear, m + 1, 0).day;
    if (day > lastDay) day = lastDay;
    return DateTime.utc(targetYear, m, day);
  }

  /// AdvanceNextDate rules copied from the server (record_port.go):
  /// weekly +7d / monthly +1 month (AddDate direct) / yearly +1 year /
  /// custom +cycleDays / unspecified unchanged.
  DateTime _advance(DateTime current, int cycle, int cycleDays) {
    switch (cycle) {
      case 1:
        return current.add(const Duration(days: 7));
      case 2:
        return DateTime.utc(current.year, current.month + 1, current.day);
      case 3:
        return DateTime.utc(current.year + 1, current.month, current.day);
      case 4:
        return current.add(Duration(days: cycleDays));
      default:
        return current;
    }
  }

  Template? _toEntityOrNull(db.TransactionTemplate? row) =>
      row == null ? null : _toEntity(row);

  Template _toEntity(db.TransactionTemplate r) => Template(
        id: r.id,
        name: r.name,
        description: r.description,
        amountCents: r.amountCents,
        direction: TemplateDirection.values[r.direction],
        sourceAccountId: r.sourceAccountId.isEmpty ? null : r.sourceAccountId,
        destinationAccountId: r.destinationAccountId,
        cycle: TemplateCycle.values[r.cycle],
        cycleDays: r.cycleDays,
        billingDay: r.billingDay,
        nextDate: _formatDate(r.nextDate),
        startDate: _formatDate(r.startDate),
        endDate: _formatDate(r.endDate),
        autoRecord: r.autoRecord,
        paused: r.paused,
        lastTransactionId: r.lastTransactionId,
        category: r.category.isEmpty ? null : r.category,
        version: r.version,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  DateTime _nowDate() {
    final n = DateTime.now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  DateTime _parseDate(String? s) {
    if (s == null || s.isEmpty) return _nowDate();
    final d = DateTime.tryParse(s);
    return d == null ? _nowDate() : DateTime.utc(d.year, d.month, d.day);
  }

  String? _formatDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
}
