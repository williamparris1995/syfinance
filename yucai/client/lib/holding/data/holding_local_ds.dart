import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/holding_dao.dart';
import 'package:yucai_client/core/localdb/daos/derived_dao.dart';
import 'package:yucai_client/core/localdb/daos/reference_dao.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// Guest-mode data source for the holding module (R6, design ADR-1).
///
/// buy/sell run inside ONE drift transaction: holding upsert + lot write /
/// FIFO consumption + trade ledger row + the double-entry cash linkage
/// (server direction table: buy = credit from / debit holding account, sell
/// reversed; fee never enters the cash leg — it capitalizes into the lot
/// cost basis). Display fields (securityName/marketValue/…) are synthesized
/// at read time from the securities table; without a live price the avgCost
/// basis is the honest (stale) fallback.
@LazySingleton()
class HoldingLocalDataSource {
  HoldingLocalDataSource(this._database, this._txns, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final TransactionLocalDataSource _txns;
  final Uuid _uuid;

  HoldingDao get _dao => _database.holdingDao;
  DerivedDao get _derived => _database.derivedDao;
  ReferenceDao get _reference => _database.referenceDao;

  // ---- reads ----

  Future<List<Holding>> listHoldings({String? accountId}) async {
    final rows = await _dao.watchAllHoldings().first;
    final out = <Holding>[];
    for (final r in rows) {
      if (accountId != null && r.accountId != accountId) continue;
      out.add(await _toEntity(r));
    }
    return out;
  }

  Future<List<HoldingTransaction>> listHoldingTransactions(
      {String? accountId, String? securityId}) async {
    final rows = await _dao.getAllHoldingTransactions();
    return rows
        .where((r) =>
            (accountId == null || r.accountId == accountId) &&
            (securityId == null || r.securityId == securityId))
        .map(_txnView)
        .toList();
  }

  // ---- trades ----

  Future<HoldingTransaction> buy({
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  }) =>
      _trade(
        isBuy: true,
        accountId: accountId,
        securityId: securityId,
        fromAccountId: fromAccountId,
        quantity: quantity,
        priceCents: priceCents,
        feeCents: feeCents,
        tradeDate: tradeDate,
        notes: notes,
      );

  Future<HoldingTransaction> sell({
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  }) =>
      _trade(
        isBuy: false,
        accountId: accountId,
        securityId: securityId,
        fromAccountId: fromAccountId,
        quantity: quantity,
        priceCents: priceCents,
        feeCents: feeCents,
        tradeDate: tradeDate,
        notes: notes,
      );

  Future<HoldingTransaction> _trade({
    required bool isBuy,
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    required int feeCents,
    required String tradeDate,
    String? notes,
  }) async {
    if (quantity <= 0) throw const ValidationFailure('数量必须大于零');
    if (priceCents <= 0) throw const ValidationFailure('价格必须大于零');
    if (fromAccountId.isEmpty) {
      throw const ValidationFailure('必须指定资金账户');
    }
    final date = _parseDate(tradeDate);
    final amount = (priceCents * quantity).round();
    final now = DateTime.now().toUtc();

    // Server-side trade validations mirrored (holding_handler.go:495+).
    final from = await _database.accountDao.getAccountById(fromAccountId);
    if (from == null) throw const ServerFailure('资金账户不存在');
    final holdingAccount = await _database.accountDao.getAccountById(accountId);
    if (holdingAccount == null) throw const ServerFailure('投资账户不存在');
    if (from.accountType != 1) {
      throw const ValidationFailure('资金账户必须为资产类型');
    }
    if (fromAccountId == accountId) {
      throw const ValidationFailure('资金账户不能与投资账户相同');
    }
    if (from.currencyCode != holdingAccount.currencyCode) {
      throw const ValidationFailure('资金账户与投资账户币种必须一致');
    }
    if (isBuy && from.currentBalanceCents < amount) {
      throw const ServerFailure('资金账户余额不足');
    }

    final tradeId = _uuid.v4();
    await _database.transaction(() async {
      // 1) Holding row upsert.
      final existing = (await _dao.watchAllHoldings().first)
          .where((h) =>
              h.accountId == accountId && h.securityId == securityId)
          .firstOrNull;
      if (isBuy) {
        final newQty = (existing?.quantity ?? 0) + quantity;
        final newCost =
            ((existing?.quantity ?? 0) * (existing?.avgCostCents ?? 0)) +
                amount + feeCents; // fee capitalizes into the basis
        final avg = newQty == 0 ? 0 : (newCost / newQty).round();
        if (existing == null) {
          await _dao.insertHolding(db.HoldingsCompanion.insert(
            id: _uuid.v4(),
            accountId: accountId,
            securityId: securityId,
            quantity: newQty,
            avgCostCents: avg,
            version: 1,
            createdAt: now,
            updatedAt: now,
          ));
        } else {
          await _dao.updateHolding(db.HoldingsCompanion(
            id: Value(existing.id),
            quantity: Value(newQty),
            avgCostCents: Value(avg),
            version: Value(existing.version + 1),
            updatedAt: Value(now),
          ));
        }
        // 2a) Buy lot: per-share cost capitalizes the fee.
        final holdingRow = (await _dao.watchAllHoldings().first)
            .where((h) =>
                h.accountId == accountId && h.securityId == securityId)
            .first;
        await _derived.insertHoldingLot(db.HoldingLotsCompanion.insert(
          id: _uuid.v4(),
          holdingId: holdingRow.id,
          securityId: securityId,
          acquiredDate: date,
          acquiredTradeId: tradeId,
          priceCents: ((amount + feeCents) / quantity).round(),
          quantity: quantity,
          remainingQuantity: quantity,
        ));
      } else {
        if (existing == null || existing.quantity < quantity) {
          throw const ValidationFailure('持仓数量不足');
        }
        // 2b) Sell: FIFO consumption + realized pnl (fee deducted from
        // proceeds), avgCost recomputed from remaining lots — lots are
        // scoped to THIS holding (server HoldingIDEQ).
        final realized = await _consumeFifo(
            existing.id, quantity, priceCents, feeCents);
        final remainingQty = existing.quantity - quantity;
        final remainingCost = await _remainingLotCost(existing.id);
        await _dao.updateHolding(db.HoldingsCompanion(
          id: Value(existing.id),
          quantity: Value(remainingQty),
          avgCostCents: Value(
              remainingQty == 0 ? 0 : (remainingCost / remainingQty).round()),
          version: Value(existing.version + 1),
          updatedAt: Value(now),
        ));
        // realized is folded into the ledger row below.
        await _dao.insertHoldingTransaction(
            db.HoldingTransactionsCompanion.insert(
          id: tradeId,
          accountId: accountId,
          securityId: securityId,
          tradeType: TradeType.sell.index + 1,
          quantity: quantity,
          priceCents: priceCents,
          amountCents: amount,
          feeCents: feeCents,
          realizedPnlCents: realized,
          tradeDate: date,
          notes: notes ?? '',
          createdAt: now,
        ));
        // 3) Cash linkage: sell = debit from (cash+) / credit holding account.
        await _txns.recordTransaction(RecordTransactionParams(
          transactionDate: date,
          description: '卖出',
          entries: [
            TransactionEntry(
                accountId: fromAccountId,
                debitCents: amount,
                creditCents: 0),
            TransactionEntry(
                accountId: accountId, debitCents: 0, creditCents: amount),
          ],
        ));
        return;
      }

      // Buy path: ledger row + cash linkage (credit from / debit holding).
      await _dao.insertHoldingTransaction(
          db.HoldingTransactionsCompanion.insert(
        id: tradeId,
        accountId: accountId,
        securityId: securityId,
        tradeType: TradeType.buy.index + 1,
        quantity: quantity,
        priceCents: priceCents,
        amountCents: amount,
        feeCents: feeCents,
        realizedPnlCents: 0,
        tradeDate: date,
        notes: notes ?? '',
        createdAt: now,
      ));
      await _txns.recordTransaction(RecordTransactionParams(
        transactionDate: date,
        description: '买入',
        entries: [
          TransactionEntry(
              accountId: accountId, debitCents: amount, creditCents: 0),
          TransactionEntry(
              accountId: fromAccountId, debitCents: 0, creditCents: amount),
        ],
      ));
    });
    return _txnView((await _dao.getHoldingTransactionById(tradeId))!);
  }

  /// FIFO consumption (server ConsumeLotsFIFO): oldest lots first; realized
  /// pnl = Σ (price − lot price) × taken, minus the sell fee.
  Future<int> _consumeFifo(
      String holdingId, double sellQty, int priceCents, int feeCents) async {
    final lots = await _derived.getLotsByHolding(holdingId);
    lots.sort((a, b) => a.acquiredDate.compareTo(b.acquiredDate));
    var remaining = sellQty;
    var realized = 0;
    for (final lot in lots) {
      if (remaining <= 0) break;
      final take = lot.remainingQuantity < remaining
          ? lot.remainingQuantity
          : remaining;
      realized += (priceCents - lot.priceCents) * take.round();
      final newRemaining = lot.remainingQuantity - take;
      if (newRemaining <= 0) {
        await _derived.deleteLotById(lot.id);
      } else {
        await _derived.updateLotRemaining(lot.id, newRemaining);
      }
      remaining -= take;
    }
    return realized - feeCents;
  }

  Future<int> _remainingLotCost(String holdingId) async {
    final lots = await _derived.getLotsByHolding(holdingId);
    return lots.fold<int>(
        0, (a, l) => a + (l.priceCents * l.remainingQuantity).round());
  }

  Future<HoldingTransaction> recordDividend({
    required String accountId,
    required String securityId,
    required double quantity,
    required int cashPerShareCents,
    required int totalAmountCents,
    required String tradeDate,
    String? notes,
  }) async {
    // Server recordDividend has no cash leg (accepted difference, ADR-1).
    final id = _uuid.v4();
    await _dao.insertHoldingTransaction(
        db.HoldingTransactionsCompanion.insert(
      id: id,
      accountId: accountId,
      securityId: securityId,
      tradeType: TradeType.dividend.index + 1,
      quantity: quantity,
      priceCents: cashPerShareCents,
      amountCents: totalAmountCents,
      feeCents: 0,
      realizedPnlCents: 0,
      tradeDate: _parseDate(tradeDate),
      notes: notes ?? '',
      createdAt: DateTime.now().toUtc(),
    ));
    return _txnView((await _dao.getHoldingTransactionById(id))!);
  }

  Future<HoldingTransaction> recordSplit({
    required String accountId,
    required String securityId,
    required double ratio,
    required String splitDate,
    String? notes,
  }) async {
    if (ratio <= 0) throw const ValidationFailure('拆股比例必须大于零');
    final date = _parseDate(splitDate);
    final now = DateTime.now().toUtc();
    final existing = (await _dao.watchAllHoldings().first)
        .where((h) => h.accountId == accountId && h.securityId == securityId)
        .firstOrNull;
    if (existing == null) throw const ServerFailure('持仓不存在');
    final id = _uuid.v4();
    await _database.transaction(() async {
      await _dao.updateHolding(db.HoldingsCompanion(
        id: Value(existing.id),
        quantity: Value(existing.quantity * ratio),
        avgCostCents:
            Value((existing.avgCostCents / ratio).round()),
        version: Value(existing.version + 1),
        updatedAt: Value(now),
      ));
      // Split every open lot of THIS holding: quantity and remaining each
      // scaled by ratio, price divided by ratio (server lot.go:13-15).
      final lots = await _derived.getLotsByHolding(existing.id);
      for (final lot in lots) {
        await _derived.updateLotSplit(lot.id, lot.quantity * ratio,
            lot.remainingQuantity * ratio, (lot.priceCents / ratio).round());
      }
      await _dao.insertHoldingTransaction(
          db.HoldingTransactionsCompanion.insert(
        id: id,
        accountId: accountId,
        securityId: securityId,
        tradeType: TradeType.split.index + 1,
        quantity: ratio,
        priceCents: 0,
        amountCents: 0,
        feeCents: 0,
        realizedPnlCents: 0,
        tradeDate: date,
        notes: notes ?? '',
        createdAt: now,
      ));
    });
    return _txnView((await _dao.getHoldingTransactionById(id))!);
  }

  // ---- securities ----

  Future<Security> createSecurity({
    required String symbol,
    required String name,
    required SecurityType type,
    String? exchange,
    required String currency,
  }) async {
    final id = _uuid.v4();
    await _reference.insertSecurity(db.SecuritiesCompanion.insert(
      id: id,
      symbol: symbol,
      name: name,
      securityType: type.name,
      exchange: exchange ?? '',
      currencyCode: currency,
      currentPriceCents: 0,
      createdAt: DateTime.now().toUtc(),
    ));
    return _securityView((await _reference.getSecurityById(id))!);
  }

  Future<List<Security>> listSecurities({SecurityType? type}) async {
    final rows = await _reference.getAllSecurities();
    return rows
        .where((r) => type == null || r.securityType == type.name)
        .map(_securityView)
        .toList();
  }

  Future<List<Security>> searchSecurities(String query) async {
    final q = query.toLowerCase();
    final rows = await _reference.getAllSecurities();
    return rows
        .where((r) =>
            r.symbol.toLowerCase().startsWith(q) ||
            r.name.toLowerCase().startsWith(q))
        .map(_securityView)
        .toList();
  }

  Future<void> updateSecurityPrice({
    required String id,
    required int priceCents,
  }) async {
    if (await _reference.getSecurityById(id) == null) {
      throw const ServerFailure('证券不存在');
    }
    await _reference.updateSecurityPrice(id, priceCents);
  }

  // ---- explicit degradations (design ADR-6) ----

  Future<Never> syncPrices() async =>
      throw const ServerFailure('离线暂不支持行情同步');

  Future<Never> getPortfolioPerformance({
    String range = 'MONTH',
    String? accountId,
    bool includeBenchmark = false,
    String baseCurrency = '',
  }) async =>
      throw const ServerFailure('离线暂不支持收益分析');

  Future<Never> getHoldingPerformance({
    required String holdingId,
    String range = 'MONTH',
    String baseCurrency = '',
  }) async =>
      throw const ServerFailure('离线暂不支持收益分析');

  /// Market value of one holding: live price when available, else the
  /// (stale) avgCost basis — shared by the holding page and goal actuals so
  /// both always agree (design R2).
  Future<int> marketValueOf(db.Holding h) async {
    final security = await _reference.getSecurityById(h.securityId);
    if (security != null && security.currentPriceCents > 0) {
      return (h.quantity * security.currentPriceCents).round();
    }
    return (h.quantity * h.avgCostCents).round();
  }

  /// Guest branch of the repo's listInvestmentGoals: read the local goals
  /// table (investment-type only) mapped into the holding-module GoalView.
  Future<List<GoalView>> listInvestmentGoalsLocal() async {
    final rows = await _database.goalDao.watchAllGoals().first;
    final views = <GoalView>[];
    for (final r in rows.where((r) => r.goalType == 3)) {
      final (accounts, _) = await _database.goalDao.linksFor(r.id);
      final holdings = await _dao.watchAllHoldings().first;
      final scoped =
          holdings.where((h) => accounts.contains(h.accountId)).toList();
      final values = await Future.wait(scoped.map(marketValueOf));
      final current = values.fold(0, (a, v) => a + v);
      views.add(GoalView(
        id: r.id,
        name: r.name,
        targetCents: r.targetAmountCents,
        currentCents: current,
        progressPct: r.targetAmountCents == 0
            ? 0
            : current * 100 / r.targetAmountCents,
      ));
    }
    return views;
  }

  // ---- helpers ----

  HoldingTransaction _txnView(db.HoldingTransaction r) => HoldingTransaction(
        id: r.id,
        accountId: r.accountId,
        securityId: r.securityId,
        tradeType: TradeType.values[r.tradeType - 1],
        quantity: r.quantity,
        priceCents: r.priceCents,
        amountCents: r.amountCents,
        feeCents: r.feeCents,
        tradeDate:
            '${r.tradeDate.year.toString().padLeft(4, '0')}-${r.tradeDate.month.toString().padLeft(2, '0')}-${r.tradeDate.day.toString().padLeft(2, '0')}',
        notes: r.notes,
        createdAt: r.createdAt,
      );

  Future<Holding> _toEntity(db.Holding r) async {
    final security = await _reference.getSecurityById(r.securityId);
    final price =
        security == null || security.currentPriceCents <= 0 ? null : security.currentPriceCents;
    final marketValue =
        price == null ? (r.quantity * r.avgCostCents).round() : (r.quantity * price).round();
    final pnl = price == null ? 0 : marketValue - (r.quantity * r.avgCostCents).round();
    return Holding(
      id: r.id,
      accountId: r.accountId,
      securityId: r.securityId,
      securityName: security?.name ?? '未知证券',
      securitySymbol: security?.symbol ?? '-',
      quantity: r.quantity,
      avgCostCents: r.avgCostCents,
      marketValueCents: marketValue,
      unrealizedPnlCents: pnl,
      version: r.version,
      currentPriceCents: price ?? 0,
      pnlPct: r.avgCostCents == 0 ? 0 : pnl * 100 / (r.quantity * r.avgCostCents),
      securityType: security == null
          ? null
          : SecurityType.values.firstWhere(
              (t) => t.name == security.securityType,
              orElse: () => SecurityType.other),
      currency: security?.currencyCode ?? 'CNY',
    );
  }

  Security _securityView(db.Security r) => Security(
        id: r.id,
        symbol: r.symbol,
        name: r.name,
        securityType: SecurityType.values.firstWhere(
            (t) => t.name == r.securityType,
            orElse: () => SecurityType.other),
        exchange: r.exchange.isEmpty ? null : r.exchange,
        currency: r.currencyCode,
        currentPriceCents: r.currentPriceCents,
        createdAt: r.createdAt,
      );

  DateTime _parseDate(String s) {
    final d = DateTime.tryParse(s);
    if (d == null) throw const ValidationFailure('日期格式错误');
    return DateTime.utc(d.year, d.month, d.day);
  }
}

/// Local three-source net worth (design ADR-7): assets = Σ asset account
/// balances + Σ holdings market value (avgCost fallback); liabilities =
/// Σ liability balances + Σ borrowedIn remaining.
@LazySingleton()
class NetWorthLocalDataSource {
  NetWorthLocalDataSource(this._database);

