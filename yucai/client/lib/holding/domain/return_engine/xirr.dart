import 'dart:math' as math;

import 'brent.dart';

/// XIRR(actual/365)— R5-G xirr.go 的 Dart 移植:
/// 入口归一化(修 F3 大额不收敛)+ 自适应几何 bracket 扩展(包络
/// (-0.999999, 1e16],修 F4 极端短日漏解)+ Brent-only + 噪声模型回代校验。
/// null = 无解/包络外/校验失败(调用方降级,绝不抛)。

class CashFlow {
  const CashFlow(this.date, this.amount);
  final DateTime date;
  final double amount;
}

const double xirrRateFloor = -0.999999;
const double xirrRateCeiling = 1e16;
const int xirrMaxExpand = 60;
const double xirrBrentXTol = 2e-12;
final double _eps = math.pow(2, -52).toDouble();

double? xirr(List<CashFlow> cashflows) {
  if (cashflows.length < 2) return null;
  var hasPos = false, hasNeg = false;
  for (final cf in cashflows) {
    if (cf.amount > 0) hasPos = true;
    if (cf.amount < 0) hasNeg = true;
  }
  if (!hasPos || !hasNeg) return null;

  final sorted = [...cashflows]..sort((a, b) => a.date.compareTo(b.date));
  final t0 = sorted.first.date;
  final years = <double>[];
  var maxAbs = 0.0;
  for (final cf in sorted) {
    years.add(cf.date.difference(t0).inSeconds / (365 * 86400.0));
    final a = cf.amount.abs();
    if (a > maxAbs) maxAbs = a;
  }
  if (maxAbs == 0) return null;
  // 归一化:NPV(r; α·cf)=α·NPV(r; cf),零点不变。
  final amounts = [for (final cf in sorted) cf.amount / maxAbs];

  double npv(double rate) {
    var sum = 0.0;
    for (var i = 0; i < sorted.length; i++) {
      sum += amounts[i] / math.pow(1 + rate, years[i]);
    }
    return sum;
  }

  // 下界:超长年限下 (1+floor)^years 下溢 → NaN;逐级上移 lo(×10 步长,
  // 封顶 -0.99)直至 NPV 有限;全程 NaN → null。
  var lo = xirrRateFloor;
  var nLo = npv(lo);
  while (nLo.isNaN && lo < -0.99) {
    lo = -1 + (lo + 1) * 10;
    if (lo > -0.99) lo = -0.99;
    nLo = npv(lo);
  }
  if (nLo.isNaN) return null;

  // 自适应几何扩展:hi 自 0.1(先跨 1)翻倍直至反号;ceiling 检查在反号前。
  var hi = 0.1;
  var nHi = npv(hi);
  if (!(nLo * nHi <= 0)) {
    var found = false;
    for (var i = 0; i < xirrMaxExpand; i++) {
      hi = hi < 1 ? 1 : hi * 2;
      if (hi > xirrRateCeiling) break;
      nHi = npv(hi);
      if (nLo * nHi <= 0) {
        found = true;
        break;
      }
    }
    if (!found && nLo * nHi > 0) return null;
  }

  final root = brentRoot(npv, lo, hi, nLo, nHi, xirrBrentXTol, 4 * _eps);
  if (root == null) return null;

  // 回代校验(噪声模型预算 = 求值噪声 + Brent 率收敛余量;G review R2)。
  var absSum = 0.0, deriv = 0.0;
  for (var i = 0; i < sorted.length; i++) {
    final term = amounts[i] / math.pow(1 + root, years[i]);
    absSum += term.abs();
    deriv -= years[i] * amounts[i] / math.pow(1 + root, years[i] + 1);
  }
  final budget = 100 * _eps * absSum + 8 * deriv.abs() * xirrBrentXTol;
  final res = npv(root);
  if (res.isNaN || res.abs() > budget) return null;
  return root;
}
