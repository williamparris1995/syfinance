import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';

@injectable
class HoldingBloc extends Bloc<HoldingEvent, HoldingState> {
  HoldingBloc(this._repo) : super(HoldingInitial()) {
    on<LoadHoldingsRequested>(_onLoadHoldings);
    on<LoadDetailRequested>(_onLoadDetail);
    on<LoadSecuritiesRequested>(_onLoadSecurities);
    on<SearchSecuritiesRequested>(_onSearchSecurities);
    on<BuyRequested>(_onBuy);
    on<SellRequested>(_onSell);
    on<RecordDividendRequested>(_onRecordDividend);
    on<RecordSplitRequested>(_onRecordSplit);
    on<CreateSecurityRequested>(_onCreateSecurity);
    on<UpdatePriceRequested>(_onUpdatePrice);
    on<RefreshPricesRequested>(_onRefreshPrices);
    on<LoadHoldingCurveRequested>(_onLoadHoldingCurve);
  }

  final HoldingRepository _repo;

  /// 上次列表态(成功),供 Error/Submitting 恢复背景。
  HoldingState? _last;
  /// 上次 LoadHoldingsRequested 的 typeFilter,业务成功后自刷新重放。
  SecurityType? _lastFilter;
  /// 上次证券列表(表单选择器背景,LoadSecurities 成功后更新)。
  List<Security> _lastSecurities = const [];
  /// 上次价格刷新时间(client 本地,刷新成功后更新,_onLoadHoldings 带入 state)。
  DateTime? _lastPriceSyncedAt;

  /// 从 holdings 聚合 summary。totalCostCents 按 quantity*avgCostCents 重建
  /// (proto HoldingDTO 未暴露总成本);totalPnlCents 来自 unrealizedPnlCents。
  HoldingSummary _summarize(List<Holding> holdings) {
    var cost = 0;
    var mv = 0;
    var pnl = 0;
    for (final h in holdings) {
      cost += (h.quantity * h.avgCostCents).round();
      mv += h.marketValueCents;
      pnl += h.unrealizedPnlCents;
    }
    return HoldingSummary(
      totalCostCents: cost,
      totalMarketValueCents: mv,
      totalPnlCents: pnl,
    );
  }

  Future<void> _onLoadHoldings(
    LoadHoldingsRequested event,
    Emitter<HoldingState> emit,
  ) async {
    _lastFilter = event.typeFilter;
    emit(HoldingLoading());
    final result = await _repo.listHoldings();
    result.fold(
      (failure) => emit(HoldingError(failure.displayMessage, last: _last)),
      (holdings) {
        final loaded = HoldingLoaded(
          holdings: holdings,
          summary: _summarize(holdings),
          securities: _lastSecurities,
          typeFilter: event.typeFilter,
          lastPriceSyncedAt: _lastPriceSyncedAt,
        );
        _last = loaded;
        emit(loaded);
      },
    );
  }

  /// 详情加载:listHoldings 找单条 + listHoldingTransactions 取流水。
  ///
  /// 后端✅已实现(holding_handler.go:229)。fail 仅作兜底降级(网络/后端异常)
  /// → HoldingDetailLoaded(found, trades: [], isPendingBackend: true),
  /// holding 仍展示,交易历史区空态。listHoldings fail / holding not found
  /// → HoldingError(无 holding,真业务错误)。
  Future<void> _onLoadDetail(
    LoadDetailRequested event,
    Emitter<HoldingState> emit,
  ) async {
    emit(HoldingLoading());
    final holdingResult = await _repo.listHoldings();
    // 先处理 listHoldings fail(真错误,无 holding)。
    if (holdingResult.isLeft()) {
      final failure = holdingResult
          .swap()
          .getOrElse(() => const ServerFailure('listHoldings'));
      emit(HoldingError(failure.displayMessage, last: _last));
      return;
    }
    final holdings = holdingResult.getOrElse(() => const <Holding>[]);
    Holding? maybeFound;
    for (final item in holdings) {
      if (item.id == event.id) {
        maybeFound = item;
        break;
      }
    }
    // holding not found(真业务错误,无 holding)。
    if (maybeFound == null) {
      emit(HoldingError('holding not found', last: _last));
      return;
    }
    final found = maybeFound; // 非空,下游闭包可提升。
    // ⚠️ 用 securityId(非 holding id)过滤交易:ListTradesRequest.security_id
    // 按 security 维度取流水;holding id 与 security id 不同,传 holding id 会
    // 返回错误(空)交易列表。found.id 仍用于上面 firstWhere 找持仓(正确)。
    final tradesResult =
        await _repo.listHoldingTransactions(securityId: found.securityId);
    tradesResult.fold(
      // 兜底降级:holding 保留,交易历史空态(后端异常/网络 fail 时,brief:交易历史区空态,非整页)。
      (_) => emit(HoldingDetailLoaded(
        holding: found,
        trades: const [],
        isPendingBackend: true,
      )),
      (trades) => emit(HoldingDetailLoaded(holding: found, trades: trades)),
    );
  }

