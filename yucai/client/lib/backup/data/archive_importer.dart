import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_row_codec.dart';

/// Archive importer (R6 feature J, design ADR-2): replaces the ENTIRE local
/// store from a decrypted envelope (the inverse of G's exporter). Runs in a
/// single drift transaction — any module failure rolls back and the local
/// store is untouched.
///
/// F17-T2 行映射抽取:envelope 行 → drift Companion 的逐字段映射已原位迁往
/// `core/localdb/envelope_row_codec.dart`(单一事实源,与 F17 增量下行
/// PullApplier 共享);本类保留「purge + 全量 insert」的导入编排。写入语义
/// 差异(导入=purge 后裸 insert;拉取=单行 insertOnConflictUpdate)由各
/// 自的编排层持有,行映射本身一份。
@LazySingleton()
class ArchiveImporter {
  ArchiveImporter(this._database);

  final db.AppDatabase _database;

  Future<void> importAll(Uint8List envelopeJson) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(envelopeJson));
    } catch (_) {
      throw const ValidationFailure('存档内容无法解析');
    }
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const ValidationFailure('存档版本不支持');
    }
    final envelope = decoded;
    final modules = (envelope['modules'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    await _database.transaction(() async {
      // Purge dependents-first, import account-first — the server's restore
      // ordering (backup service orderedPorts).
      await _database.transactionDao.deleteAllEntries();
      await _database.transactionDao.deleteAllTransactions();
      await _database.debtDao.deleteAllSchedule();
      await _database.debtDao.deleteAllDebts();
      await _database.budgetDao.deleteAllItems();
      await _database.budgetDao.deleteAllBudgets();
      await _database.goalDao.deleteAllLinks();
      await _database.goalDao.deleteAllGoals();
      await _database.tagDao.deleteAllTransactionTags();
      await _database.tagDao.deleteAllTags();
      await _database.templateDao.deleteAllTemplates();
      await _database.holdingDao.deleteAllHoldingTransactions();
      await _database.holdingDao.deleteAllHoldings();
      await _database.accountDao.deleteAllAccounts();

      for (final a in _list(modules, 'account')) {
        await _database.accountDao.insertAccount(accountRowFromEnvelope(a));
      }
      for (final t in _list(modules, 'transaction')) {
        await _database.transactionDao
            .insertTransaction(transactionRowFromEnvelope(t));
        for (final e in (t['Entries'] as List? ?? [])) {
          await _database.transactionDao
              .insertEntry(entryRowFromEnvelope(t['ID'], e));
        }
      }
      for (final d in _list(modules, 'debt')) {
        await _database.debtDao.insertDebt(debtRowFromEnvelope(d));
        for (final s in (d['Schedule'] as List? ?? [])) {
          await _database.debtDao
              .insertScheduleEntry(scheduleRowFromEnvelope(d['ID'], s));
        }
      }
      for (final b in _list(modules, 'budget')) {
        await _database.budgetDao.insertBudget(budgetRowFromEnvelope(b));
        for (final i in (b['Items'] as List? ?? [])) {
          await _database.budgetDao
              .insertItem(budgetItemRowFromEnvelope(b['ID'], i));
        }
      }
      for (final g in _list(modules, 'goal')) {
        await _database.goalDao.insertGoal(goalRowFromEnvelope(g));
        for (final a in (g['LinkedAccountIDs'] as List? ?? [])) {
          await _database.goalDao.insertAccountLink(
              db.GoalAccountLinksCompanion.insert(goalId: g['ID'], linkedId: a));
        }
        for (final d in (g['LinkedDebtIDs'] as List? ?? [])) {
          await _database.goalDao.insertDebtLink(
              db.GoalDebtLinksCompanion.insert(goalId: g['ID'], linkedId: d));
        }
      }
      for (final t in _list(modules, 'tag')) {
        await _database.tagDao.insertTag(tagRowFromEnvelope(t));
      }
      for (final t in _list(modules, 'template')) {
        await _database.templateDao.insertTemplate(templateRowFromEnvelope(t));
      }
      final holding = modules['holding'] as Map<String, dynamic>?;
      if (holding != null) {
        for (final h in (holding['holdings'] as List? ?? [])) {
          await _database.holdingDao.insertHolding(holdingRowFromEnvelope(h));
        }
        for (final t in (holding['transactions'] as List? ?? [])) {
          await _database.holdingDao
              .insertHoldingTransaction(holdingTxnRowFromEnvelope(t));
        }
      }
    });
  }

  List<dynamic> _list(Map<String, dynamic> modules, String key) =>
      modules[key] as List? ?? [];
}
