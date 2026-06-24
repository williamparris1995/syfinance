import 'package:equatable/equatable.dart';

import 'package:yucai_client/currency/domain/entities/currency_entity.dart';

enum CurrencyStatus { initial, loading, loaded, error }

class CurrencyState extends Equatable {
  const CurrencyState({
    this.currencies = const <Currency>[],
    this.rates = const <String, double>{},
    this.preferred = 'CNY',
    this.intervalHours = 24,
    this.status = CurrencyStatus.initial,
    this.errorMessage = '',
  });

  /// Active currency entities (code + name + symbol + rate) for the settings
  /// dropdown and any UI needing names/symbols. Populated by LoadCurrencies.
  final List<Currency> currencies;

  /// EUR-base exchange rates keyed by ISO 4217 code (e.g. {'USD': 1.08}).
  /// Fed to `toPreferredCents` in currency_convert.dart.
  final Map<String, double> rates;

  /// The user's preferred display currency code (default CNY).
  final String preferred;

  /// Tenant rate-sync interval in hours (default 24).
  final int intervalHours;

  final CurrencyStatus status;
  final String errorMessage;

  CurrencyState copyWith({
    List<Currency>? currencies,
    Map<String, double>? rates,
    String? preferred,
    int? intervalHours,
    CurrencyStatus? status,
    String? errorMessage,
  }) {
    return CurrencyState(
      currencies: currencies ?? this.currencies,
      rates: rates ?? this.rates,
      preferred: preferred ?? this.preferred,
      intervalHours: intervalHours ?? this.intervalHours,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [currencies, rates, preferred, intervalHours, status, errorMessage];
}
