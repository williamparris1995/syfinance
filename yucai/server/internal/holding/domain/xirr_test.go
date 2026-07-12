package domain

import (
	"math"
	"testing"
	"time"
)

func mustDate(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic(err)
	}
	return t
}

// Excel =XIRR() 文档经典例:投入 -10000,分期收回 → 37.34%。
func TestXIRRMatchesExcel(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2008-01-01"), Amount: -10000},
		{Date: mustDate("2008-03-01"), Amount: 2750},
		{Date: mustDate("2008-10-30"), Amount: 4250},
		{Date: mustDate("2009-02-15"), Amount: 3250},
		{Date: mustDate("2009-04-01"), Amount: 2750},
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Excel XIRR = 0.373362535
	if math.Abs(rate-0.373362535) > 1e-6 {
		t.Errorf("XIRR = %.9f, want 0.373362535", rate)
	}
}

func TestXIRRInsufficientCashFlows(t *testing.T) {
	_, err := XIRR([]CashFlow{{Date: mustDate("2020-01-01"), Amount: -100}})
	if err != ErrInsufficientCashFlows {
		t.Errorf("err = %v, want ErrInsufficientCashFlows", err)
	}
}

// 全同号(无正负交叉)→ NPV 无零点。
func TestXIRRNoSolutionSameSign(t *testing.T) {
	_, err := XIRR([]CashFlow{
		{Date: mustDate("2020-01-01"), Amount: -100},
		{Date: mustDate("2020-06-01"), Amount: -50},
		{Date: mustDate("2021-01-01"), Amount: 0}, // 0 不算正
	})
	if err != ErrNoSolution {
		t.Errorf("err = %v, want ErrNoSolution", err)
	}
}

// 单笔 buy + 当前终值 → 正常收敛。
// 注:用 2021-01-01 → 2022-01-01(365 天,非闰年)使 actual/365 下 years=1.0,
// XIRR 精确 = 0.20。若用 2020-01-01 → 2021-01-01(跨闰年 366 天),Excel 语义
// 下真实 XIRR = 0.199402,与"一年 20%"的测试意图不符。
func TestXIRRSimpleGrowth(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2021-01-01"), Amount: -10000},
		{Date: mustDate("2022-01-01"), Amount: 12000}, // 一年 20%
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(rate-0.20) > 1e-4 {
		t.Errorf("XIRR = %.6f, want ~0.20", rate)
	}
}
