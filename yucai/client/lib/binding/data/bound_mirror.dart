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
    // 已知行为(F10 T2 注释缺口,review fix round 1):离线交易经
    // BalanceLocalUpdater 联动的账户余额为派生值,不置账户行 pending;
    // 上行前若账户模块镜像刷新,本地余额暂回 server 值(pending 交易仍
    // 可见),T3 上行成功后随镜像刷新自愈 —— 非缺陷,语义如此钉死。
    await result.fold((_) async {}, (list) async {
      await _db.transaction(() async {
        // F10 ADR-3 镜像协调:delete-all 排除 pending(在线全 synced 场景无
        // pending 行,与 delete-all 逐位等价);rebuild 遇同 id pending 行
        // 跳过 —— 单设备语义下 server 行 = pending 前镜像,跳过安全
        //(本地内容与存在性保住,待 T3 上行后恢复同步)。
        await _db.accountDao.deleteAllSyncedAccounts();
        final pendingIds = (await _db.accountDao.getPendingAccounts())
            .map((a) => a.id)
            .toSet();
        for (final e in list) {
          if (pendingIds.contains(e.id)) continue;
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
        // F10 ADR-3:pending 头行及其分录保留(内容与存在性不变),其余
        // delete-all + rebuild(在线全 synced 与旧行为逐位等价)。
        await _db.transactionDao.deleteEntriesOfSyncedTransactions();
        await _db.transactionDao.deleteAllSyncedTransactions();
        final pendingIds = (await _db.transactionDao.getPendingTransactions())
            .map((t) => t.id)
            .toSet();
        for (final t in page.transactions) {
          if (pendingIds.contains(t.id)) continue;
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
        // F10 ADR-3:pending 债务及其期次(含离线还款事实)保留。
        await _db.debtDao.deleteScheduleOfSyncedDebts();
        await _db.debtDao.deleteAllSyncedDebts();
        final pendingIds = (await _db.debtDao.getPendingDebts())
            .map((d) => d.id)
            .toSet();
        for (final detail in details) {
          if (pendingIds.contains(detail.debt.id)) continue;
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
        // F10 ADR-3:pending 预算及其预算项保留。
        await _db.budgetDao.deleteItemsOfSyncedBudgets();
        await _db.budgetDao.deleteAllSyncedBudgets();
        final pendingIds = (await _db.budgetDao.getPendingBudgets())
            .map((b) => b.id)
            .toSet();
        for (final d in details) {
          if (pendingIds.contains(d.id)) continue;
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
        // F10 ADR-3:pending 目标及其链接保留。
        await _db.goalDao.deleteLinksOfSyncedGoals();
        await _db.goalDao.deleteAllSyncedGoals();
        final pendingIds = (await _db.goalDao.getPendingGoals())
            .map((g) => g.id)
            .toSet();
        for (final g in list) {
          if (pendingIds.contains(g.id)) continue;
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
            // F10 ADR-3:pending 持仓头行保留,其台账行(离线买/卖/分红)按
            // (accountId, securityId) 联动保留;pending 持仓引用的证券同样
            // 保留(否则离线建仓证券刷新后变「未知证券」)。
            await _db.holdingDao.deleteHoldingTransactionsOfSyncedHoldings();
            await _db.holdingDao.deleteAllSyncedHoldings();
            await _db.referenceDao
                .deleteSecuritiesNotReferencedByPendingHoldings();
            final pendingPairs = (await _db.holdingDao.getPendingHoldings())
                .map((h) => '${h.accountId}|${h.securityId}')
                .toSet();
            for (final s in securities) {
              // F10 T2 fix(round 1):pending 持仓引用的 server 证券已在保留
              // 集内,裸 insert 撞 UNIQUE 会回滚整事务 —— upsert 冲突覆盖
              //(server 对 server-id 行权威;本地 uuid 行永不冲突)。
              await _db.referenceDao
                  .upsertSecurity(mirrorSecurityToRow(s));
            }
            for (final h in holdings) {
              // 同 (account, security) 的 server 旧行跳过,防重复持仓行
              //(本地 pending 行即最新事实)。
              if (pendingPairs.contains('${h.accountId}|${h.securityId}')) {
                continue;
              }
              await _db.holdingDao.insertHolding(mirrorHoldingToRow(h));
            }
            // 台账 append-only。F10 T2 fix(round 1):pending pair 的保留集
            // 含上一轮镜像写入的 server 台账行(server id),裸 insert 撞
            // UNIQUE 会回滚整事务 —— upsert 冲突覆盖;离线 uuid 行 server
            // 不含、永不冲突,合集(保留行 ∪ server 行)即全量。
            for (final t in trades) {
              await _db.holdingDao
                  .upsertHoldingTransaction(mirrorHoldingTxnToRow(t));
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
        // F10 ADR-3:pending 标签及其本地联表保留(联表不在备份契约,属
        // 本地私有数据);其余 delete-all + rebuild。
        await _db.tagDao.deleteAllSyncedTags();
        await _db.tagDao.deleteTransactionTagsOfSyncedTags();
        final pendingIds = (await _db.tagDao.getPendingTags())
            .map((t) => t.id)
            .toSet();
        for (final t in list) {
          if (pendingIds.contains(t.id)) continue;
          await _db.tagDao.insertTag(mirrorTagToRow(t));
        }
      });
    });
  }

  Future<void> _refreshTemplates() async {
    final result = await _templates.list();
    await result.fold((_) async {}, (list) async {
      await _db.transaction(() async {
        // F10 ADR-3:pending 模板保留(离线 record 推进的 nextDate/
        // lastTransactionId 不被镜像抹掉)。
        await _db.templateDao.deleteAllSyncedTemplates();
        final pendingIds = (await _db.templateDao.getPendingTemplates())
            .map((t) => t.id)
            .toSet();
        for (final t in list) {
          if (pendingIds.contains(t.id)) continue;
          await _db.templateDao.insertTemplate(mirrorTemplateToRow(t));
        }
      });
    });
  }
}
