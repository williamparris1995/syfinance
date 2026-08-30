import 'dart:math' as math;

/// TWR 累计/年化 — R5-G twr.go 的 Dart 移植(GIPS):
/// 零端点(含 finalValue)→ null(可判别降级);cumulative<-1 年化防御;
/// days<1 返累计。清仓分段/终止语义由装配层负责(GIPS 三态)。

class SubPeriodReturn {
  const SubPeriodReturn(this.beginValueAfterCF, this.endValueBeforeCF);
  final double beginValueAfterCF;
  final double endValueBeforeCF;
}

double? cumulativeTwr(
  List<SubPeriodReturn> subPeriods,
  double finalValue,
  double lastAfterCF,
) {
  if (subPeriods.isEmpty) return null;
  if (finalValue == 0) return null;
  var product = 1.0;
  for (final sp in subPeriods) {
    if (sp.beginValueAfterCF == 0 || sp.endValueBeforeCF == 0) return null;
    product *= sp.endValueBeforeCF / sp.beginValueAfterCF;
  }
  if (lastAfterCF == 0) return null;
  product *= finalValue / lastAfterCF;
  return product - 1;
}

double? annualizeTwr(double cumulative, int totalDays) {
  if (totalDays < 1) return cumulative;
  if (cumulative < -1) return null;
  final years = totalDays / 365.0;
  return math.pow(1 + cumulative, 1 / years) - 1;
}
