package domain

import (
	"errors"
	"math"
)

// brentMaxIter 是 Brent 迭代上限。bracket 内连续函数理论上远早于此收敛,
// 超限视为数值异常(fail-closed 返错,不返回伪根)。
const brentMaxIter = 100

var errBrentNoConvergence = errors.New("brent: max iterations exceeded")

// brentRoot 在 [lo, hi] 内用 Brent(1973)方法求 f 的根。
// 语义对齐 scipy.optimize.brentq:逆二次插值 + secant,bisection 兜底,
// 收敛判据 |x−x₀| ≤ xtol + rtol·|x|(scipy 缺省 xtol=2e-12, rtol=4·eps)。
// 前置:fa=f(lo)、fb=f(hi) 由调用方预传,且 fa·fb ≤ 0(已反号);
// 端点恰为零直接返回端点;同号返错。
func brentRoot(f func(float64) float64, lo, hi, fa, fb, xtol, rtol float64) (float64, error) {
	if fa == 0 {
		return lo, nil
	}
	if fb == 0 {
		return hi, nil
	}
	if fa*fb > 0 {
		return 0, errors.New("brent: root not bracketed")
	}

	a, b := lo, hi
	c, fc := a, fa
	d, e := b-a, b-a // d=上一步位移, e=上上步位移(插值步判断用)

	for iter := 0; iter < brentMaxIter; iter++ {
		if fb*fc > 0 {
			c, fc = a, fa
			d, e = b-a, b-a
		}
		if math.Abs(fc) < math.Abs(fb) {
			a, b, c = b, c, b
			fa, fb, fc = fb, fc, fb
		}
		tol1 := 2*rtol*math.Abs(b) + 0.5*xtol
		xm := 0.5 * (c - b)
		if math.Abs(xm) <= tol1 || fb == 0 {
			return b, nil
		}
		if math.Abs(e) >= tol1 && math.Abs(fa) > math.Abs(fb) {
			s := fb / fa
			var p, q float64
			if a == c {
				// secant
				p = 2 * xm * s
				q = 1 - s
			} else {
				// 逆二次插值
				q = fa / fc
				r := fb / fc
				p = s * (2*xm*q*(q-r) - (b-a)*(r-1))
				q = (q - 1) * (r - 1) * (s - 1)
			}
			if p > 0 {
				q = -q
			}
			p = math.Abs(p)
			min1 := 3*xm*q - math.Abs(tol1*q)
			min2 := math.Abs(e * q)
			if 2*p < math.Min(min1, min2) {
				e = d
				d = p / q
			} else {
				d = xm
				e = d
			}
		} else {
			d = xm
			e = d
		}
		a, fa = b, fb
		if math.Abs(d) > tol1 {
			b += d
		} else {
			b += math.Copysign(tol1, xm)
		}
		fb = f(b)
	}
	return 0, errBrentNoConvergence
}
