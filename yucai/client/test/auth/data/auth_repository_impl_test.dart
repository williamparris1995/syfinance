import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/data/auth_repository_impl.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/entities/oidc_provider.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}
class _MockStorage extends Mock implements TokenStorage {}

void main() {
  late _MockRemote remote;
  late _MockStorage storage;
  late AuthRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    storage = _MockStorage();
    repo = AuthRepositoryImpl(remote, storage);
    registerFallbackValue(const AuthTokens(accessToken: 'a', refreshToken: 'r'));
  });

  final user = User(
      id: 'u1',
      tenantId: 't1',
      email: 'a@b.com',
      displayName: 'A',
      avatarUrl: '',
      createdAt: DateTime(2026));

  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

  group('getOIDCConfig', () {
    test('success returns Right(providers)', () async {
      final providers = [
        OidcProviderConfig(
          name: 'google',
          displayName: 'Google',
          issuer: 'https://accounts.google.com',
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
          clientId: 'cid',
          scopes: const ['openid', 'email'],
        ),
      ];
      when(() => remote.getOIDCConfig()).thenAnswer((_) async => providers);

      final result = await repo.getOIDCConfig();

      expect(result, Right<Failure, List<OidcProviderConfig>>(providers));
    });

    test('GrpcError unavailable maps to NetworkFailure', () async {
      when(() => remote.getOIDCConfig())
          .thenThrow(GrpcError.unavailable('down'));

      final result = await repo.getOIDCConfig();

      expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
    });
  });

  group('oidcExchange', () {
    test('success returns Right(user) and saves tokens', () async {
      when(() => remote.oidcExchange(
            provider: any(named: 'provider'),
            code: any(named: 'code'),
            codeVerifier: any(named: 'codeVerifier'),
            redirectUri: any(named: 'redirectUri'),
          )).thenAnswer((_) async => (user: user, tokens: tokens));
      when(() => storage.saveTokens(any())).thenAnswer((_) async {});

      final result = await repo.oidcExchange(
        provider: 'google',
        code: 'c',
        codeVerifier: 'v',
        redirectUri: 'http://localhost:1/callback',
      );

      expect(result, Right<Failure, User>(user));
      verify(() => storage.saveTokens(tokens)).called(1);
    });

    test('GrpcError unauthenticated maps to AuthFailure', () async {
      when(() => remote.oidcExchange(
            provider: any(named: 'provider'),
            code: any(named: 'code'),
            codeVerifier: any(named: 'codeVerifier'),
            redirectUri: any(named: 'redirectUri'),
          )).thenThrow(GrpcError.unauthenticated('invalid'));

      final result = await repo.oidcExchange(
        provider: 'google',
        code: 'c',
        codeVerifier: 'v',
        redirectUri: 'http://localhost:1/callback',
      );

      expect(result.fold((l) => l, (_) => null), isA<AuthFailure>());
    });
  });

  test('refreshToken with no stored token returns AuthFailure', () async {
    when(() => storage.readTokens()).thenAnswer((_) async => null);
    final result = await repo.refreshToken();
    expect(result.fold((l) => l, (_) => null), isA<AuthFailure>());
  });

  test('refreshToken success saves new tokens', () async {
    final tokens = const AuthTokens(accessToken: 'a2', refreshToken: 'r2');
    when(() => storage.readTokens())
        .thenAnswer((_) async => const AuthTokens(accessToken: 'a', refreshToken: 'r'));
    when(() => remote.refreshToken('r')).thenAnswer((_) async => tokens);
    when(() => storage.saveTokens(any())).thenAnswer((_) async {});

    final result = await repo.refreshToken();

    expect(result, Right<Failure, AuthTokens>(tokens));
    verify(() => storage.saveTokens(tokens)).called(1);
  });

  test('logout clears tokens', () async {
    when(() => storage.clearTokens()).thenAnswer((_) async {});
    await repo.logout();
    verify(() => storage.clearTokens()).called(1);
  });
}
