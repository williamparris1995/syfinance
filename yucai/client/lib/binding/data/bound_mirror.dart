import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/binding/data/mirror_mappers.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// Module granularity for the bound-state mirror (design ADR-1).
enum MirrorModule {
  account,
  transaction,
  debt,
  budget,
  goal,
  holding,
  tag,
  template,
}

/// Bound-state local mirror (R6 feature H, design ADR-1): after a successful
/// remote write (or on login / before logout), refresh whole module tables
/// from the remote so the local store always holds the last mirror — the
/// logout-into-guest experience then works fully offline.
///
/// Fire-and-forget: callers never await on the write path; a failed refresh
/// is logged and retried on the next trigger. Per-module in-flight guard
/// serializes concurrent refreshes of the same module.
@LazySingleton()
class BoundMirror {
  /// Repos are resolved LAZILY from getIt at first refresh: the mirror is
  /// constructor-injected into every dual-source repo, and those same repos
  /// back the mirror — eager constructor injection creates a resolution
  /// cycle that overflows the stack on first resolve (review H-H2).
  BoundMirror(this._db);

  final db.AppDatabase _db;

  AccountRepository get _accounts => getIt<AccountRepository>();
  TransactionRepository get _transactions => getIt<TransactionRepository>();
  DebtRepository get _debts => getIt<DebtRepository>();
  BudgetRepository get _budgets => getIt<BudgetRepository>();
  GoalRepository get _goals => getIt<GoalRepository>();
  HoldingRepository get _holdings => getIt<HoldingRepository>();
  TagRepository get _tags => getIt<TagRepository>();
  TemplateRepository get _templates => getIt<TemplateRepository>();

  final _inFlight = <MirrorModule>{};

  /// Refreshes every module (login / pre-logout terminal refresh).
  Future<void> refreshAll() async {
    for (final m in MirrorModule.values) {
      await refreshModule(m);
    }
  }

  Future<void> refreshModule(MirrorModule m) async {
    if (_inFlight.contains(m)) return;
    _inFlight.add(m);
    try {
      switch (m) {
        case MirrorModule.account:
          await _refreshAccounts();
        case MirrorModule.transaction:
          await _refreshTransactions();
        case MirrorModule.debt:
          await _refreshDebts();
        case MirrorModule.budget:
          await _refreshBudgets();
        case MirrorModule.goal:
          await _refreshGoals();
        case MirrorModule.holding:
          await _refreshHoldings();
        case MirrorModule.tag:
          await _refreshTags();
        case MirrorModule.template:
          await _refreshTemplates();
      }
    } catch (e) {
      // Silent retry semantics: the next trigger re-runs the refresh.
      debugPrint('[mirror] refresh $m failed: $e');
    } finally {
      _inFlight.remove(m);
    }
  }

  Future<void> _refreshAccounts() async {
    final result = await _accounts.list();
    await result.fold((_) async {}, (list) async {
      await _db.transaction(() async {
        await _db.accountDao.deleteAllAccounts();
        for (final e in list) {
          await _db.accountDao
              .insertAccount(mirrorAccountToRow(e, DateTime.now().toUtc()));
        }
      });
    });
  }

  Future<void> _refreshTransactions() async {
    final result = await _transactions.list(const ListTransactionsParams(
      pageSize: 10000,
    ));
    await result.fold((_) async {}, (page) async {
      await _db.transaction(() async {
        await _db.transactionDao.deleteAllEntries();
        await _db.transactionDao.deleteAllTransactions();
        for (final t in page.transactions) {
          await _db.transactionDao
              .insertTransaction(mirrorTransactionToRow(t));
          for (final e in t.entries) {
            await _db.transactionDao
                .insertEntry(mirrorEntryToRow(t.id, e));
          }
        }
      });
    });
  }

