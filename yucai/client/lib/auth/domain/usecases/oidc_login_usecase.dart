import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/data/oidc_authenticator.dart';
import 'package:yucai_client/auth/domain/entities/oidc_provider.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

/// Orchestrates the full OIDC login flow on top of the lower-level
/// repository primitives:
///
/// 1. Fetch the server-advertised provider list and resolve the requested
///    provider name to its [OidcProviderConfig].
/// 2. Drive [OIDCAuthenticator] to run the loopback PKCE dance and obtain
///    an authorization `code` + `verifier`.
/// 3. Forward those to `AuthRepository.oidcExchange`, which exchanges them
///    with the server for access + refresh tokens.
///
/// The repository stays free of OIDC flow knowledge (it only does the
/// token-exchange RPC); this usecase is the single place that owns the
/// browser-redirect orchestration.
@injectable
class OidcLoginUseCase {
  OidcLoginUseCase(this._repo, this._authenticator);

  final AuthRepository _repo;
  final OIDCAuthenticator _authenticator;

  Future<Either<Failure, User>> call(String provider) async {
    final configResult = await _repo.getOIDCConfig();
    if (configResult.isLeft()) {
      return Left((configResult as Left).value as Failure);
    }
    final configs = (configResult as Right).value as List<OidcProviderConfig>;
    if (!configs.any((p) => p.name == provider)) {
      return Left(UnexpectedFailure('unknown OIDC provider: $provider'));
    }
    final config = configs.firstWhere((p) => p.name == provider);

    try {
      final auth = await _authenticator.authenticate(config);
      return _repo.oidcExchange(
        provider: provider,
        code: auth.code,
        codeVerifier: auth.verifier,
        redirectUri: auth.redirectUri,
      );
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
