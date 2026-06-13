import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockLogin extends Mock implements LoginUseCase {}
class _MockRegister extends Mock implements RegisterUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}

final user = User(
    id: 'u1', tenantId: 't1', email: 'a@b.com', displayName: 'A', avatarUrl: '', createdAt: DateTime(2026));

void main() {
  late _MockLogin login;
  late _MockRegister register;
  late _MockProfile profile;
  late _MockLogout logout;

  setUp(() {
    login = _MockLogin();
    register = _MockRegister();
    profile = _MockProfile();
    logout = _MockLogout();
    registerFallbackValue(const LoginParams(email: '', password: ''));
    registerFallbackValue(const RegisterParams(email: '', password: '', displayName: ''));
  });

  blocTest<AuthBloc, AuthState>(
    'LoginRequested success emits [AuthLoading, Authenticated]',
    build: () {
      when(() => login.call(any())).thenAnswer((_) async => Right(user));
      return AuthBloc(login, register, profile, logout);
    },
    act: (bloc) => bloc.add(const LoginRequested(email: 'a@b.com', password: 'pw')),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Authenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'LoginRequested failure emits [AuthLoading, AuthError]',
    build: () {
      when(() => login.call(any())).thenAnswer((_) async => const Left(ServerFailure('bad')));
      return AuthBloc(login, register, profile, logout);
    },
    act: (bloc) => bloc.add(const LoginRequested(email: 'a@b.com', password: 'pw')),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), isA<AuthError>()],
  );

  blocTest<AuthBloc, AuthState>(
    'RegisterRequested success emits Authenticated',
    build: () {
      when(() => register.call(any())).thenAnswer((_) async => Right(user));
      return AuthBloc(login, register, profile, logout);
    },
    act: (bloc) => bloc.add(const RegisterRequested(email: 'a@b.com', password: 'pw', displayName: 'Andy')),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Authenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'LogoutRequested emits Unauthenticated',
    build: () {
      when(() => logout.call()).thenAnswer((_) async {});
      return AuthBloc(login, register, profile, logout);
    },
    act: (bloc) => bloc.add(LogoutRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [Unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'AppStarted with profile success emits Authenticated',
    build: () {
      when(() => profile.call()).thenAnswer((_) async => Right(user));
      return AuthBloc(login, register, profile, logout);
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Authenticated(user)],
  );

  blocTest<AuthBloc, AuthState>(
    'AppStarted with profile failure emits Unauthenticated',
    build: () {
      when(() => profile.call()).thenAnswer((_) async => const Left(ServerFailure('no token')));
      return AuthBloc(login, register, profile, logout);
    },
    act: (bloc) => bloc.add(AppStarted()),
    wait: const Duration(milliseconds: 100),
    expect: () => [AuthLoading(), Unauthenticated()],
  );
}
