# Prototype v3 — F33 债务分类 9 类 + 冲突警示条

> tier: high-fi(design) · path: B-fallback(同 v1/v2,OD/Penpot 不可用;design skill 明示 OD 缺席回退 self-design);令牌直连 design-v2 事实源(v3/tokens.css @import,不复制值)。
> v2(F26 hero 变体)保持为其锁定参考;本版为 F33 债务表单 subtype 选择区 + 白名单警示条,CURRENT 已指 v3(用户拍板后生效)。

## 复用声明(零新组件)

- **radio 卡行**:沿用 OD debt-form `.radio` 形态(现状 `_RadioCard`:icon + label,选中态 accent 描边/软底),5 类扩 9 类不加新组件。
- **冲突警示条 = `.callout.warn` 复用**(design-v2 §4「提示卡 callout(pos/warn)」既有变体;theme.css:339):warn 软底 + 图标 + 标题 + 正文 + 「可照常保存」pill。**零新组件、零新令牌**。

## 9 类图标(icon,非色 —— debt 表单 radio 选中态用 accent,列表卡用语义色,无 subtype 专属色,与现状一致)

| key | label | icon(现有) | icon(新增) | 语义 |
|---|---|---|---|---|
| mortgage | 房贷 | `home` | — | 住房 |
| auto_loan | 车贷 | `car` | — | 车辆 |
| credit_card | 信用卡 | `credit-card` | — | 循环信用 |
| family | 亲友借款 | `users` | — | 个人关系 |
| other | 其他 | `help-circle` | — | 兜底 |
| **credit_loan** | **信用贷款** | | **`hand-coins`**(备选 `badge-percent`) | 信用放款 |
| **cash_installment** | **现金分期** | | **`calendar-clock`**(备选 `layers`) | 分期日程 |
| **consumption_loan** | **消费贷** | | **`shopping-bag`** | 消费用途 |
| **business_loan** | **经营贷** | | **`briefcase`** | 经营用途 |

Flutter 映射:`lucide_icons_flutter` 对应 `LucideIcons.handCoins / calendarClock / shoppingBag / briefcase`(以包内实际命名为准,execute 时核对)。

## 状态表(FR-3/FR-4 行为演示,ui/subtype-affinity.html 可交互)

| 状态 | 触发 | 表现 |
|---|---|---|
| 联动归位 | 创建模式,用户**未碰** subtype,切换关联账户 | subtype 自动切到该账户类别兼容值(radio 选中态移动) |
| 已触碰不联动 | 用户手动选过 subtype 后再切账户 | 选中态不动 |
| 冲突提示 | 「账户类别↔subtype」落白名单外 | `.callout.warn` 出现于 radio 行下方:标题「分类与账户通常不一致」/ 正文「这是引导提示,可照常保存」;改回兼容组合即消失 |
| 兼容/other | 白名单内,或 subtype=other | 无提示 |

白名单(与 spec FR-4 一致):loan 账户↔六种银行类;creditCard 账户↔credit_card;otherLiability 账户↔family;other 永不提示。

## 输入

design-v2.md §2 令牌(warn `#FBBF24`/`#D97706`)/§4 callout 组件;grill 拍板方案 B(归位+非阻断提示);现状 debt_form `_RadioCard`/`.radio` 形态;spec FR-3/FR-4。

## Token gate

v3/ui/subtype-affinity.html 全部颜色/圆角/间距引用 theme.css `var(--*)`,无新增硬编码(交互演示 JS 不含视觉值)。