  Future<void> _onLoadSecurities(
    LoadSecuritiesRequested event,
    Emitter<HoldingState> emit,
  ) async {
    emit(HoldingLoading());
    final result = await _repo.listSecurities(type: event.type);
    result.fold(
      (failure) => emit(HoldingError(failure.displayMessage, last: _last)),
      (securities) {
        _lastSecurities = securities;
        // 不覆盖 _last(列表态):securities 是表单数据,复用上次 holdings 背景。
        if (_last is HoldingLoaded) {
          final prev = _last as HoldingLoaded;
          final updated = HoldingLoaded(
            holdings: prev.holdings,
            summary: prev.summary,
            securities: securities,
            typeFilter: prev.typeFilter,
            lastPriceSyncedAt: _lastPriceSyncedAt,
          );
          _last = updated;
          emit(updated);
        } else {
          emit(HoldingLoaded(
            holdings: const [],
            summary: const HoldingSummary(
              totalCostCents: 0,
              totalMarketValueCents: 0,
              totalPnlCents: 0,
            ),
            securities: securities,
            lastPriceSyncedAt: _lastPriceSyncedAt,
          ));
        }
      },
    );
  }

  Future<void> _onSearchSecurities(
    SearchSecuritiesRequested event,
    Emitter<HoldingState> emit,
  ) async {
    final result = await _repo.searchSecurities(event.query);
    result.fold(
      (failure) => emit(HoldingError(failure.displayMessage, last: _last)),
      (securities) {
        _lastSecurities = securities;
        emit(HoldingLoaded(
          holdings: const [],
          summary: const HoldingSummary(
            totalCostCents: 0,
            totalMarketValueCents: 0,
            totalPnlCents: 0,
          ),
          securities: securities,
          lastPriceSyncedAt: _lastPriceSyncedAt,
        ));
      },
    );
  }

  // —— 业务事件:Submitting(last) → repo → Right 自刷新 / Left Error ——

  Future<void> _onBuy(
    BuyRequested event,
    Emitter<HoldingState> emit,
  ) async {
    final p = event.params;
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.buy(
      accountId: p.accountId,
      securityId: p.securityId,
      fromAccountId: p.fromAccountId,
      quantity: p.quantity,
      priceCents: p.priceCents,
      feeCents: p.feeCents,
      tradeDate: p.tradeDate,
      notes: p.notes,
    );
    result.fold(
      (failure) =>
          emit(HoldingError(failure.displayMessage, last: _last)),
      (_) => add(LoadHoldingsRequested(typeFilter: _lastFilter)),
    );
  }

  Future<void> _onSell(
    SellRequested event,
    Emitter<HoldingState> emit,
  ) async {
    final p = event.params;
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.sell(
      accountId: p.accountId,
      securityId: p.securityId,
      fromAccountId: p.fromAccountId,
      quantity: p.quantity,
      priceCents: p.priceCents,
      feeCents: p.feeCents,
      tradeDate: p.tradeDate,
      notes: p.notes,
    );
    result.fold(
      (failure) =>
          emit(HoldingError(failure.displayMessage, last: _last)),
      (_) => add(LoadHoldingsRequested(typeFilter: _lastFilter)),
    );
  }

