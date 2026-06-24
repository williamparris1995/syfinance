package exchangerate

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type FrankfurterProvider struct {
	baseURL string
	client  *http.Client
}

func NewFrankfurterProvider() *FrankfurterProvider {
	return &FrankfurterProvider{baseURL: "https://api.frankfurter.app", client: &http.Client{Timeout: 10 * time.Second}}
}

func (p *FrankfurterProvider) FetchRate(ctx context.Context, code string) (float64, error) {
	rates, err := p.FetchRates(ctx, []string{code})
	if err != nil {
		return 0, err
	}
	r, ok := rates[strings.ToUpper(code)]
	if !ok {
		return 0, fmt.Errorf("rate not available for currency %s", code)
	}
	return r, nil
}

func (p *FrankfurterProvider) FetchRates(ctx context.Context, codes []string) (map[string]float64, error) {
	upper := make([]string, 0, len(codes))
	for _, c := range codes {
		up := strings.ToUpper(strings.TrimSpace(c))
		if up != "" && up != "EUR" {
			upper = append(upper, up)
		}
	}
	url := p.baseURL + "/latest?base=EUR"
	if len(upper) > 0 {
		url += "&symbols=" + strings.Join(upper, ",")
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	resp, err := p.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("frankfurter request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("frankfurter status %d", resp.StatusCode)
	}
	var body struct {
		Base  string             `json:"base"`
		Rates map[string]float64 `json:"rates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return nil, fmt.Errorf("decode frankfurter response: %w", err)
	}
	out := make(map[string]float64, len(body.Rates)+1)
	out["EUR"] = 1.0
	for k, v := range body.Rates {
		out[strings.ToUpper(k)] = v
	}
	return out, nil
}
