import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// Guest-mode balance linkage (R6 F, design ADR-1) — mirrors the server's
/// BalanceUpdaterImpl (transaction/adapter/driven/balance/updater.go):
/// every entry's account is looked up (missing → ServerFailure → the
/// surrounding drift transaction rolls the whole write back), the balance
/// delta follows ApplyEntryDirection (account/domain/repository.go:27-36)
/// scaled by [sign] (+1 apply / −1 reverse), and the account version bumps.
@LazySingleton()
class BalanceLocalUpdater {
  BalanceLocalUpdater(this._database);

  final db.AppDatabase _database;

  /// Applies (sign = +1) or reverses (sign = −1) the balance effect of the
  /// given entries. MUST be called inside the caller's drift transaction.
  Future<void> applyEntries(
      List<db.TransactionEntry> entries, int sign) async {
    for (final e in entries) {
      final account = await _database.accountDao.getAccountById(e.accountId);
      if (account == null) {
        throw ServerFailure('账户不存在: ${e.accountId}');
      }
      final delta = _entryDelta(account.accountType, e.debitCents, e.creditCents) * sign;
      await _database.accountDao.updateAccount(db.AccountsCompanion(
        id: Value(e.accountId),
        currentBalanceCents: Value(account.currentBalanceCents + delta),
        version: Value(account.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
    }
  }

  /// asset(1)/expense(5) → debit−credit; liability(2)/equity(3)/income(4)
  /// → credit−debit; unknown → 0. Copied verbatim from the server rule.
  int _entryDelta(int accountType, int debitCents, int creditCents) {
    switch (accountType) {
      case 1:
      case 5:
        return debitCents - creditCents;
      case 2:
      case 3:
      case 4:
        return creditCents - debitCents;
      default:
        return 0;
    }
  }
}
