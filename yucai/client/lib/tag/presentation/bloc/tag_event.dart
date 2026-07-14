import 'package:equatable/equatable.dart';

abstract class TagEvent extends Equatable {
  const TagEvent();
  @override
  List<Object?> get props => [];
}

class LoadTagsRequested extends TagEvent {}

class CreateTagRequested extends TagEvent {
  const CreateTagRequested(this.name, this.color);
  final String name;
  final String color;
  @override
  List<Object?> get props => [name, color];
}

class UpdateTagRequested extends TagEvent {
  const UpdateTagRequested({required this.id, required this.name, required this.color, required this.version});
  final String id;
  final String name;
  final String color;
  final int version;
  @override
  List<Object?> get props => [id, name, color, version];
}

class DeleteTagRequested extends TagEvent {
  const DeleteTagRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class LoadTransactionTagsRequested extends TagEvent {
  const LoadTransactionTagsRequested(this.transactionId);
  final String transactionId;
  @override
  List<Object?> get props => [transactionId];
}
