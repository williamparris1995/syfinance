import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/account_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/debt_dao.dart';
import 'daos/derived_dao.dart';
import 'daos/goal_dao.dart';
import 'daos/holding_dao.dart';
import 'daos/reference_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/template_dao.dart';
import 'daos/transaction_dao.dart';
import 'tables/account_tables.dart';
import 'tables/budget_tables.dart';
import 'tables/debt_tables.dart';
import 'tables/derived_tables.dart';
import 'tables/goal_tables.dart';
import 'tables/holding_tables.dart';
import 'tables/reference_tables.dart';
import 'tables/tag_tables.dart';
import 'tables/template_tables.dart';
import 'tables/transaction_tables.dart';

part 'app_database.g.dart';

/// Local-first store (R6): drift is the primary storage while unbound and the
/// mirror after binding. Contract tables follow the server backup payload
/// (design.md ADR-3); timestamps persist as text (build.yaml) to keep the
/// RFC3339-compatible wire form.
@DriftDatabase(
  tables: [
    Accounts,
    ChartOfAccounts,
    Transactions,
    TransactionEntries,
    Debts,
    PaymentScheduleEntries,
    Budgets,
    BudgetItems,
    Goals,
    GoalAccountLinks,
    GoalDebtLinks,
    Tags,
    TransactionTags,
    TransactionTemplates,
    Holdings,
    HoldingTransactions,
    Currencies,
    RateHistories,
    Securities,
    SecurityPriceHistories,
    DebtProgressSnapshots,
    GoalProgressSnapshots,
    HoldingSnapshots,
    HoldingLots,
  ],
  daos: [
    AccountDao,
    TransactionDao,
    DebtDao,
    BudgetDao,
    GoalDao,
    TagDao,
    TemplateDao,
    HoldingDao,
    ReferenceDao,
    DerivedDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// The file path resolves lazily on first query so DI registration stays
  /// synchronous (path_provider needs a live platform binding).
  static QueryExecutor _openConnection() => LazyDatabase(() async {
        final dir = await getApplicationSupportDirectory();
        final file = File('${dir.path}/yucai.db');
        return NativeDatabase.createInBackground(file);
      });

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // Mechanism only (spec FR-5): add per-version steps when the schema
        // evolves beyond v1.
        onUpgrade: (m, from, to) async {},
        // SQLite ships with foreign keys off; cascade deletes (design LLD)
        // need the pragma enabled per connection.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
