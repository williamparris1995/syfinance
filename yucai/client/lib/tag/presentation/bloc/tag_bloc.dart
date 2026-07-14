import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_event.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_state.dart';

@injectable
class TagBloc extends Bloc<TagEvent, TagState> {
  TagBloc(this._repo) : super(TagInitial()) {
    on<LoadTagsRequested>(_onLoad);
    on<CreateTagRequested>(_onCreate);
    on<UpdateTagRequested>(_onUpdate);
    on<DeleteTagRequested>(_onDelete);
    on<LoadTransactionTagsRequested>(_onLoadTransactionTags);
  }

  final TagRepository _repo;

  Future<void> _onLoad(LoadTagsRequested event, Emitter<TagState> emit) async {
    emit(TagLoading());
    final result = await _repo.list();
    result.fold(
      (failure) => emit(TagError(failure.displayMessage)),
      (tags) => emit(TagsLoaded(tags)),
    );
  }

  Future<void> _onCreate(CreateTagRequested event, Emitter<TagState> emit) async {
    emit(TagSubmitting());
    final result = await _repo.create(name: event.name, color: event.color);
    result.fold(
      (failure) => emit(TagError(failure.displayMessage)),
      (_) {
        emit(const TagActionSuccess('标签已创建'));
        add(LoadTagsRequested());
      },
    );
  }

  Future<void> _onUpdate(UpdateTagRequested event, Emitter<TagState> emit) async {
    emit(TagSubmitting());
    final result = await _repo.update(
      id: event.id, name: event.name, color: event.color, version: event.version,
    );
    result.fold(
      (failure) => emit(TagError(failure.displayMessage)),
      (_) {
        emit(const TagActionSuccess('标签已更新'));
        add(LoadTagsRequested());
      },
    );
  }

  Future<void> _onDelete(DeleteTagRequested event, Emitter<TagState> emit) async {
    emit(TagSubmitting());
    final result = await _repo.delete(event.id);
    result.fold(
      (failure) => emit(TagError(failure.displayMessage)),
      (_) {
        emit(const TagActionSuccess('标签已删除'));
        add(LoadTagsRequested());
      },
    );
  }

  Future<void> _onLoadTransactionTags(
    LoadTransactionTagsRequested event, Emitter<TagState> emit,
  ) async {
    final result = await _repo.getTransactionTags(event.transactionId);
    result.fold(
      (failure) => emit(TagError(failure.displayMessage)),
      (tags) => emit(TransactionTagsLoaded(event.transactionId, tags)),
    );
  }
}
