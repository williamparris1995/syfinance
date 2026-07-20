import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}

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

  setUp(() {
    oidcLogin = _MockOidcLogin();
    profile = _MockProfile();
    logout = _MockLogout();
  });

  blocTest<AuthBloc, AuthState>(
    'OIDCLoginRequested success emits [AuthLoading, Authenticated]',
    build: () {
      when(() => oidcLogin.call(any()))
          .thenAnswer((_) async => Right(user));
      return AuthBloc(oidcLogin, profile, logout);
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
      return AuthBloc(oidcLogin, profile, logout);
    },
    act: (bloc) => bloc.add(const OIDCLoginRequested('google')),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), isA<AuthError>()],
  );

  blocTest<AuthBloc, AuthState>(
    'LogoutRequested emits Unauthenticated',
    build: () {
      when(() => logout.call()).thenAnswer((_) async {});
      return AuthBloc(oidcLogin, profile, logout);
    },
    act: (bloc) => bloc.add(LogoutRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [Unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'AppStarted with profile success emits Authenticated',
    build: () {
      when(() => profile.call()).thenAnswer((_) async => Right(user));
      return AuthBloc(oidcLogin, profile, logout);
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Authenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'AppStarted with profile failure emits Unauthenticated',
    build: () {
      when(() => profile.call())
          .thenAnswer((_) async => const Left(ServerFailure('no token')));
      return AuthBloc(oidcLogin, profile, logout);
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Unauthenticated()],
  );
}
