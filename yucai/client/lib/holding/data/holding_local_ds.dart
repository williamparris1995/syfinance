import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/holding_dao.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/localdb/daos/derived_dao.dart';
import 'package:yucai_client/core/localdb/daos/reference_dao.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/data/local_performance_assembler.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// F9 FR-3/ADR-3 持仓分页查询结果(照 F7 `ListTransactionsResult` 形态)。
///
/// [nextPageToken] = 下一页起始 offset 串(空 = 无下一页);[totalCount] =
/// 过滤(搜索)后的总条数(非本页条数)。
class PagedHoldings {
  const PagedHoldings({
    required this.holdings,
    this.nextPageToken = '',
    this.totalCount = 0,
  });

  final List<Holding> holdings;
  final String nextPageToken;
  final int totalCount;

  bool get hasMore => nextPageToken.isNotEmpty;
}

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

  /// F9 FR-3/ADR-3 持仓分页查询(in-memory,默认路径零变化)。
  ///
  /// **为何新增 `listPaged` 而不改 `listHoldings`**:既有 `listHoldings` 返回
  /// `List<Holding>`,被 repo/bloc/详情页/net worth 等多条链路消费,改返回
  /// 形态会波及全部调用方;新方法独立承载「搜索 + offset 分页」查询能力
  /// (FR-6 DS 级断言的靶点)。默认参数下与 `listHoldings` **同集(条数 ≤
  /// pageSize=100 时整集,超出截断)**;序为本方法固定的市值降序基准序
  /// (`listHoldings` 保持 DAO 行序不变,两者不承诺同序)。
  Future<PagedHoldings> listPaged({
    String? accountId,
    String? searchText,
    int pageSize = 100,
    String? pageToken,
  }) async {
    // 搜索词:trim 后非空才生效(null/空白 = 不过滤),匹配 symbol/name
    // contains 忽略大小写(F9 LLD 口径;与 _toEntity 合成字段同源)。
    final query = searchText?.trim() ?? '';
    final searchLower = query.isEmpty ? null : query.toLowerCase();

    final all = await listHoldings(accountId: accountId);
    var filtered = searchLower == null
        ? all
        : all
            .where((h) =>
                h.securitySymbol.toLowerCase().contains(searchLower) ||
                h.securityName.toLowerCase().contains(searchLower))
            .toList();

    // DS 基准序:市值降序(原币 marketValueCents —— DS 层无汇率换算,多币种
    // 混排的精确序由页面 preferred 口径负责;此处只需确定性全序保证 offset
    // 分页稳定),tie-break symbol/id 升序。
    filtered = [...filtered]..sort((a, b) {
        final byMv = b.marketValueCents.compareTo(a.marketValueCents);
        if (byMv != 0) return byMv;
        final bySymbol =
            a.securitySymbol.compareTo(b.securitySymbol);
        return bySymbol != 0 ? bySymbol : a.id.compareTo(b.id);
      });

    // offset 分页(照 F7 transaction_local_ds 语义逐位):pageToken = 偏移串,
    // pageSize<=0 回退 100,越界返回空页不抛。
    final offset = int.tryParse(pageToken ?? '') ?? 0;
    final size = pageSize <= 0 ? 100 : pageSize;
    final end = (offset + size).clamp(0, filtered.length);
    final page =
        offset >= filtered.length ? <Holding>[] : filtered.sublist(offset, end);
    return PagedHoldings(
      holdings: page,
      nextPageToken: end < filtered.length ? '$end' : '',
      totalCount: filtered.length,
    );
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
  //
  // buy/sell/recordDividend/recordSplit 的 [markPending] 三态语义(F10
  // FR-3):guest 缺省 false → holding 头行 synced;boundOfflineLocal /
  // boundRemote 降级传 true → holding 头行 pending(台账/lot 为无
  // syncState 的子表,镜像协调按 (accountId, securityId) 联动保留)。
  // createSecurity/updateSecurityPrice 操作证券表(无 syncState,引用数据),
  // 旗标忽略。

  Future<HoldingTransaction> buy({
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
    bool markPending = false,
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
        markPending: markPending,
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
    bool markPending = false,
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
        markPending: markPending,
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
    bool markPending = false,
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
            syncState: syncStateValue(markPending),
          ));
        } else {
          await _dao.updateHolding(db.HoldingsCompanion(
            id: Value(existing.id),
            quantity: Value(newQty),
            avgCostCents: Value(avg),
            version: Value(existing.version + 1),
            updatedAt: Value(now),
            syncState: markPending
                ? const Value(SyncState.pending)
                : const Value.absent(),
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
          syncState: markPending
              ? const Value(SyncState.pending)
              : const Value.absent(),
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
        await _txns.recordTransaction(
            RecordTransactionParams(
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
        ), markPending: markPending);
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
      await _txns.recordTransaction(
          RecordTransactionParams(
        transactionDate: date,
        description: '买入',
        entries: [
          TransactionEntry(
              accountId: accountId, debitCents: amount, creditCents: 0),
          TransactionEntry(
              accountId: fromAccountId, debitCents: 0, creditCents: amount),
          ],
        ), markPending: markPending);
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
    if (remaining > 0) {
      // Server errors when lots can't cover the sale (lot.go:56-58) — no
      // silent under-consumption (review F FR-2).
      throw const ValidationFailure('持仓数量不足');
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
    bool markPending = false,
  }) async {
    // Server recordDividend has no cash leg (accepted difference, ADR-1).
    final id = _uuid.v4();
    await _database.transaction(() async {
      // 台账行无 syncState:离线分红的保留依赖持有头行置 pending(镜像协调
      // 按 (accountId, securityId) 联动保台账)。无持仓行的裸分红属边角
      // (server 亦允许),该台账行不设保护,随上行批次补齐。
      if (markPending) {
        final existing = (await _dao.watchAllHoldings().first)
            .where(
                (h) => h.accountId == accountId && h.securityId == securityId)
            .firstOrNull;
        if (existing != null) {
          await _dao.updateHolding(db.HoldingsCompanion(
            id: Value(existing.id),
            syncState: const Value(SyncState.pending),
          ));
        }
      }
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
    });
    return _txnView((await _dao.getHoldingTransactionById(id))!);
  }

  Future<HoldingTransaction> recordSplit({
    required String accountId,
    required String securityId,
    required double ratio,
    required String splitDate,
    String? notes,
    bool markPending = false,
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
        syncState: markPending
            ? const Value(SyncState.pending)
            : const Value.absent(),
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
  //
  // 证券表无 syncState(引用数据,非 8 头表):repo 的 markPending 旗标对
  // 下述方法无意义,闭包层显式忽略(离线建证券/改价的保存语义留给 T3)。

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

  Future<PortfolioPerformance> getPortfolioPerformance({
    String range = 'MONTH',
    String? accountId,
    bool includeBenchmark = false,
    String baseCurrency = '',
  }) async {
    final now = DateTime.now();
    final rangeStart = switch (range) {
      'DAY' => DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30)),
      'MONTH' => DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 365)),
      'YEAR' => DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 365 * 3)),
      _ => null, // 全期
    };
    final hRows = await _database.select(_database.holdings).get();
    final tRows = await _database.select(_database.holdingTransactions).get();
    final sRows = await _database.select(_database.securities).get();

    final assembler = LocalPerformanceAssembler(
      holdings: [
        for (final h in hRows)
          if (accountId == null || h.accountId == accountId)
            AssemblerHolding(h.securityId, h.quantity, h.avgCostCents),
      ],
      trades: [
        for (final t in tRows)
          if (accountId == null || t.accountId == accountId)
            AssemblerTrade(
              securityId: t.securityId,
              tradeType: t.tradeType,
              quantity: t.quantity,
              priceCents: t.priceCents,
              amountCents: t.amountCents,
              feeCents: t.feeCents,
              realizedPnlCents: t.realizedPnlCents,
              tradeDate: t.tradeDate,
            ),
      ],
      securities: {
        for (final s in sRows) s.id: AssemblerSecurity(s.id, s.currentPriceCents),
      },
      now: now,
    );
    return assembler.assemble(rangeStart: rangeStart);
  }

  /// holding 级 performance 本地化 → 后续 polish(R7-D scope boundary):
  /// 优雅降级(空曲线+null 指标),不再 throw 炸页。
  Future<HoldingPerformance> getHoldingPerformance({
    required String holdingId,
    String range = 'MONTH',
    String baseCurrency = '',
  }) async {
    final h = await _dao.getHoldingById(holdingId);
    return HoldingPerformance(
      pricePoints: const [],
      realizedCents: 0,
      unrealizedCents: 0,
      totalCents: 0,
      currency: h != null ? await _securityCurrency(h.securityId) : 'CNY',
    );
  }

  Future<String> _securityCurrency(String securityId) async {
    final s = await _reference.getSecurityById(securityId);
    return s?.currencyCode ?? 'CNY';
  }

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
      // Liability ACCOUNT balances are deliberately NOT counted here — the
      // borrowedIn debt rows below carry the liability; counting both would
      // double-count (review E-#9).
    }
    // Caliber (post feature F): balances are LIVE via the linkage, so asset
    // balances carry real cost basis; the gain layer adds unrealized pnl.
    // ACCEPTED difference (review F-J2): after a SELL the investment account
    // is credited the proceeds (not the FIFO cost), so realized PnL is NOT
    // reflected in this guest net-worth number (bound-mode server numbers
    // include it) — divergence equals cumulative realized gross PnL.
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
