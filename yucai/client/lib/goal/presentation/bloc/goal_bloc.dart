import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_state.dart';

@injectable
class GoalBloc extends Bloc<GoalEvent, GoalState> {
  GoalBloc(this._repo) : super(GoalInitial()) {
    on<LoadListRequested>(_onLoadList);
    on<LoadDetailRequested>(_onLoadDetail);
    on<CreateGoalRequested>(_onCreate);
    on<UpdateGoalRequested>(_onUpdate);
    on<DeleteGoalRequested>(_onDelete);
    on<CompleteGoalRequested>(_onComplete);
    on<RecordContributionRequested>(_onRecordContribution);
    on<CloneGoalRequested>(_onClone);
  }

  final GoalRepository _repo;

  Future<void> _onLoadList(LoadListRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.listGoals(type: event.type);
    result.fold(
      (failure) => emit(GoalError(failure.displayMessage)),
      (goals) => emit(GoalListLoaded(goals)),
    );
  }

  Future<void> _onLoadDetail(LoadDetailRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.getGoal(event.id);
    result.fold(
      (failure) => emit(GoalError(failure.displayMessage)),
      (goal) => emit(GoalDetailLoaded(goal)),
    );
  }

  Future<void> _onCreate(CreateGoalRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.createGoal(
      name: event.name,
      type: event.type,
      targetAmountCents: event.target,
      deadline: event.deadline,
      linkedAccountIds: event.linkedAccountIds,
      linkedDebtIds: event.linkedDebtIds,
    );
    result.fold(
      (failure) => emit(GoalError(failure.displayMessage)),
      (_) => add(const LoadListRequested()),
    );
  }

  Future<void> _onUpdate(UpdateGoalRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.updateGoal(
      id: event.id,
      name: event.name,
      targetAmountCents: event.target,
      deadline: event.deadline,
      linkedAccountIds: event.linkedAccountIds,
      linkedDebtIds: event.linkedDebtIds,
    );
    result.fold(
      (failure) => emit(GoalError(failure.displayMessage)),
      (goal) => emit(GoalDetailLoaded(goal)),
    );
  }

  Future<void> _onDelete(DeleteGoalRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.deleteGoal(event.id);
    result.fold(
      (failure) => emit(GoalError(failure.displayMessage)),
      (_) => add(const LoadListRequested()),
    );
  }

  /// completeGoal 返回 void(proto Empty)。成功后重新拉取完整 detail,
  /// 因完成会改 server 端 isCompleted + actuals。
  Future<void> _onComplete(CompleteGoalRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.completeGoal(event.id);
    await result.fold(
      (failure) async => emit(GoalError(failure.displayMessage)),
      (_) async {
        final detail = await _repo.getGoal(event.id);
        detail.fold(
          (failure) => emit(GoalError(failure.displayMessage)),
          (goal) => emit(GoalDetailLoaded(goal)),
        );
      },
    );
  }

  /// recordContribution 返回的 GoalView 不保证含最新 actuals
  /// (照 budget AddItem re-fetch via getGoal 模式),成功后重新拉取完整 detail。
  Future<void> _onRecordContribution(RecordContributionRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.recordContribution(
      id: event.id,
      amountCents: event.amount,
    );
    await result.fold(
      (failure) async => emit(GoalError(failure.displayMessage)),
      (_) async {
        final detail = await _repo.getGoal(event.id);
        detail.fold(
          (failure) => emit(GoalError(failure.displayMessage)),
          (goal) => emit(GoalDetailLoaded(goal)),
        );
      },
    );
  }

  /// cloneGoal 返回的 GoalView 是克隆出的新目标,但 id 不同。为展示完整
  /// actuals(新克隆目标 actuals 通常为 0),成功后用返回的新目标 id 重新
  /// 拉取 detail。但 result.fold 的成功分支拿不到新 id(返回 void 化处理)——
  /// 实际 cloneGoal 返回 GoalView,这里用其 id re-fetch。
  Future<void> _onClone(CloneGoalRequested event, Emitter<GoalState> emit) async {
    emit(GoalLoading());
    final result = await _repo.cloneGoal(
      sourceId: event.sourceId,
      targetAmountCents: event.target,
      deadline: event.deadline,
      name: event.name,
    );
    await result.fold(
      (failure) async => emit(GoalError(failure.displayMessage)),
      (cloned) async {
        final detail = await _repo.getGoal(cloned.id);
        detail.fold(
          (failure) => emit(GoalError(failure.displayMessage)),
          (goal) => emit(GoalDetailLoaded(goal)),
        );
      },
    );
  }
}
