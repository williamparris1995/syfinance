# Prototype v5 — 信用卡账户(账单周期)

> tier: high-fi(design) · **path: OD 套件底版 fork**(用户裁决 2026-09-23:布局须与其他页面原型
> 一致;本会话无 OD MCP,故 fork design-output-v2/ab/account-detail.html 完整壳,资产
> theme.css/app.js **SSOT 直连**不复制,侧栏/底栏导航互通 OD 套件 12 页)。
> v4(F42 反馈表单)保持为其锁定参考;**CURRENT 待用户拍板变体后指 v5**。

## 底版与同构性

- 页 = `account-detail.html` 同构 fork:侧栏 + 顶栏(面包屑/搜索/主题/通知)+ page-head
  (编辑/还款)+ hero(acct-hero + chip)+ sum-strip 三卡 + detail-grid 1.5fr/1fr 双列 +
  底栏 + foot。页面专属 style 块沿底版同款写法(kv/trend/detail-grid)。
- 主题切换走套件 `app.js`(#themeToggle + localStorage yc2-theme),与套件 12 页行为一致。

## 需求来源(2026-09-23 dev 验收两轮)

| 需求 | 落地(生产码) | 原型呈现 |
|---|---|---|
| 信用卡账户显示上期账单/本期账单/上期已还/上期剩余 | CreditCardStatementPanel(64dfc893) | ★右列「账单周期」卡 A/B/C 变体(浮动条切换) |
| 恒等式 当前欠款=上期剩余+本期账单 | breakdown 不变式测试钉死 | hero 金额下 caption + sum-strip 第二卡 |
| 还款=上期账单口径(24f29e66) | 对话框全额(上期账单)/最低10%/分期 | page-head「还款」唤对话框,口径联动 |
| 账单日/还款日编辑预填 | _dayPicker initialValue 回读(64dfc893) | 账户信息卡注记行 |
| 与催办同数 | DueScheduleEntry 单一来源 | callout「还款日提醒」+ 面板副标 |

## 口径(与生产 CreditCardStatementDue 同源,数字 fixture 同 T7/T8 测试)

```
D=≤今天最近账单日;S=账单日后正向消费和;R=账单日后还款和
上期账单   = current − S + R          ¥3,000.00
上期已还   = R                        ¥1,000.00
上期剩余   = max(0, current − S)      ¥2,000.00(= 还款日应还,强调,三处同数)
本期账单   = S(未出账)               ¥  500.00
不变式:current == 上期剩余 + 本期账单   ¥2,500.00(hero)
未设账单日:降级全额欠款口径 ¥2,500(面板 muted 提示行,对话框「全额」)
```

## 复用声明(零新令牌;组件形态全部沿套件)

- **账单周期卡**:card/card-head/kv 行(底版「账户信息」同款);**强调行** = `--q1-bg` 软底
  + `--acc`(套件 chip/accent 同源)。
- **variant B 数字卡**:surface-2 格 + mini-title/mini-big(sum-strip 同构)。
- **variant C 时间轴**:`--bar-track/--bar-fill`(trend 同源)+ `--cyan` 今天标记。
- **还款对话框**:套件 .card 形态 + radio 行(border→acc 选中,自组装,零新令牌)。
- **降级提示**:surface-2 + muted(callout 信息语义轻量变体)。
- **原型控制条(浮动)**:prototype 专用控件,非套件组件,已注释声明。

## 交互(URL 参数 + 浮动条双通道)

`?panel=a|b|c&billing=set|unset`:面板变体与账单日状态全页联动(hero 恒等式/sum-strip
第二卡/周期徽标/账户信息行/还款对话框基数与文案);主题切换沿套件 app.js。

## 定稿指引

浏览器打开 ui/credit-card-account.html 拍板 A/B/C → CURRENT 指 v5。A=零改动已实现;
B/C 需后续 UI 票(布局契约照本版快照,review 门以此为 code↔prototype 对照)。