  Future<void> _onRecordDividend(
    RecordDividendRequested event,
    Emitter<HoldingState> emit,
  ) async {
    final p = event.params;
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.recordDividend(
      accountId: p.accountId,
      securityId: p.securityId,
      quantity: p.quantity,
      cashPerShareCents: p.cashPerShareCents,
      totalAmountCents: p.totalAmountCents,
      tradeDate: p.tradeDate,
      notes: p.notes,
    );
    result.fold(
      (failure) =>
          emit(HoldingError(failure.displayMessage, last: _last)),
      (_) => add(LoadHoldingsRequested(typeFilter: _lastFilter)),
    );
  }

  Future<void> _onRecordSplit(
    RecordSplitRequested event,
    Emitter<HoldingState> emit,
  ) async {
    final p = event.params;
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.recordSplit(
      accountId: p.accountId,
      securityId: p.securityId,
      ratio: p.ratio,
      splitDate: p.splitDate,
      notes: p.notes,
    );
    result.fold(
      (failure) =>
          emit(HoldingError(failure.displayMessage, last: _last)),
      (_) => add(LoadHoldingsRequested(typeFilter: _lastFilter)),
    );
  }

  Future<void> _onCreateSecurity(
    CreateSecurityRequested event,
    Emitter<HoldingState> emit,
  ) async {
    final p = event.params;
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.createSecurity(
      symbol: p.symbol,
      name: p.name,
      type: p.type,
      exchange: p.exchange,
      currency: p.currency,
    );
    result.fold(
      (failure) =>
          emit(HoldingError(failure.displayMessage, last: _last)),
      (_) => add(LoadSecuritiesRequested()),
    );
  }

  Future<void> _onUpdatePrice(
    UpdatePriceRequested event,
    Emitter<HoldingState> emit,
  ) async {
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.updateSecurityPrice(
      id: event.id,
      priceCents: event.priceCents,
    );
    result.fold(
      (failure) =>
          emit(HoldingError(failure.displayMessage, last: _last)),
      (_) => add(LoadHoldingsRequested(typeFilter: _lastFilter)),
    );
  }

  /// 手动刷新价格:调 repo.syncPrices(server 批量拉价)→ 成功则记录时间 +
  /// 重发 LoadHoldingsRequested(用新价格重算 marketValue/pnl);失败 HoldingError。
  Future<void> _onRefreshPrices(
    RefreshPricesRequested event,
    Emitter<HoldingState> emit,
  ) async {
    emit(HoldingSubmitting(last: _last));
    final result = await _repo.syncPrices();
    result.fold(
      (failure) => emit(HoldingError(failure.displayMessage, last: _last)),
      (r) {
        _lastPriceSyncedAt = r.syncedAt;
        add(LoadHoldingsRequested(typeFilter: _lastFilter));
      },
    );
  }

  /// 拉单持仓价格曲线(Task 13,holding-C 子事件)。
  ///
  /// range tab 切换时**仅更新曲线**(不重拉 holding/trades)。成功 →
  /// 在现有 HoldingDetailLoaded 基础上 copyWith 曲线(pricePoints +
  /// realizedCents)。失败 → 保留当前态,曲线区空态(对齐 isPendingBackend
  /// 降级风格:不整页报错)。
  ///
  /// ⚠️ 读 `state`(bloc 当前态)而非 `_last`:detail 页 LoadDetail 不写 _last
  /// (仅列表态写),但 detail loaded 态即当前 state,故从 state 取 current。
  Future<void> _onLoadHoldingCurve(
    LoadHoldingCurveRequested event,
    Emitter<HoldingState> emit,
  ) async {
    final result = await _repo.getHoldingPerformance(
      holdingId: event.holdingId,
      range: event.range,
      baseCurrency: event.baseCurrency,
    );
    final current = state is HoldingDetailLoaded
        ? state as HoldingDetailLoaded
        : null;
    result.fold(
      (f) => emit(current != null
          ? current.copyWith() // 保留,curve 区空态。
          : HoldingError(f.displayMessage, last: _last)),
      (perf) {
        if (current == null) return; // 无 current 态:无承载,忽略(不应发生)。
        emit(current.copyWith(
          holdingCurve: perf.pricePoints,
          holdingCurveRealizedCents: perf.realizedCents,
        ));
      },
    );
  }
}
