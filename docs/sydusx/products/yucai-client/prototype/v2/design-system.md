# Prototype v2 — F26 净资产 hero 重设计变体

> tier: high-fi(design) · path: B-fallback(同 v1,OD/Penpot 不可用);令牌直连 design-v2 事实源(v2/tokens.css @import,不复制值)。
> v1(F22 设置页/对话框)保持为其锁定参考;本版为 F26 hero 变体,材料变更→v2,CURRENT 已指 v2(用户拍板后生效)。

## 变体(v2/ui/hero-variants.html,双主题可切)

| 变体 | 暗色 | 亮色 |
|---|---|---|
| **A · design-v2 正统** | surface 墨面卡 + 1.5px 金渐变描边 + **渐变金字** + 金晕 | 白卡 + 柔影 + 黑字 |
| **B · 氛围强化** | A + 大金晕(0.30) + 渐变金 pill(私行感) | 极简白卡(同 A 亮态) |
| **C · 渐变面血统** | 墨系渐变面(bg→surface-2)+ 实金数字(改动最小,保留现气质) | 晨白渐变面 + 黑字 |

design-v2 §4 字面 = A;C 为保留血统的折中;B 为氛围取向。

## 新组件规格

- `hero-networth-v2`(拍板后命名定型):随主题;暗=描边+渐变字(背景裁切文字渐变)/亮=白卡阴影。圆角 24、padding 28/30、数字 42/600/tabular-nums。
- Flutter 映射:渐变描边=Container foregroundDecoration 或 ShaderMask 双层;渐变金字=ShaderMask(grad 文本);金晕=RadialGradient 既有手法保留。

## 输入

design-v2.md §2 令牌/§4 hero 规格;现状 home_page.dart 净资产 hero(F15 豁免注释);用户口味(三选一)。
