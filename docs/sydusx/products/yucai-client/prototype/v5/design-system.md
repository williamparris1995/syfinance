# Prototype v5 — 信用卡账户(账单周期)

> tier: high-fi(design) · **path: OD 管线重做**(用户指示「使用 od 去设计」,2026-09-23 落地:
> OD 项目 `yucai-cc-bill-cycle-13e8` / run `fe09336c`,agent=claude;壳与 account-detail.html
> 同构,零新令牌)。fork 底版版(529fd9a8)为其 fallback 基线,已被本版**取代**——如需回取走
> git 历史(注意 fork 版 ui/ 页内 SSOT 链接 6 级 `../` 实为坏链,正确为 **7 级**;tokens.css 在
> v5/ 层 6 级才对,两者层级差一级)。
> v4(F42 反馈表单)保持为其锁定参考;**CURRENT 待用户拍板变体后指 v5**。

## 底版与同构性

- 页 = `account-detail.html` 同构:侧栏 + 顶栏(面包屑/搜索/主题/通知)+ page-head(编辑/还款)
  + hero(acct-hero + chip)+ sum-strip 三卡 + detail-grid 1.5fr/1fr 双列 + 底栏 + foot。
  页面专属 style 块沿底版同款写法(kv/trend/detail-grid),**零新令牌**(grep 零 hex 色,
  遮罩用 `color-mix(var(--bg))` 派生)。
- 主题切换走套件 `app.js`(#themeToggle + localStorage yc2-theme);资产 SSOT 直连
  `design-output-v2/ab/assets/`(theme.css/app.js 不复制);侧栏/底栏/面包屑导航互通套件 12 页
  (债务/债权/目标/标签/模板/我的为 `#` 占位,套件无对应页)。

## 需求来源(2026-09-23 dev 验收两轮)

| 需求 | 落地(生产码) | 原型呈现 |
|---|---|---|
| 信用卡账户显示上期账单/本期账单/上期已还/上期剩余 | CreditCardStatementPanel(64dfc893) | ★右列「账单周期」卡 A/B/C 变体(浮动条切换) |
| 恒等式 当前欠款=上期剩余+本期账单 | breakdown 不变式测试钉死 | hero caption + B 构成条 + C 恒等式脚注(三处) |
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

## 三变体(拍板对象;OD 设计,B/C 非 fork 版形态)

- **A 列表**:生产已实现形态照实——kv 四行 + `--q1-bg` 软底强调行(上期剩余 acc 色)+
  推导副标。A=零改动基线,不许过度设计。
- **B 应还拆解**:应答优先——`--q1-bg` 应答块(还款日 23 日 · 应还 ¥2,000.00 大字 + chip
  还有 6 天 + 恢复等式推导),下接「当前欠款构成」比例条(`--bar-fill` 80% / `--seg2` 20%)
  + 双行图例,把 2000+500=2500 恒等式做成一段可视化。
- **C 周期时间轴**:垂直事件轴(`--line` 轴线 + acc 圆点)——9/5 账单日出账 ¥3,000.00 →
  9/6 还款冲减 ¥1,000.00 → 9/8·9/17 本期新增 ¥500.00 → 今天 `--cyan` 标记(距还款日 6 天)
  → 9/23 还款日 `--q1-bg` 应还卡,底部恒等式脚注收束。

## 复用声明(零新令牌;组件形态全部沿套件)

- **还款对话框**:套件 .card 形态 + radio 行(border→acc 选中);Esc 可关。
- **降级提示**:surface-2 + muted +「去设置」小钮。
- **原型控制条(浮动)**:prototype 专用控件,非套件组件,已注释声明(A/B/C 拍板前保留)。

## 交互(URL 参数 + 浮动条双通道)

`?panel=a|b|c&billing=set|unset`:面板变体与账单日状态全页联动(hero 恒等式/sum-strip
第一卡 chip+第二卡金额/账户信息行/还款对话框基数与文案);主题切换沿套件 app.js。
已核验(2026-09-23,浏览器视觉+程序化):A/B/C 三变体渲染、URL 反向初始化、billing 四处
联动+面板降级、对话框三模式金额、Esc 关闭、亮暗切换、CSS 183 规则加载(7 级路径)。

## 定稿指引

浏览器打开 ui/credit-card-account.html 拍板 A/B/C → CURRENT 指 v5。A=零改动已实现;
B/C 需后续 UI 票(布局契约照本版快照,review 门以此为 code↔prototype 对照)。
