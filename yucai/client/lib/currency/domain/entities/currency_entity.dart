import 'package:equatable/equatable.dart';

/// A tradeable currency (ISO 4217 code + display metadata).
///
/// `exchangeRate` is relative to the server's base currency (EUR via the
/// frankfurter provider — see `currency_convert.dart`). `isActive` flags
/// currencies the tenant has enabled for selection.
class Currency extends Equatable {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.exchangeRate,
    required this.isActive,
  });

  final String code;
  final String name;
  final String symbol;
  final double exchangeRate;
  final bool isActive;

  @override
  List<Object?> get props => [code, name, symbol, exchangeRate, isActive];
}
