import 'package:dartz/dartz.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/entities/oidc_provider.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

/// Port interface for authentication. Data layer implements this.
///
/// The repository only owns the low-level token-exchange RPC; it does **not**
/// know how the authorization code was obtained. The PKCE/loopback flow
/// orchestration lives in `OIDCAuthenticator` + `OidcLoginUseCase`, keeping
/// the repository independently testable.
abstract class AuthRepository {
  /// Lists OIDC providers advertised by the server (for the login screen).
  Future<Either<Failure, List<OidcProviderConfig>>> getOIDCConfig();

  /// Exchanges an OIDC authorization code (obtained upstream by the
  /// authenticator) for access + refresh tokens. Saves tokens on success.
  Future<Either<Failure, User>> oidcExchange({
    required String provider,
    required String code,
    required String codeVerifier,
    required String redirectUri,
  });

  Future<Either<Failure, AuthTokens>> refreshToken();
  Future<Either<Failure, User>> getProfile();
  Future<void> logout();

  /// Whether any credentials persist locally. Drives the AppStarted fork:
  /// no credentials → guest without a doomed profile RPC; with credentials →
  /// profile call whose NetworkFailure keeps the offline session (R6 FR-1).
  Future<bool> hasStoredCredentials();
}
