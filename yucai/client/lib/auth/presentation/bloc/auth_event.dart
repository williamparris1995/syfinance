import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  const RegisterRequested({required this.email, required this.password, required this.displayName});
  final String email;
  final String password;
  final String displayName;
  @override
  List<Object?> get props => [email, password, displayName];
}

class LogoutRequested extends AuthEvent {}

class TokenRefreshFailed extends AuthEvent {}
