// Client currency convert helpers (pure functions).
//
// `rates` is relative to EUR base (frankfurter provider). ISO 4217 codes are
// uppercase. Same-currency, missing-rate, and divide-by-zero cases all fall
// back to the original cents value (no conversion) so callers never crash on
// incomplete rate data.

/// EUR is the implicit base currency (rate == 1.0 when not present in `rates`).
const String _eurBase = 'EUR';

/// Converts `cents` from `fromCode` into `preferred`-currency cents using the
/// EUR-base `rates` map. Cross-rate: from→preferred = rates[preferred]/rates[from].
///
/// Returns the original `cents` when:
/// - `fromCode == preferred` (same currency),
/// - `rates[fromCode]` is missing or zero (divide-by-zero),
/// - `rates[preferred]` is missing.
int toPreferredCents(
  int cents,
  String fromCode,
  Map<String, double> rates,
  String preferred,
) {
  if (fromCode == preferred) return cents;

  final double fromRate = fromCode == _eurBase ? 1.0 : (rates[fromCode] ?? 0.0);
  if (fromRate == 0.0) return cents;

  if (preferred == _eurBase) {
    // EUR base: from→EUR = 1/rates[from].
    return (cents / fromRate).round();
  }

  final double? preferredRate = rates[preferred];
  if (preferredRate == null) return cents;

  final double cross = preferredRate / fromRate;
  return (cents * cross).round();
}

/// Returns the display symbol for an ISO 4217 currency code.
///
/// Known: CNY ¥, USD $, EUR €, GBP £, JPY ¥, HKD HK$. Unknown codes return the
/// code itself (e.g. SGD → "SGD").
String currencySymbol(String code) {
  switch (code) {
    case 'CNY':
      return '¥';
    case 'JPY':
      return '¥';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'HKD':
      return 'HK\$';
    default:
      return code;
  }
}
