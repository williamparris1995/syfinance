# Prototype v5 — 信用卡账户(账单周期)

> tier: high-fi(design) · path: **B-fallback 延续**(同 v1-v4,OD/Penpot 不可用;项目 path 已锁定);
> 令牌直连 design-v2 事实源(v5/tokens.css @import,不复制值;ui/ 自包含快照同 v3/v4 惯例)。
> v4(F42 反馈表单)保持为其锁定参考;本版为信用卡账户重构 —— 账单周期需求并入,
> **CURRENT 待用户拍板变体后指 v5**。

## 需求来源(2026-09-23 dev 验收两轮)

| 需求 | 落地(64dfc893 生产码) | 原型呈现 |
|---|---|---|
| 信用卡账户显示上期账单/本期账单/上期已还/上期剩余 | CreditCardStatementPanel(四行,上期剩余强调) | ★面板变体 A/B/C(待拍板) |
| 恒等式 当前欠款=上期剩余+本期账单 | breakdown 不变式测试钉死 | hero 下方 caption 恒等式行 |
| 还款=上期账单口径(24f29e66) | 对话框全额(上期账单)/最低10%/分期 | 还款对话框快照(基数+口径联动) |
| 账单日/还款日编辑预填 | _dayPicker initialValue 回读(64dfc893) | 编辑表单卡两下拉带「5日/23日」 |

## 口径(与生产 CreditCardStatementDue 同源,数字 fixture 同 T7/T8 测试)

```
D=≤今天最近账单日;S=账单日后正向消费和;R=账单日后还款和
上期账单   = current − S + R          ¥3,000.00
上期已还   = R                        ¥1,000.00
上期剩余   = max(0, current − S)      ¥2,000.00(= 还款日应还,强调)
本期账单   = S(未出账)               ¥  500.00
不变式:current == 上期剩余 + 本期账单   ¥2,500.00(hero)
未设账单日:降级全额欠款口径(面板变 muted 提示行,对话框「全额」= ¥2,500)
```

## 复用声明(零新令牌;组件形态全部沿既有)

- **面板卡**:DataCard 范式(surface+border+圆角,同 v3/v4 卡)。
- **四数行**:信息行(border-top 分隔);**强调** = `--q1-bg` 软底 + `--acc` 前景(v3 radio-card
  选中态同款);variant B 数字卡 = surface-2 格(额度 stats 同构)。
- **时间轴(variant C)**:`--bar-track/--bar-fill`(进度条既有)+ `--cyan` 今天标记。
- **还款对话框**:v4 表单形态(.field/.radio-card/.btn-primary);只读金额 = disabled input。
- **降级提示**:surface-2 + muted(callout 信息语义轻量变体,零新组件)。

## 变体与交互(ui/credit-card-account.html)

- **URL 参数 + 浮动条双通道切换**(`?panel=a|b|c&billing=set|unset`):A 四行列表(=当前
  生产形态)/ B 2×2 数字卡 / C 周期时间轴;账单日已设/未设两态全页联动(hero 恒等式、
  周期徽标、还款对话框基数与文案)。
- 双主题切换(右上「主题」,A 墨鎏金/B 晨白)。
- 状态呈现:每步动作后页面数字/口径全量刷新(prototype skill UI 支惯例)。

## 定稿指引

用户在浏览器打开 `ui/credit-card-account.html` 拍板变体(A=零改动已实现;B/C 需后续
UI 票改产线面板)→ CURRENT 指 v5;若拍 B/C,另开 feature 票(布局契约照本版快照),
review 门以定稿变体为 code↔prototype 对照。
