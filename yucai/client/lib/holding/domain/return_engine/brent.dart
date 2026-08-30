import 'dart:math' as math;

/// Brent(1973)求根 — R5-G brent.go 的 Dart 逐函数移植(设计/语义对齐
/// scipy.optimize.brentq;包络内保证收敛)。null=不收敛/未括根。
/// oracle:test/holding/domain/return_engine/(G 用例移植)。

const int brentMaxIter = 100;

double? brentRoot(
  double Function(double) f,
  double lo,
  double hi,
  double fa,
  double fb,
  double xtol,
  double rtol,
) {
  if (fa == 0) return lo;
  if (fb == 0) return hi;
  if (fa * fb > 0) return null;

  var a = lo, b = hi;
  var c = a, fc = fa;
  var d = b - a, e = b - a;

  for (var iter = 0; iter < brentMaxIter; iter++) {
    if (fb * fc > 0) {
      c = a;
      fc = fa;
      d = b - a;
      e = b - a;
    }
    if (fc.abs() < fb.abs()) {
      a = b; b = c; c = a;
      fa = fb; fb = fc; fc = fa;
    }
    final tol1 = 2 * rtol * b.abs() + 0.5 * xtol;
    final xm = 0.5 * (c - b);
    if (xm.abs() <= tol1 || fb == 0) return b;
    if (e.abs() >= tol1 && fa.abs() > fb.abs()) {
      final s = fb / fa;
      double p, q;
      if (a == c) {
        p = 2 * xm * s;
        q = 1 - s;
      } else {
        q = fa / fc;
        final r = fb / fc;
        p = s * (2 * xm * q * (q - r) - (b - a) * (r - 1));
        q = (q - 1) * (r - 1) * (s - 1);
      }
      if (p > 0) q = -q;
      p = p.abs();
      final min1 = 3 * xm * q - (tol1 * q).abs();
      final min2 = (e * q).abs();
      if (2 * p < math.min(min1, min2)) {
        e = d;
        d = p / q;
      } else {
        d = xm;
        e = d;
      }
    } else {
      d = xm;
      e = d;
    }
    a = b;
    fa = fb;
    if (d.abs() > tol1) {
      b += d;
    } else {
      b += _copysign(tol1, xm);
    }
    fb = f(b);
  }
  return null;
}

double _copysign(double v, double ref) => ref.isNegative ? -v.abs() : v.abs();
