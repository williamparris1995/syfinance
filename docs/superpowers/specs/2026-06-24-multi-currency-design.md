# 御财多货币换算统计 · 设计

- **日期**: 2026-06-24
- **状态**: 设计已确认，待转实施计划
- **范围**: 账户列表/详情多货币处理 —— 货币符号按 currencyCode + 总计/小计按汇率换算到用户偏好货币
- **分支**: main（新功能分支 multi-currency）

## 1. 概述

御财支持多货币账户（CNY/USD/EUR/GBP/HKD/JPY 等）。当前问题：
1. **货币符号硬编码 ¥**：`_fmt`（accounts_page L51/L623 + account_detail）都 `'$sign¥...'`，美元账户余额显示 ¥
2. **总计/小计混加多货币**：assetCents/liabCents/subtotal 直接 fold currentBalanceCents，美元 cents + CNY cents 混加显示 ¥（无意义）

本 spec 实现：货币符号按 currencyCode 显示 + 总计/小计按汇率换算到用户偏好货币（默认 CNY，可设置）。

## 2. 决策（已确认）

- **汇率源**：frankfurter.app（免费、无需 API key、ECB 数据、base EUR）
- **偏好货币**：tenant 级（server tenants 表 preferred_currency，默认 CNY，设置页可改）
- **换算时机**：client 换算（server 提供汇率表 + 偏好货币；client fold 时本地换算）
- **汇率存储**：相对 EUR base（frankfurter 原样），cross-rate 换算
- **同步周期**：可配置（设置），默认 **8 小时**
- **Card 余额**：显示原货币（USD 账户 $ 原金额）；**总计/小计**：显示偏好货币（¥ 换算金额）

## 3. 架构

### server

**frankfurter provider**（`internal/currency/adapter/driven/exchangerate/frankfurter.go`）：
- 实现 `Provider` 接口（`FetchRate(ctx, code) (float64, error)`）
- 调 `https://api.frankfurter.app/latest?base=EUR&symbols=<active currencies>`
- 返回 rate[code]（相对 EUR）。EUR=1.0
- 失败返回 error（scheduler fallback）

**scheduler**（复用现有后台任务模式，如 sync/reminders 5min）：
- 启动 fetch 一次 frankfurter → 更新 `currencies.exchange_rate`
- 定时周期 = **min(所有 tenant `rate_sync_interval_hours`)**（单 tenant 即该 tenant 设置；多 tenant 取最频繁者的 interval）。currencies 是全局表，每次 fetch 一次惠及所有 tenant
- 每 tenant 可在设置改自己的 `rate_sync_interval_hours`（默认 8h，范围 1-168h）；scheduler 每 1h 唤醒检查是否到周期

**tenant 偏好货币 + 同步周期**（migration + proto + RPC）：
- migration：`tenants` 加 `preferred_currency VARCHAR DEFAULT 'CNY'` + `rate_sync_interval_hours INT DEFAULT 8`
- proto：`TenantDTO`/profile 加 `preferred_currency` + `rate_sync_interval_hours`；加 `UpdatePreferences` RPC（改偏好货币/同步周期）
- handler/service：UpdatePreferences（tenant 级，校验 currency code 存在 + interval 合法 1-168h）

### client

**CurrencyBloc**（新 bloc 或扩展）：
- 加载 currencies 表（rate map）+ tenant preferred_currency + rate_sync_interval_hours
- initState 触发 LoadCurrencies + LoadPreferences

**换算 helper**（`lib/currency/` 或 account 模块）：
```
/// cross-rate: from → preferred = rates[preferred] / rates[from]
/// rates 相对 EUR base（frankfurter）。
int toPreferredCents(int cents, String fromCode, Map<String,double> rates, String preferred) {
  if (fromCode == preferred) return cents;
  final fromRate = rates[fromCode], toRate = rates[preferred];
  if (fromRate == null || toRate == null || fromRate == 0) return cents; // 缺汇率回退原值
  return (cents * (toRate / fromRate)).round();
}
```

