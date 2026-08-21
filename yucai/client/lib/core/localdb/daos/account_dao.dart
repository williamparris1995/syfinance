import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/account_tables.dart';

part 'account_dao.g.dart';

/// DAO boundary = backup module boundary (design ADR-4): the seam in feature C
/// wires repositories to these accessors.
@DriftAccessor(tables: [Accounts, ChartOfAccounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<void> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<Account?> getAccountById(String id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Account>> watchAllAccounts() => select(accounts).watch();

  Future<int> updateAccount(AccountsCompanion entry) =>
      (update(accounts)..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<int> deleteAccountById(String id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  // Chart of accounts (local-owned reference).
  Future<void> insertChartOfAccount(ChartOfAccountsCompanion entry) =>
      into(chartOfAccounts).insert(entry);

  Stream<List<ChartOfAccount>> watchAllChartOfAccounts() =>
      select(chartOfAccounts).watch();
}
