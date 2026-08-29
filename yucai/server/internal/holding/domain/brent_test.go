package domain

import (
	"math"
	"testing"
)

// brent 测试的独立 oracle:闭式根 / 已知数学常数,与求解器零共享。

func brentEps() float64 { return math.Nextafter(1, 2) - 1 }

func TestBrentRootLinearFunctionFindsExactRoot(t *testing.T) {
	f := func(x float64) float64 { return x - 3 }
	root, err := brentRoot(f, 0, 10, f(0), f(10), 2e-12, 4*brentEps())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(root-3) > 1e-10 {
		t.Fatalf("linear root: want 3, got %.15f", root)
	}
}

func TestBrentRootQuadraticFindsPositiveRoot(t *testing.T) {
	f := func(x float64) float64 { return x*x - 4 }
	root, err := brentRoot(f, 0, 10, f(0), f(10), 2e-12, 4*brentEps())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(root-2) > 1e-10 {
		t.Fatalf("quadratic root: want 2, got %.15f", root)
	}
}

func TestBrentRootCosMinusXFindsDottieNumber(t *testing.T) {
	// cos(x)=x 的唯一实根(Dottie number),值取自数学常数,非求解器输出。
	f := func(x float64) float64 { return math.Cos(x) - x }
	root, err := brentRoot(f, 0, 1, f(0), f(1), 2e-12, 4*brentEps())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(root-0.7390851332151607) > 1e-12 {
		t.Fatalf("dottie number: want 0.7390851332151607, got %.15f", root)
	}
}

func TestBrentRootSteepExponentialConverges(t *testing.T) {
	// e^x = 1e6 → x = ln(1e6)(闭式)。陡峭函数考验 bracket 收缩。
	f := func(x float64) float64 { return math.Exp(x) - 1e6 }
	root, err := brentRoot(f, 0, 20, f(0), f(20), 2e-12, 4*brentEps())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := math.Log(1e6)
	if math.Abs(root-want) > 1e-10 {
		t.Fatalf("exp root: want %.15f, got %.15f", want, root)
	}
}

func TestBrentRootEndpointExactlyZeroReturnsEndpoint(t *testing.T) {
	f := func(x float64) float64 { return x }
	root, err := brentRoot(f, 0, 1, f(0), f(1), 2e-12, 4*brentEps())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if root != 0 {
		t.Fatalf("endpoint root: want 0, got %v", root)
	}
}

func TestBrentRootSameSignEndpointsReturnsError(t *testing.T) {
	f := func(x float64) float64 { return x*x + 1 } // 恒正,无反号
	_, err := brentRoot(f, 0, 2, f(0), f(2), 2e-12, 4*brentEps())
	if err == nil {
		t.Fatal("same-sign bracket: want error, got nil")
	}
}
