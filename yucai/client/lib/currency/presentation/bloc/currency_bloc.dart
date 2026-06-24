import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/currency/domain/repositories/currency_repository.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';

@injectable
class CurrencyBloc extends Bloc<CurrencyEvent, CurrencyState> {
  CurrencyBloc(this._repo, this._authRemote)
      : super(const CurrencyState()) {
    on<LoadCurrenciesRequested>(_onLoadCurrencies);
    on<LoadPreferencesRequested>(_onLoadPreferences);
  }

  final CurrencyRepository _repo;
  final AuthRemoteDataSource _authRemote;

  Future<void> _onLoadCurrencies(
    LoadCurrenciesRequested event,
    Emitter<CurrencyState> emit,
  ) async {
    emit(state.copyWith(status: CurrencyStatus.loading));
    final result = await _repo.list();
    result.fold(
      (failure) => emit(state.copyWith(
        status: CurrencyStatus.error,
        errorMessage: failure.displayMessage,
      )),
      (currencies) {
        final rates = <String, double>{
          for (final c in currencies) c.code: c.exchangeRate,
        };
        emit(state.copyWith(
          status: CurrencyStatus.loaded,
          currencies: currencies,
          rates: rates,
        ));
      },
    );
  }

  Future<void> _onLoadPreferences(
    LoadPreferencesRequested event,
    Emitter<CurrencyState> emit,
  ) async {
    emit(state.copyWith(status: CurrencyStatus.loading));
    try {
      // preferred_currency lives on UserDTO (auth.proto field 7); default to
      // CNY when the server returns an empty/unset value.
      final preferred = await _authRemote.getPreferredCurrency();
      // rate_sync_interval_hours lives on TenantPreferencesDTO (GetPreferences
      // RPC). Falls back to the existing interval on failure so a preference
      // outage never blanks the rate-sync cadence.
      var interval = state.intervalHours;
      try {
        interval = await _authRemote.getRateSyncIntervalHours();
        if (interval <= 0) interval = state.intervalHours;
      } catch (_) {
        // keep previous interval
      }
      emit(state.copyWith(
        status: CurrencyStatus.loaded,
        preferred: preferred.isEmpty ? 'CNY' : preferred,
        intervalHours: interval,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CurrencyStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
