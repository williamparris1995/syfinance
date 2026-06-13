import 'package:equatable/equatable.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;
  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
