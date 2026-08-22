// AuthBloc tests — table-driven over the transition table in design.md.
// R6 feature B: AppStarted forks on stored credentials + failure type
// (Guest / OfflineAuthenticated / Unauthenticated), skip-login and logout
// land in Guest (binding is a free choice, spec FR-3/FR-4).
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}
class _MockHasCredentials extends Mock implements HasStoredCredentialsUseCase {}

final user = User(
    id: 'u1',
    tenantId: 't1',
    email: 'a@b.com',
    displayName: 'A',
    avatarUrl: '',
    createdAt: DateTime(2026));

void main() {
  late _MockOidcLogin oidcLogin;
  late _MockProfile profile;
  late _MockLogout logout;
  late _MockHasCredentials hasCreds;

  setUp(() {
    oidcLogin = _MockOidcLogin();
    profile = _MockProfile();
    logout = _MockLogout();
    hasCreds = _MockHasCredentials();
    // Most AppStarted cases assume credentials exist; the guest test overrides.
    when(() => hasCreds.call()).thenAnswer((_) async => true);
  });

  AuthBloc build() => AuthBloc(oidcLogin, profile, logout, hasCreds);

  blocTest<AuthBloc, AuthState>(
    'AppStarted without credentials emits Guest (no profile RPC)',
    build: () {
      when(() => hasCreds.call()).thenAnswer((_) async => false);
      return build();
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Guest()],
    verify: (_) => verifyNever(() => profile.call()),
  );

  blocTest<AuthBloc, AuthState>(
    'AppStarted with credentials + profile success emits Authenticated',
    build: () {
      when(() => profile.call()).thenAnswer((_) async => Right(user));
      return build();
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Authenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'AppStarted with credentials + NetworkFailure keeps the offline session',
    build: () {
      when(() => profile.call())
          .thenAnswer((_) async => const Left(NetworkFailure('offline')));
      return build();
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), OfflineAuthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'AppStarted with credentials + AuthFailure emits Unauthenticated',
    build: () {
      when(() => profile.call())
          .thenAnswer((_) async => const Left(AuthFailure('expired')));
      return build();
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'OIDCLoginRequested success emits [AuthLoading, Authenticated]',
    build: () {
      when(() => oidcLogin.call(any()))
          .thenAnswer((_) async => Right(user));
      return build();
    },
    act: (bloc) => bloc.add(const OIDCLoginRequested('google')),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Authenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'OIDCLoginRequested failure emits [AuthLoading, AuthError]',
    build: () {
      when(() => oidcLogin.call(any()))
          .thenAnswer((_) async => const Left(ServerFailure('bad')));
      return build();
    },
    act: (bloc) => bloc.add(const OIDCLoginRequested('google')),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), isA<AuthError>()],
  );

  blocTest<AuthBloc, AuthState>(
    'SkipLoginRequested emits Guest',
    build: build,
    act: (bloc) => bloc.add(SkipLoginRequested()),
    expect: () => [Guest()],
  );

  blocTest<AuthBloc, AuthState>(
    'LogoutRequested emits Guest (not the login wall)',
    build: () {
      when(() => logout.call()).thenAnswer((_) async {});
      return build();
    },
    act: (bloc) => bloc.add(LogoutRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [Guest()],
  );

  blocTest<AuthBloc, AuthState>(
    'TokenRefreshFailed emits Guest',
    build: () {
      when(() => logout.call()).thenAnswer((_) async {});
      return build();
    },
    act: (bloc) => bloc.add(TokenRefreshFailed()),
    wait: const Duration(milliseconds: 100),
    expect: () => [Guest()],
  );
}
