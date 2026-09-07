import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
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
  }

  final DebtRepository _repo;

  List<Debt> _last = const [];

  /// 上一次 LoadDebtsRequested 携带的 typeFilter。create/update/delete 成功后的
  /// 刷新用它重放,使 debts_page(borrowedIn)与 receivables_page(borrowedOut)
  /// 的内联操作不会因刷新重置为「全部」而泄漏另一方向的债务。
  DebtType? _lastTypeFilter;

  Future<void> _onLoadDebts(
    LoadDebtsRequested event,
    Emitter<DebtState> emit,
  ) async {
    _lastTypeFilter = event.typeFilter;
    emit(DebtLoading());
    final result = await _repo.list(typeFilter: event.typeFilter);
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
      collectionAccountId: p.collectionAccountId,
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) =>
          add(LoadDebtsRequested(typeFilter: _lastTypeFilter)), // refresh list on success
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
      collectionAccountId: p.collectionAccountId,
    );
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) =>
          add(LoadDebtsRequested(typeFilter: _lastTypeFilter)), // refresh list on success
    );
  }

  Future<void> _onDelete(
    DeleteDebtRequested event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repo.delete(event.id);
    result.fold(
      (failure) => emit(DebtError(failure.displayMessage, last: _last)),
      (_) =>
          add(LoadDebtsRequested(typeFilter: _lastTypeFilter)), // refresh list on success
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
}
