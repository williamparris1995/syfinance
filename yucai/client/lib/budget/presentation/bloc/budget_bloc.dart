import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';

// @lazySingleton(非 @injectable):预算列表与表单 sibling 路由 .value 共享
// (68f30495 router .value sharing fix);注解须与契约一致防 regen 回滚。
@LazySingleton()
class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  BudgetBloc(this._repo) : super(BudgetInitial()) {
    on<LoadListRequested>(_onLoadList);
    on<LoadDetailRequested>(_onLoadDetail);
    on<CreateBudgetRequested>(_onCreate);
    on<UpdateBudgetRequested>(_onUpdate);
    on<DeleteBudgetRequested>(_onDelete);
    on<AddItemRequested>(_onAddItem);
    on<RemoveItemRequested>(_onRemoveItem);
  }

  final BudgetRepository _repo;

  Future<void> _onLoadList(LoadListRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.listBudgets(activeOnly: event.activeOnly);
    result.fold(
      (failure) => emit(BudgetError(failure.displayMessage)),
      (budgets) => emit(BudgetListLoaded(budgets)),
    );
  }

  Future<void> _onLoadDetail(LoadDetailRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.getBudget(event.id);
    result.fold(
      (failure) => emit(BudgetError(failure.displayMessage)),
      (budget) => emit(BudgetDetailLoaded(budget)),
    );
  }

  Future<void> _onCreate(CreateBudgetRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.createBudget(
      name: event.name,
      month: event.month,
      currencyCode: event.currencyCode,
      items: event.items,
    );
    result.fold(
      (failure) => emit(BudgetError(failure.displayMessage)),
      (_) => add(const LoadListRequested()),
    );
  }

  /// updateBudget 返回 BudgetDTO(无 items),重新拉完整 budget 回填 items
  /// (照 _onAddItem/_onRemoveItem)。edit 成功 → BudgetDetailLoaded(带新数据,
  /// form 据此 pop 返回 detail 页)。
  Future<void> _onUpdate(UpdateBudgetRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.updateBudget(
      id: event.budgetId,
      name: event.name,
      currencyCode: event.currencyCode,
      items: event.items,
    );
    await result.fold(
      (failure) async => emit(BudgetError(failure.displayMessage)),
      (_) async {
        final detail = await _repo.getBudget(event.budgetId);
        detail.fold(
          (failure) => emit(BudgetError(failure.displayMessage)),
          (budget) => emit(BudgetDetailLoaded(budget)),
        );
      },
    );
  }

  Future<void> _onDelete(DeleteBudgetRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.deleteBudget(event.id);
    result.fold(
      (failure) => emit(BudgetError(failure.displayMessage)),
      (_) => add(const LoadListRequested()),
    );
  }

  /// addItem 返回的 BudgetView 是 BudgetDTO(无 items),直接 emit 会导致详情页
  /// items 丢失。故成功后重新拉取完整 budget(getBudget detail 路径,含 items),
  /// emit BudgetDetailLoaded。
  Future<void> _onAddItem(AddItemRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.addItem(
      budgetId: event.budgetId,
      accountId: event.accountId,
      plannedAmountCents: event.plannedAmountCents,
      notes: event.notes,
    );
    await result.fold(
      (failure) async => emit(BudgetError(failure.displayMessage)),
      (_) async {
        final detail = await _repo.getBudget(event.budgetId);
        detail.fold(
          (failure) => emit(BudgetError(failure.displayMessage)),
          (budget) => emit(BudgetDetailLoaded(budget)),
        );
      },
    );
  }

  /// 同 _onAddItem:removeItem 返回 BudgetDTO(无 items),重新拉取完整 budget。
  Future<void> _onRemoveItem(RemoveItemRequested event, Emitter<BudgetState> emit) async {
    emit(BudgetLoading());
    final result = await _repo.removeItem(
      budgetId: event.budgetId,
      itemId: event.itemId,
    );
    await result.fold(
      (failure) async => emit(BudgetError(failure.displayMessage)),
      (_) async {
        final detail = await _repo.getBudget(event.budgetId);
        detail.fold(
          (failure) => emit(BudgetError(failure.displayMessage)),
          (budget) => emit(BudgetDetailLoaded(budget)),
        );
      },
    );
  }
}
