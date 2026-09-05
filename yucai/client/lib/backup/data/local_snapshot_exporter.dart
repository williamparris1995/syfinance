import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
// F11 T3(ADR-2):per-row 序列化已抽至 envelope_codec(单一事实源)——本类
// 只保留取数(查询+子表分组)与 envelope 顶层组装;行形态契约见 codec 头注。
import 'package:yucai_client/core/localdb/envelope_codec.dart';

/// Exports the local drift store as a server-compatible BackupEnvelope
/// (R6 feature G, design ADR-3). Shape contract: the per-module JSON must be
/// structurally identical to the server exporters' domain-struct marshal —
/// PascalCase keys, int enums, RFC3339 timestamps, nested arrays (entries/
/// schedule/items), goal uuid arrays, holding's two sibling arrays. Go's
/// json.Unmarshal ignores unknown keys, so extra client fields are safe but
/// missing ones are not. Idempotent and read-only.
@LazySingleton()
class LocalSnapshotExporter {
  LocalSnapshotExporter(this._database);

  final db.AppDatabase _database;

  /// Serializes the full snapshot to envelope JSON bytes. `tenantId` is a
  /// placeholder — the server overrides it with the authenticated tenant.
  Future<Uint8List> exportAll({String tenantId = '00000000-0000-0000-0000-000000000000'}) async {
    final modules = <String, dynamic>{
      'account': await _exportAccounts(),
      'transaction': await _exportTransactions(),
      'debt': await _exportDebts(),
      'budget': await _exportBudgets(),
      'goal': await _exportGoals(),
      'tag': await _exportTags(),
      'template': await _exportTemplates(),
      'holding': await _exportHoldings(),
    };
    // Top-level keys use the server's json tags (snake_case); module payload
    // keys stay PascalCase (Go field-name default for the untagged structs).
    final envelope = {
      'version': 1,
      'tenant_id': tenantId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'modules': modules,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  // ---- module readers (drift rows → codec 行映射;取数与子表分组在此) ----

  Future<List<dynamic>> _exportAccounts() async {
    final rows = await _database.accountDao.getAllAccounts();
    return rows.map(accountRowToEnvelope).toList();
  }

  Future<List<dynamic>> _exportTransactions() async {
    final heads = await _database.transactionDao.getAllTransactions();
    final entries = await _database.transactionDao.getAllEntries();
    final byTxn = <String, List<db.TransactionEntry>>{};
    for (final e in entries) {
      byTxn.putIfAbsent(e.transactionId, () => []).add(e);
    }
    return heads
        .map((h) => transactionRowToEnvelope(h, byTxn[h.id] ?? const []))
        .toList();
  }

  Future<List<dynamic>> _exportDebts() async {
    final debts = await _database.debtDao.watchAllDebts().first;
    final out = <dynamic>[];
    for (final d in debts) {
      final schedule = await _database.debtDao.getScheduleByDebt(d.id);
      out.add(debtRowToEnvelope(d, schedule));
    }
    return out;
  }

  Future<List<dynamic>> _exportBudgets() async {
    final budgets = await _database.budgetDao.watchAllBudgets().first;
    final out = <dynamic>[];
    for (final b in budgets) {
      final items = await _database.budgetDao.getItemsByBudget(b.id);
      out.add(budgetRowToEnvelope(b, items));
    }
    return out;
  }

  Future<List<dynamic>> _exportGoals() async {
    final goals = await _database.goalDao.watchAllGoals().first;
    final out = <dynamic>[];
    for (final g in goals) {
      final (accounts, debts) = await _database.goalDao.linksFor(g.id);
      out.add(goalRowToEnvelope(g, accounts, debts));
    }
    return out;
  }

  Future<List<dynamic>> _exportTags() async {
    final tags = await _database.tagDao.watchAllTags().first;
    return tags.map(tagRowToEnvelope).toList();
  }

  Future<List<dynamic>> _exportTemplates() async {
    final rows = await _database.templateDao.watchAllTemplates().first;
    return rows.map(templateRowToEnvelope).toList();
  }

  Future<Map<String, dynamic>> _exportHoldings() async {
    // Server shape: sibling arrays "holdings"/"transactions" under one key.
    final holdings = await _database.holdingDao.watchAllHoldings().first;
    final trades =
        await _database.holdingDao.getAllHoldingTransactions();
    return {
      'holdings': holdings.map(holdingRowToEnvelope).toList(),
      'transactions': trades.map(holdingTxnRowToEnvelope).toList(),
    };
  }
}
