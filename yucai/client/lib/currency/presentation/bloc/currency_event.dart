import 'package:equatable/equatable.dart';

abstract class CurrencyEvent extends Equatable {
  const CurrencyEvent();
  @override
  List<Object?> get props => [];
}

/// Fetch the active currency list and populate `rates` ({code: exchangeRate}).
class LoadCurrenciesRequested extends CurrencyEvent {
  const LoadCurrenciesRequested();
}

/// Read the user's preferred currency + rate-sync interval from the auth/profile
/// RPCs and populate `preferred` / `interval`.
class LoadPreferencesRequested extends CurrencyEvent {
  const LoadPreferencesRequested();
}
