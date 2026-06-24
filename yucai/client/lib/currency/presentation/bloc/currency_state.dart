import 'package:equatable/equatable.dart';

enum CurrencyStatus { initial, loading, loaded, error }

class CurrencyState extends Equatable {
  const CurrencyState({
    this.rates = const <String, double>{},
    this.preferred = 'CNY',
    this.intervalHours = 24,
    this.status = CurrencyStatus.initial,
    this.errorMessage = '',
  });

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
    Map<String, double>? rates,
    String? preferred,
    int? intervalHours,
    CurrencyStatus? status,
    String? errorMessage,
  }) {
    return CurrencyState(
      rates: rates ?? this.rates,
      preferred: preferred ?? this.preferred,
      intervalHours: intervalHours ?? this.intervalHours,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [rates, preferred, intervalHours, status, errorMessage];
}
