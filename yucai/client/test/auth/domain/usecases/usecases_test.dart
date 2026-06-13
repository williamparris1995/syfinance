import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  final user = User(
      id: 'u1', tenantId: 't1', email: 'a@b.com', displayName: 'A', avatarUrl: '', createdAt: DateTime(2026));

  test('LoginUseCase delegates to repo.login', () async {
    when(() => repo.login('a@b.com', 'pw')).thenAnswer((_) async => Right(user));
    final result = await LoginUseCase(repo).call(const LoginParams(email: 'a@b.com', password: 'pw'));
    expect(result, Right<Failure, User>(user));
  });

  test('RegisterUseCase delegates to repo.register', () async {
    when(() => repo.register('a@b.com', 'pw', 'Andy')).thenAnswer((_) async => Right(user));
    final result = await RegisterUseCase(repo)
        .call(const RegisterParams(email: 'a@b.com', password: 'pw', displayName: 'Andy'));
    expect(result, Right<Failure, User>(user));
  });

  test('RefreshTokenUseCase delegates to repo.refreshToken', () async {
    const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');
    when(() => repo.refreshToken()).thenAnswer((_) async => const Right(tokens));
    final result = await RefreshTokenUseCase(repo).call();
    expect(result, const Right<Failure, AuthTokens>(tokens));
  });

  test('GetProfileUseCase delegates to repo.getProfile', () async {
    when(() => repo.getProfile()).thenAnswer((_) async => Right(user));
    final result = await GetProfileUseCase(repo).call();
    expect(result, Right<Failure, User>(user));
  });

  test('LogoutUseCase delegates to repo.logout', () async {
    when(() => repo.logout()).thenAnswer((_) async {});
    await LogoutUseCase(repo).call();
    verify(() => repo.logout()).called(1);
  });
}