  Future<void> _refreshDebts() async {
    final listResult = await _debts.list();
    await listResult.fold((_) async {}, (list) async {
      // Schedule rows need per-debt detail (list omits them).
      final details = <DebtDetail>[];
      for (final d in list) {
        final detail = await _debts.get(d.id);
        detail.fold((_) {}, details.add);
      }
      await _db.transaction(() async {
        await _db.debtDao.deleteAllSchedule();
        await _db.debtDao.deleteAllDebts();
        for (final detail in details) {
          await _db.debtDao.insertDebt(mirrorDebtToRow(detail.debt));
          for (final s in detail.schedule) {
            await _db.debtDao
                .insertScheduleEntry(mirrorScheduleToRow(detail.debt.id, s));
          }
        }
      });
    });
  }

  Future<void> _refreshBudgets() async {
    final listResult = await _budgets.listBudgets();
    await listResult.fold((_) async {}, (list) async {
      // Items need per-budget detail (list omits them).
      final details = <BudgetView>[];
      for (final b in list) {
        final detail = await _budgets.getBudget(b.id);
        detail.fold((_) {}, details.add);
      }
      await _db.transaction(() async {
        await _db.budgetDao.deleteAllItems();
        await _db.budgetDao.deleteAllBudgets();
        for (final d in details) {
          await _db.budgetDao.insertBudget(mirrorBudgetToRow(d));
          for (final i in d.items) {
            await _db.budgetDao
                .insertItem(mirrorBudgetItemToRow(d.id, i));
          }
        }
      });
    });
  }

  Future<void> _refreshGoals() async {
    final result = await _goals.listGoals();
    await result.fold((_) async {}, (list) async {
      await _db.transaction(() async {
        await _db.goalDao.deleteAllLinks();
        await _db.goalDao.deleteAllGoals();
        for (final g in list) {
          await _db.goalDao.insertGoal(mirrorGoalToRow(g));
          for (final a in g.linkedAccountIds) {
            await _db.goalDao.insertAccountLink(
                db.GoalAccountLinksCompanion.insert(goalId: g.id, linkedId: a));
          }
          for (final d in g.linkedDebtIds) {
            await _db.goalDao.insertDebtLink(
                db.GoalDebtLinksCompanion.insert(goalId: g.id, linkedId: d));
          }
        }
      });
    });
  }

  Future<void> _refreshHoldings() async {
    final holdingsResult = await _holdings.listHoldings();
    final tradesResult = await _holdings.listHoldingTransactions();
    final securitiesResult = await _holdings.listSecurities();
    await holdingsResult.fold((_) async {}, (holdings) async {
      await tradesResult.fold((_) async {}, (trades) async {
        await securitiesResult.fold((_) async {}, (securities) async {
          await _db.transaction(() async {
            await _db.holdingDao.deleteAllHoldingTransactions();
            await _db.holdingDao.deleteAllHoldings();
            await _db.referenceDao.deleteAllSecurities();
            for (final s in securities) {
              await _db.referenceDao.insertSecurity(mirrorSecurityToRow(s));
            }
            for (final h in holdings) {
              await _db.holdingDao.insertHolding(mirrorHoldingToRow(h));
            }
            for (final t in trades) {
              await _db.holdingDao
                  .insertHoldingTransaction(mirrorHoldingTxnToRow(t));
            }
          });
        });
      });
    });
  }

  Future<void> _refreshTags() async {
    final result = await _tags.list();
    await result.fold((_) async {}, (list) async {
      await _db.transaction(() async {
        await _db.tagDao.deleteAllTags();
        await _db.tagDao.deleteAllTransactionTags();
        for (final t in list) {
          await _db.tagDao.insertTag(mirrorTagToRow(t));
        }
      });
    });
  }

  Future<void> _refreshTemplates() async {
    final result = await _templates.list();
    await result.fold((_) async {}, (list) async {
      await _db.transaction(() async {
        await _db.templateDao.deleteAllTemplates();
        for (final t in list) {
          await _db.templateDao.insertTemplate(mirrorTemplateToRow(t));
        }
      });
    });
  }
}
