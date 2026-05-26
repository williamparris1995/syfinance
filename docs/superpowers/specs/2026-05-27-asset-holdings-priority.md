# 资产持仓系统 — 优先级设计

## 现状

当前 `Investment` 账户只有一个余额数字，没有任何持仓/仓位概念。无法回答"我的腾讯股票赚了多少"这种问题。

## 分层架构

```
accounts (容器层)
  ├── 招商证券 (Investment)
  │   ├── 持仓：腾讯控股 (Stock) × 100股
  │   ├── 持仓：贵州茅台 (Stock) × 50股
  │   └── 持仓：国债2048 (Bond) × ¥10,000
  ├── 蚂蚁基金 (Investment)
  │   ├── 持仓：沪深300ETF (ETF) × 2000份
  │   └── 持仓：黄金ETF (Gold) × 500份
  └── 万科房产 (RealEstate) ← 账户即资产
```

## 优先级划分

### P0: 持仓数据模型（基础）

| 内容 | 说明 |
|------|------|
| `holdings` 表 | 持仓的基础存储 |
| `Holding` domain | 持仓领域模型 |
| 关联到 accounts | 每个持仓属于一个 Investment 账户 |
| CRUD | 增删改查持仓 |

**为什么是 P0**: 这是所有后续功能的地基，没有它后面什么都做不了。

### P1: 股票持仓（最高价值）

| 内容 | 说明 |
|------|------|
| 录入股票持仓 | 代码、数量、成本价 |
| 市价更新 | 手动录入当前价格 |
| 盈亏计算 | 浮动盈亏 = (现价-成本) × 数量 |
| Dashboard 展示 | 股票组合概览卡片 |
| 持仓列表页 | 各股票明细 |

**为什么是 P1**: 股票是个人投资中最常见的资产类别，覆盖 80% 的使用场景。

### P2: ETF/基金 + 债券 + 黄金

| 内容 | 说明 |
|------|------|
| ETF/基金持仓 | 基金代码、份额、净值 |
| 债券持仓 | 票面利率、到期日、持有面值 |
| 黄金持仓 | 克数/盎司、成本、现价 |

**为什么是 P2**: 补充主流资产类型，覆盖更多场景。

### P3: 期权/期货 + 房产 + 其他

| 内容 | 说明 |
|------|------|
| 期权持仓 | 标的、方向、行权价、到期日 |
| 房产物产 | 估值、贷款余额、购买日期 |
| 其他实物资产 | 车辆、艺术品等 |

**为什么是 P3**: 使用频率较低或需要更复杂的计算逻辑。

### P4: 自动化

| 内容 | 说明 |
|------|------|
| 自动获取市价 | API 接入股票/基金/黄金实时价格 |
| 自动更新净值 | 定时刷新持仓市值 |
| 导入券商数据 | CSV 导入、API 对接 |

**为什么是 P4**: 提升体验但非必需，手动录入可先用。

---

## P0 详细设计: 持仓数据模型

### 数据库

```sql
CREATE TABLE holdings (
    id TEXT PRIMARY KEY NOT NULL,
    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    asset_type VARCHAR(20) NOT NULL,  -- stock, fund, bond, gold, option, real_estate, other
    symbol VARCHAR(50),               -- 股票代码/基金代码
    name VARCHAR(100) NOT NULL,       -- 资产名称
    quantity DECIMAL(20,8) NOT NULL,  -- 持有数量
    cost_price DECIMAL(20,4) NOT NULL,-- 成本单价
    current_price DECIMAL(20,4),      -- 当前市价
    currency_code VARCHAR(3) NOT NULL DEFAULT 'CNY',
    extra JSON,                       -- 扩展字段（债券利率、期权行权价等）
    deleted_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_id TEXT,
    synced_at TIMESTAMP,
    CHECK (asset_type IN ('stock', 'fund', 'etf', 'bond', 'gold', 'option', 'real_estate', 'other'))
);
```

### 关键字段说明

- `asset_type`: 资产类别，决定了 `extra` JSON 里存什么
- `symbol`: 交易代码，方便后续接入行情 API
- `cost_price`: 加权平均成本，用于计算盈亏
- `current_price`: 手动维护的市价（P4 版本自动化）
- `extra`: 扩展字段，不同类别存不同数据
  - bond: `{"face_value": 100, "coupon_rate": 0.035, "maturity": "2028-12-31"}`
  - option: `{"strike_price": 28.00, "expiry": "2025-06-30", "direction": "call"}`
  - real_estate: `{"area_sqm": 89.5, "purchase_date": "2020-03-15"}`

### 计算字段（不存 DB，动态计算）

- `market_value = quantity * current_price` — 市值
- `cost_basis = quantity * cost_price` — 成本
- `unrealized_pnl = market_value - cost_basis` — 浮动盈亏
- `pnl_pct = (current_price - cost_price) / cost_price * 100` — 盈亏百分比

---

## 下一步

P0 实现后，Dashboard 就可以按 `asset_type` 分组展示：
- 股票组：表格列 symbol/name/quantity/cost/price/pnl
- 债券组：表格列 name/face_value/rate/maturity
- 黄金组：数量 + 市值曲线