**货币符号 helper**（`_currencySymbol(String code)`）：
- CNY→¥ / USD→$ / EUR→€ / GBP→£ / JPY→¥ / HKD→HK$ / 其他→code

**accounts_page**（总计/小计换算）：
- `_fmt`（L51 Card 余额）：按 `account.currencyCode` 符号 + 原金额（**不换算**）
- 总计/小计（assetCents/liabCents/subtotal fold）：`toPreferredCents(account.balance, account.currencyCode, rates, preferred)` 后 fold；`_sumcard`/`_subtotal` 用 `_currencySymbol(preferred)` + 换算金额
- 汇率缺失的账户：回退原值计入（标注）或 skip

**account_detail_page**：Hero 余额按 account.currencyCode 原符号；stat/饼图（summary 已 scope 货币中性，但若多货币账户交易，summary 同 account.currencyCode，不需换算）

**设置页**：加「偏好货币」dropdown（currencies 列表）+「汇率同步频率」（1h/8h/12h/24h/手动）→ UpdatePreferences RPC

## 4. 数据流

1. server 启动：scheduler fetch frankfurter → `currencies.exchange_rate`（相对 EUR）
2. scheduler 每 `rate_sync_interval_hours`（默认 8h）：再 fetch → 更新
3. client 启动：CurrencyBloc load currencies（rate map）+ preferred_currency + interval
4. 账户列表 fold：`toPreferredCents(account.balance, account.currency, rates, preferred)` → preferred cents → 总计/小计
5. Card 余额：`_currencySymbol(account.currency)` + 原金额
6. 总计/小计：`_currencySymbol(preferred)` + 换算金额

## 5. 汇率存储与换算

- `currencies.exchange_rate` 存**相对 EUR base**（frankfurter 原样）：rate[EUR]=1.0, rate[CNY]=7.8, rate[USD]=1.08
- cross-rate from→to：`rates[to] / rates[from]`
- 例：USD 账户 1000 cents → preferred CNY：1000 × (7.8 / 1.08) = 7222 cents (¥72.22)
- EUR base 固定（frankfurter 免费 base EUR）。偏好货币可任意（CNY/USD/...），cross-rate 处理

## 6. 错误处理

- **frankfurter 失败**（网络/API）：scheduler fallback `currencies` 表现有 rate（不更新）+ `error` log（不阻塞 app）
- **某 currency 无 rate**（新 currency 未 fetch）：`toPreferredCents` 回退原值（该账户原货币计入总计，标注「汇率缺失」或汇总行提示）
- **偏好货币无效**（删 currency）：UpdatePreferences 校验 code 存在；fallback CNY

## 7. 测试

**server（Go）**：
- frankfurter provider：HTTP mock（frankfurter 响应）→ parse rates 正确
- scheduler：fetch → currencies.exchange_rate 更新；失败 fallback
- UpdatePreferences：校验 currency code + interval（1-168h）

**client（Flutter）**：
- `toPreferredCents` unit test：同货币 / cross-rate / 缺汇率回退 / 除零
- `_currencySymbol` unit test：各 code 映射
- widget test：USD+CNY 账户列表总计 = 换算 preferred（mock rates）；Card 余额原符号

## 8. 御财 token（遵循）

货币符号按 ISO，金额 mono+tabular-nums。偏好货币总计正绿/负红（资产/负债）。

## 9. 范围边界

### 本期做
- frankfurter provider + scheduler（可配置 8h）+ tenant preferred_currency/rate_sync_interval
- client 换算 helper + accounts_page 总计/小计换算 + _currencySymbol + Card 原货币符号
- 设置页偏好货币 + 同步频率 UI
- account_detail Hero 余额原货币符号（stat/饼图不涉及跨货币）

### 本期不做
- 历史汇率（交易按发生日汇率换算）—— 用当前汇率（简化）
- 交易明细多货币换算（交易列表/详情按原货币）
- 汇率趋势图

## 10. 原型参考

无 OD 原型（多货币是数据逻辑，非视觉）。货币符号 + 总计沿用现有 accounts_page/_sumcard 视觉，仅改数据（换算）+ 符号（按 currency）。
