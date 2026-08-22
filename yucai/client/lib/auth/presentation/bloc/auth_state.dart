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

/// No credentials: first launch, explicit skip, or after logout. The app is
/// fully usable in this state (offline-first, R6); business routes resolve
/// their own data (empty/error until the dual-source seam lands).
class Guest extends AuthState {}

/// Credentials exist but the profile RPC failed on network grounds — the
/// session is kept (user is NOT kicked to /login). No User object: the
/// profile is unknown while offline (design ADR-1).
class OfflineAuthenticated extends AuthState {}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
