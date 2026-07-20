import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

/// Kick off the full OIDC login flow for the named provider (e.g. "google").
/// The bloc delegates to `OidcLoginUseCase`, which drives the loopback PKCE
/// dance + token exchange.
class OIDCLoginRequested extends AuthEvent {
  const OIDCLoginRequested(this.provider);
  final String provider;
  @override
  List<Object?> get props => [provider];
}

class LogoutRequested extends AuthEvent {}

class TokenRefreshFailed extends AuthEvent {}
