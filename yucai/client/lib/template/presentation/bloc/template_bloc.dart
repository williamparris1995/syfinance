import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/utils/date_format.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/template/presentation/bloc/template_event.dart';
import 'package:yucai_client/template/presentation/bloc/template_state.dart';

@injectable
class TemplateBloc extends Bloc<TemplateEvent, TemplateState> {
  TemplateBloc(this._repo) : super(TemplateInitial()) {
    on<LoadTemplatesRequested>(_onLoad);
    on<CreateTemplateRequested>(_onCreate);
    on<UpdateTemplateRequested>(_onUpdate);
    on<DeleteTemplateRequested>(_onDelete);
    on<PauseTemplateRequested>(_onPause);
    on<ResumeTemplateRequested>(_onResume);
    on<RecordTemplateRequested>(_onRecord);
  }

  final TemplateRepository _repo;

  Future<void> _onLoad(
    LoadTemplatesRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(TemplateLoading());
    final result = await _repo.list();
    result.fold(
      (failure) => emit(TemplateError(failure.displayMessage)),
      (templates) => emit(TemplatesLoaded(templates)),
    );
  }

  Future<void> _onCreate(
    CreateTemplateRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(TemplateSubmitting());
    final result = await _repo.create(
      name: event.name,
      description: event.description,
      amountCents: event.amountCents,
      direction: event.direction,
      sourceAccountId: event.sourceAccountId,
      destinationAccountId: event.destinationAccountId,
      cycle: event.cycle,
      cycleDays: event.cycleDays,
      billingDay: event.billingDay,
      interval: event.interval,
      weekdayMask: event.weekdayMask,
      monthlyMode: event.monthlyMode,
      nth: event.nth,
      startDate: event.startDate,
      endDate: event.endDate,
      autoRecord: event.autoRecord,
      category: event.category,
    );
    result.fold(
      (failure) => emit(TemplateError(failure.displayMessage)),
      (_) {
        emit(const TemplateActionSuccess('模板已创建'));
        add(LoadTemplatesRequested());
      },
    );
  }

  Future<void> _onUpdate(
    UpdateTemplateRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(TemplateSubmitting());
    final result = await _repo.update(
      id: event.id,
      version: event.version,
      name: event.name,
      description: event.description,
      amountCents: event.amountCents,
      cycle: event.cycle,
      cycleDays: event.cycleDays,
      billingDay: event.billingDay,
      interval: event.interval,
      weekdayMask: event.weekdayMask,
      monthlyMode: event.monthlyMode,
      nth: event.nth,
      endDate: event.endDate,
      autoRecord: event.autoRecord,
    );
    result.fold(
      (failure) => emit(TemplateError(failure.displayMessage)),
      (_) {
        emit(const TemplateActionSuccess('模板已更新'));
        add(LoadTemplatesRequested());
      },
    );
  }

  Future<void> _onDelete(
    DeleteTemplateRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(TemplateSubmitting());
    final result = await _repo.delete(event.id);
    result.fold(
      (failure) => emit(TemplateError(failure.displayMessage)),
      (_) {
        emit(const TemplateActionSuccess('模板已删除'));
        add(LoadTemplatesRequested());
      },
    );
  }

  Future<void> _onPause(
    PauseTemplateRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(TemplateSubmitting());
    final result = await _repo.pause(event.id);
    result.fold(
      (failure) => emit(TemplateError(failure.displayMessage)),
      (_) {
        emit(const TemplateActionSuccess('模板已暂停'));
        add(LoadTemplatesRequested());
      },
    );
  }

  Future<void> _onResume(
    ResumeTemplateRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(TemplateSubmitting());
    final result = await _repo.resume(event.id);
    result.fold(
      (failure) => emit(TemplateError(failure.displayMessage)),
      (_) {
        emit(const TemplateActionSuccess('模板已恢复'));
        add(LoadTemplatesRequested());
      },
    );
  }

  Future<void> _onRecord(
    RecordTemplateRequested event,
    Emitter<TemplateState> emit,
  ) async {
    emit(TemplateSubmitting());
    final result = await _repo.record(event.id);
    result.fold(
      (failure) => emit(TemplateError(failure.displayMessage)),
      (recordResult) {
        final next = recordResult.nextDate;
        final msg = next == null
            ? '已记录'
            : '已记录(下次 ${formatDate(next)})';
        emit(TemplateActionSuccess(msg));
        add(LoadTemplatesRequested());
      },
    );
  }
}
