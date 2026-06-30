package priceprovider

import (
	"context"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"golang.org/x/text/encoding/simplifiedchinese"
)

// SinaProvider fetches A-share prices from Sina Finance (hq.sinajs.cn).
// Covers Exchange == "SSE" (Shanghai, prefix sh) or "SZSE" (Shenzhen, sz).
// All other exchanges return ErrNoSource so the router falls through.
//
// The endpoint returns GBK-encoded text:
//
//	var hq_str_sh600519="贵州茅台",今开,昨收,当前价(2),最高,最低,...
//
// It requires a Referer header or returns 403. Current price is field index 2.
type SinaProvider struct {
	baseURL string
	client  *http.Client
}

// NewSinaProvider builds a SinaProvider pointing at the public endpoint.
func NewSinaProvider() *SinaProvider {
	return &SinaProvider{
		baseURL: "http://hq.sinajs.cn",
		client:  &http.Client{Timeout: 10 * time.Second},
	}
}

// newSinaProviderWithURL is the test seam: point at a httptest server.
func newSinaProviderWithURL(baseURL string) *SinaProvider {
	return &SinaProvider{baseURL: baseURL, client: &http.Client{Timeout: 5 * time.Second}}
}

func (p *SinaProvider) FetchPrice(ctx context.Context, v PriceView) (int64, string, error) {
	listKey, ok := sinaListKey(v.Exchange, v.Symbol)
	if !ok {
		return 0, "", ErrNoSource
	}
	url := p.baseURL + "/list=" + listKey
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, "", fmt.Errorf("sina build request: %w", err)
	}
	// Sina rejects requests without this Referer (HTTP 403).
	req.Header.Set("Referer", "https://finance.sina.com.cn")

	resp, err := p.client.Do(req)
	if err != nil {
		return 0, "", fmt.Errorf("sina request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 0, "", fmt.Errorf("sina status %d", resp.StatusCode)
	}

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, "", fmt.Errorf("sina read body: %w", err)
	}
	// Decode GBK → UTF-8. ASCII bytes map 1:1, so mixed/ASCII payloads survive.
	utf8, err := simplifiedchinese.GBK.NewDecoder().Bytes(raw)
	if err != nil {
		return 0, "", fmt.Errorf("sina gbk decode: %w", err)
	}
	price, err := parseSinaCurrentPrice(string(utf8))
	if err != nil {
		return 0, "", fmt.Errorf("sina parse: %w", err)
	}
	// math.Round avoids float truncation (34.80*100 == 3479.999…). This is
	// the same convention used in holding/domain/entity.go for cents math.
	return int64(math.Round(price * 100)), "sina", nil
}

// sinaListKey maps exchange + symbol to the sinajs list key (sh/sz prefix).
// Returns ok=false for exchanges Sina does not cover.
func sinaListKey(exchange, symbol string) (string, bool) {
	switch strings.ToUpper(strings.TrimSpace(exchange)) {
	case "SSE":
		return "sh" + symbol, true
	case "SZSE":
		return "sz" + symbol, true
	default:
		return "", false
	}
}

// parseSinaCurrentPrice extracts the current price (field index 2) from a
// sinajs response line of the form:
//
//	var hq_str_<key>="<name>",f0,f1,f2,...
//
// The name is enclosed in double quotes; the numeric fields follow the
// closing quote, comma-separated. An empty quote ("") means the symbol does
// not exist → error. Field index: 0=open, 1=prevClose, 2=current.
func parseSinaCurrentPrice(line string) (float64, error) {
	open := strings.Index(line, "\"")
	if open < 0 {
		return 0, fmt.Errorf("no opening quote in response")
	}
	after := line[open+1:]
	close := strings.Index(after, "\"")
	if close < 0 {
		return 0, fmt.Errorf("no closing quote in response")
	}
	name := after[:close]
	tail := after[close+1:] // ",f0,f1,f2,...;"
	if strings.TrimSpace(name) == "" {
		// Empty quote ("") → symbol not found.
		return 0, fmt.Errorf("empty quote, symbol not found")
	}
	// tail starts with ",f0,..."; strip the leading comma to get the fields.
	tail = strings.TrimSpace(tail)
	tail = strings.TrimPrefix(tail, ",")
	if tail == "" {
		return 0, fmt.Errorf("no fields after name")
	}
	fields := strings.Split(tail, ",")
	if len(fields) < 3 {
		return 0, fmt.Errorf("not enough fields: %d", len(fields))
	}
	price, err := strconv.ParseFloat(strings.TrimSpace(fields[2]), 64)
	if err != nil {
		return 0, fmt.Errorf("parse current price %q: %w", fields[2], err)
	}
	return price, nil
}
