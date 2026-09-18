import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';

// @lazySingleton(非 @injectable):债务列表与 /new 表单是 sibling 路由,经
// BlocProvider.value 共享同一 DebtBloc(66a9e0e9 hotfix:factory 会让两路由各持
// 一份,创建后列表不刷新)。源注解必须与该契约一致,否则 build_runner regen
// 会静默回滚成 factory(F17-T2 实际踩中)。
@LazySingleton()
class DebtBloc extends Bloc<DebtEvent, DebtState> {
  DebtBloc(this._repo) : super(DebtInitial()) {
    on<LoadDebtsRequested>(_onLoadDebts);
    on<LoadDebtRequested>(_onLoadDebt);
    on<CreateDebtRequested>(_onCreate);
    on<UpdateDebtRequested>(_onUpdate);
    on<DeleteDebtRequested>(_onDelete);
    on<RecordPaymentRequested>(_onRecordPayment);
    on<SetPaymentDateRequested>(_onSetPaymentDate);
    on<MarkEntryPaidRequested>(_onMarkEntryPaid);
  }

  final DebtRepository _repo;

  List<Debt> _last = const [];

  /// 最近一次 create 成功返回的 Debt(含服务端/本地生成 id)。表单在
  /// BlocListener(DebtsLoaded)里读它拿新债务 id 绑定本地合同附件 —— 不进
  /// state(刷新态只携带列表,消费方无需感知);无 create 会话时为 null。
  Debt? lastCreated;

  /// LoadDebtsRequested:repo 层按 event.typeFilter 过滤(非空时)。
  ///
  /// 写后刷新(create/update/delete)一律 `LoadDebtsRequested()` 不带过滤:
  /// 本 bloc 是 debts/receivables 两条 branch 共享的单例,若按「最后一次
  /// 过滤」重放,先访债权页再回债务页创建 → 刷新加载的是 borrowedOut 列表,
  /// 债务页看不到新建债务(用户实测「添加债务没有任何显示」)。全量刷新后
  /// 两个页面各自在表现层按方向切片(_debtsOf),互不串扰。
  Future<void> _onLoadDebts(
    LoadDebtsRequested event,
    Emitter<DebtState> emit,
  ) async {
    emit(DebtLoading());
    final result = await _repo.list(typeFilter: event.typeFilter);
    result.fold(
      (f) => debugPrint('[DEBT-DIAG] list FAILED: ${f.displayMessage} typeFilter=${event.typeFilter}'),
      (debts) => debugPrint('[DEBT-DIAG] list loaded: ${debts.length} debts (borrowedIn=${debts.where((d) => d.type.index == 0).length}) typeFilter=${event.typeFilter}'),
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (debts) {
        _last = debts;
        emit(DebtsLoaded(debts));
      },
    );
  }

  Future<void> _onLoadDebt(
    LoadDebtRequested event,
    Emitter<DebtState> emit,
  ) async {
    emit(DebtLoading());
    final result = await _repo.get(event.id);
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (detail) => emit(DebtDetailLoaded(detail)),
    );
  }

  Future<void> _onCreate(
    CreateDebtRequested event,
    Emitter<DebtState> emit,
  ) async {
    final p = event.params;
    emit(DebtSubmitting(_last));
    final result = await _repo.create(
      accountId: p.accountId,
      counterparty: p.counterparty,
      interestRate: p.interestRate,
      amortizationIndex: p.amortizationIndex,
      startDate: p.startDateOption!,
      dueDate: p.dueDateOption!,
      totalPrincipalCents: p.totalPrincipalCents,
      type: p.type,
      subtype: p.subtype,
      sourceAccountId: p.sourceAccountId,
      contact: p.contact,
      contractRef: p.contractRef,
      guarantorName: p.guarantorName,
      guarantorContact: p.guarantorContact,
      collectionAccountId: p.collectionAccountId,
      cycle: p.cycle,
      interval: p.interval,
      weekdayMask: p.weekdayMask,
      monthlyMode: p.monthlyMode,
      nth: p.nth,
      termPeriods: p.termPeriods,
      interestWaivedCents: p.interestWaivedCents,
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (debt) {
        lastCreated = debt;
        add(const LoadDebtsRequested()); // refresh list on success
      },
    );
  }

  Future<void> _onUpdate(
    UpdateDebtRequested event,
    Emitter<DebtState> emit,
  ) async {
    final p = event.params;
    emit(DebtSubmitting(_last));
    final result = await _repo.update(
      id: p.id,
      counterparty: p.counterparty,
      interestRate: p.interestRate,
      version: p.version,
      contact: p.contact,
      contractRef: p.contractRef,
      guarantorName: p.guarantorName,
      guarantorContact: p.guarantorContact,
      collectionAccountId: p.collectionAccountId,
      amortizationIndex: p.amortizationIndex,
      dueDate: p.dueDate,
      termPeriods: p.termPeriods,
      cycle: p.cycle,
      interval: p.interval,
      weekdayMask: p.weekdayMask,
      monthlyMode: p.monthlyMode,
      nth: p.nth,
      interestWaivedCents: p.interestWaivedCents,
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) => add(const LoadDebtsRequested()), // refresh list on success
    );
  }

  Future<void> _onDelete(
    DeleteDebtRequested event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repo.delete(event.id);
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) => add(const LoadDebtsRequested()), // refresh list on success
    );
  }

  Future<void> _onRecordPayment(
    RecordPaymentRequested event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repo.recordPayment(
      debtId: event.debtId,
      scheduleEntryId: event.scheduleEntryId,
      fromAccountId: event.fromAccountId,
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) => add(LoadDebtRequested(event.debtId)), // refresh detail on success
    );
  }

  /// 单期改日(Google-Calendar 式):成功后刷新详情。
  Future<void> _onSetPaymentDate(
    SetPaymentDateRequested event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repo.setPaymentDate(
      debtId: event.debtId,
      entryId: event.entryId,
      paymentDate: event.paymentDate,
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) => add(LoadDebtRequested(event.debtId)),
    );
  }

  /// 标记已还(历史还款,不记账):成功后刷新详情。
  Future<void> _onMarkEntryPaid(
    MarkEntryPaidRequested event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repo.markEntryPaid(
      debtId: event.debtId,
      entryId: event.entryId,
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) => add(LoadDebtRequested(event.debtId)),
    );
  }
}
