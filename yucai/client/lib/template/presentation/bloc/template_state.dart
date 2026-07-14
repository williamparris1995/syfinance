import 'package:equatable/equatable.dart';

import 'package:yucai_client/template/domain/entities/template_entity.dart';

abstract class TemplateState extends Equatable {
  const TemplateState();
  @override
  List<Object?> get props => [];
}

class TemplateInitial extends TemplateState {}

class TemplateLoading extends TemplateState {}

class TemplatesLoaded extends TemplateState {
  const TemplatesLoaded(this.templates);
  final List<Template> templates;
  @override
  List<Object?> get props => [templates];
}

class TemplateSubmitting extends TemplateState {}

/// 一次性成功反馈(create/update/delete/pause/resume/record)—— UI BlocListener
/// 捕获 message 显示 SnackBar。
class TemplateActionSuccess extends TemplateState {
  const TemplateActionSuccess(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class TemplateError extends TemplateState {
  const TemplateError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
