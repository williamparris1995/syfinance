import 'package:equatable/equatable.dart';

import 'package:yucai_client/tag/domain/entities/tag_entity.dart';

abstract class TagState extends Equatable {
  const TagState();
  @override
  List<Object?> get props => [];
}

class TagInitial extends TagState {}

class TagLoading extends TagState {}

class TagsLoaded extends TagState {
  const TagsLoaded(this.tags);
  final List<Tag> tags;
  @override
  List<Object?> get props => [tags];
}

class TagSubmitting extends TagState {}

/// 一次性成功反馈(create/update/delete)—— UI BlocListener 捕获 message 显示 SnackBar。
class TagActionSuccess extends TagState {
  const TagActionSuccess(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class TagError extends TagState {
  const TagError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// 单 transaction 的 tags(表单编辑预选 / 详情显示)。
class TransactionTagsLoaded extends TagState {
  const TransactionTagsLoaded(this.transactionId, this.tags);
  final String transactionId;
  final List<Tag> tags;
  @override
  List<Object?> get props => [transactionId, tags];
}