  final db.AppDatabase _database;

  Future<NetWorthView> getNetWorth({required String baseCurrency}) async {
    final accounts = await _database.accountDao.getAllAccounts();
    final holdings = await _database.holdingDao.watchAllHoldings().first;
    final debts = await _database.debtDao.watchAllDebts().first;

    var assets = 0, liabilities = 0;
    for (final a in accounts) {
      if (a.accountType == 1) {
        assets += a.currentBalanceCents;
      }
      // Liability ACCOUNT balances are deliberately NOT counted here: the
      // guest balance column stays frozen while borrowedIn debt rows carry
      // the liability below — counting both would double-count (review E-#9).
    }
    // Accepted caliber difference (recorded, not a server mirror): the guest
    // double-entry never moves the balance column, so "frozen asset balances
    // + unrealized gain layer" nets to the true guest net worth (cash not
    // yet deducted and cost not yet added cancel out). Bound-mode numbers
    // come from the server and may differ systematically until feature H.
    for (final h in holdings) {
      final security =
          await _database.referenceDao.getSecurityById(h.securityId);
      if (security != null && security.currentPriceCents > 0) {
        assets +=
            (h.quantity * (security.currentPriceCents - h.avgCostCents))
                .round();
      }
    }
    for (final d in debts) {
      if (d.debtType == DebtDirection.borrowedIn) {
        final schedule = await _database.debtDao.getScheduleByDebt(d.id);
        final paid = schedule.fold(0, (a, s2) => a + s2.paidCents);
        liabilities += d.totalPrincipalCents - paid;
      }
    }
    return NetWorthView(
      totalAssetsCents: assets,
      totalLiabilitiesCents: liabilities,
      netWorthCents: assets - liabilities,
      currency: baseCurrency.isEmpty ? 'CNY' : baseCurrency,
    );
  }
}

/// Local contract-int constants for debt direction (borrowedIn = 1).
extension type const DebtDirection(int value) {
  static const borrowedIn = 1;
}
