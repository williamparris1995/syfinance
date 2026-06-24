import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/domain/repositories/currency_repository.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';

class _MockRepo extends Mock implements CurrencyRepository {}

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

final _sampleCurrencies = <Currency>[
  const Currency(
      code: 'USD', name: 'US Dollar', symbol: '\$', exchangeRate: 1.08, isActive: true),
  const Currency(
      code: 'CNY', name: 'Chinese Yuan', symbol: '¥', exchangeRate: 7.8, isActive: true),
];

void main() {
  late _MockRepo repo;
  late _MockAuthRemote authRemote;

  setUp(() {
    repo = _MockRepo();
    authRemote = _MockAuthRemote();
  });

  blocTest<CurrencyBloc, CurrencyState>(
    'LoadCurrencies populates rates map {code: exchangeRate}',
    build: () {
      when(() => repo.list())
          .thenAnswer((_) async => Right(_sampleCurrencies));
      return CurrencyBloc(repo, authRemote);
    },
    act: (b) => b.add(const LoadCurrenciesRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const CurrencyState(status: CurrencyStatus.loading),
      const CurrencyState(
        status: CurrencyStatus.loaded,
        rates: {'USD': 1.08, 'CNY': 7.8},
      ),
    ],
  );

  blocTest<CurrencyBloc, CurrencyState>(
    'LoadCurrencies failure emits error',
    build: () {
      when(() => repo.list())
          .thenAnswer((_) async => const Left(ServerFailure('down')));
      return CurrencyBloc(repo, authRemote);
    },
    act: (b) => b.add(const LoadCurrenciesRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const CurrencyState(status: CurrencyStatus.loading),
      const CurrencyState(
          status: CurrencyStatus.error, errorMessage: 'down'),
    ],
  );

  blocTest<CurrencyBloc, CurrencyState>(
    'LoadPreferences sets preferred + interval',
    build: () {
      when(() => authRemote.getPreferredCurrency())
          .thenAnswer((_) async => 'USD');
      when(() => authRemote.getRateSyncIntervalHours())
          .thenAnswer((_) async => 12);
      return CurrencyBloc(repo, authRemote);
    },
    act: (b) => b.add(const LoadPreferencesRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const CurrencyState(status: CurrencyStatus.loading),
      const CurrencyState(
        status: CurrencyStatus.loaded,
        preferred: 'USD',
        intervalHours: 12,
      ),
    ],
  );

  blocTest<CurrencyBloc, CurrencyState>(
    'LoadPreferences empty preferred falls back to CNY',
    build: () {
      when(() => authRemote.getPreferredCurrency())
          .thenAnswer((_) async => '');
      when(() => authRemote.getRateSyncIntervalHours())
          .thenAnswer((_) async => 6);
      return CurrencyBloc(repo, authRemote);
    },
    act: (b) => b.add(const LoadPreferencesRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const CurrencyState(status: CurrencyStatus.loading),
      const CurrencyState(
        status: CurrencyStatus.loaded,
        preferred: 'CNY',
        intervalHours: 6,
      ),
    ],
  );

  blocTest<CurrencyBloc, CurrencyState>(
    'LoadPreferences interval RPC failure keeps previous interval',
    build: () {
      when(() => authRemote.getPreferredCurrency())
          .thenAnswer((_) async => 'EUR');
      when(() => authRemote.getRateSyncIntervalHours())
          .thenThrow(Exception('prefs down'));
      return CurrencyBloc(repo, authRemote);
    },
    act: (b) => b.add(const LoadPreferencesRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const CurrencyState(status: CurrencyStatus.loading),
      const CurrencyState(
        status: CurrencyStatus.loaded,
        preferred: 'EUR',
        intervalHours: 24, // unchanged default
      ),
    ],
  );
}
