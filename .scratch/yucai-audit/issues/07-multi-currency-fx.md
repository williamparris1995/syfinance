# 07 · 跨币种汇率体系(汇率基数 P0 + 时点 + 缺失降级)

Type: grilling
Status: resolved
Blocked by: —

## Question

**最高优先级 P0**:汇率基数约定错致生产 USD→CNY 错 ~52 倍,unit test 用 mock 掩盖(详见 `findings.md` F1/F8/F9):

- **[F1 P0]** `ConvertToBase(amount, rateFrom, rateBase)=amount×rateFrom/rateBase` 假定 CNY-base(rate[CNY]=1.0,unit test 用此),但 `FrankfurterProvider` 落库 EUR-base(rate[USD]=1.08 意"1EUR=1.08USD"),seed 同 EUR-base。生产 rate[USD]/rate[CNY]=1.08/7.81=0.138,正确≈7.22 → 错 52 倍且方向乘反。影响 networth/holding/budget 全跨币种聚合。
- **[F8 P1]** 预算 actuals 跨币种用月末单点汇率换算全月,波动月偏差。
- **[F9 P1]** 汇率缺失静默回退 1.0,用户看到"€100 当 ¥100"。

**决策点:**
1. 修法:`SyncRates` 落库前重基到 CNY-base(rate[X]="1 X 兑多少 CNY",保持公式)/ 改 ConvertToBase 公式为 `amount×rateBase/rateFrom`(适配 EUR-base)/ 其他?(决策影响所有调用方)
2. 是否补"真实 Frankfurter 响应样本贯穿到 ConvertToBase"的端到端断言测试,堵住 mock 掩盖?
3. 预算 actuals 跨币种换算:改每笔 entry 按交易日汇率 vs 接受月末单点?
4. 汇率缺失:降级 nil(受影响指标隐藏)vs 显式标"汇率缺失未折算"?
5. 是否在 tenant 配置引入显式"本位币"(base currency)概念?

## Answer(resolved 2026-07-26)

grilling 决策(4 点 + 测试):

1. **修法(F1 P0 核心)**:`SyncRates` 落库前把 Frankfurter 的 EUR-base 数据重基到 **CNY-base**(`rate[X] = rate[CNY]_eur / rate[X]_eur` = "1 X 兑多少 CNY",`rate[CNY]=1`)。`ConvertToBase` 公式 `amount×rateFrom/rateBase` **不变**(已正确支持动态 base —— codegraph 确认 networth/holding/budget 都传了 base 的 rate)。修 rate 语义注释。
2. **预算 actuals 时点(F8 P1)**:改**每笔 entry 按各自 transaction_date 汇率**换算(替代月末单点)。需 budget actuals 查询/换算改造。
3. **本位币**:**保持现状**(调用方传 `baseCurrency`,默认 CNY)。**不引入 tenant `base_currency` 字段**(YAGNI;御财中国家庭 base=CNY,多本位币需求出现时再扩)。因 base 默认 CNY,决策 1 的"重基 CNY-base"即正解。
4. **汇率缺失(F9 P1)**:保持 **1.0 回退**(best-effort,显示原币数),但加 **UI 提示**"汇率缺失,未折算到本位币"(server 返回缺失标志 / client 标记)。
5. **测试(无分歧)**:补 **Frankfurter 真实响应样本 → ConvertToBase → 聚合**的端到端断言测试(堵 mock 掩盖,这是 F1 潜伏数月的结构性原因)。

**实施分阶段**:F1 重基 hotfix(P0,最紧急,独立)→ F8 预算每笔交易日 → F9 UI 提示 → 端到端测试。

## Implementation(2026-07-26)

**F1 hotfix 已实施**(commit 本地 main):
- SyncRates 重基 EUR-base→CNY-base(`rate[X]=rate[CNY]/rate[X]`,CNY=1.0)+ CNY 缺失 fallback(Warn + skip)
- ConvertToBase 公式不变 + 注释强化;networth/holding/budget 注释确认 CNY-base 语义
- 端到端测试(Frankfurter 1.08/7.81 → 1000 USD=7231 CNY,pre-fix ~138)+ CNY 缺失 fallback 测
- 16 包测试全绿,networth/holding/budget 多币种 e2e 不破

**Follow-up(留后续)**:
- F8 预算每笔交易日汇率(budget 查询改造)
- F9 汇率缺失 UI 提示
- **FetchExchangeRate 单币 gRPC 路径未重基**(另一处 bug,client 单查汇率会显示 EUR-base 原值)
- **defaultCurrencies seed 值仍 EUR-base**(Frankfurter 不服务的币种 landmine,如 HKD;SyncRates 重基后 seed 不一致)
