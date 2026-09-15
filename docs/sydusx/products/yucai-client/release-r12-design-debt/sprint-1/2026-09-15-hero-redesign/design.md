# Design — F26 净资产 hero 重设计(变体 A)

**prototype: v2**([prototype/v2](../../../../prototype/v2/);hero-variants.html 变体 A,用户拍板;令牌直连 design-v2)

## Context

[spec.md](spec.md)。现状:home_page.dart 净资产 hero + account_detail_page hero 为 v1 固定深渐变面(F15「固定深色面」豁免,白系文本豁免随附)。

## Goals / NonGoals

- **Goals**:两处 hero 迁变体 A 随主题终态;豁免条目退役;探针测试锁形态。
- **NonGoals**:迷你 hero 档、B/C 变体、布局/信息结构变化(只换皮)。

## Decisions(ADR)

### ADR-1 渐变描边 = 双层容器(padding 镂空法)
- 外层 `Container.decoration=LinearGradient(accent→accentDeep)+AppRadius.lgBorder(24)`;内层同圆角、`color=surface`、margin=描边宽 1.5 → 露出渐变边。备选:foregroundDecoration+GradientOutlineBorder(需自绘 painter,过度)。纯 UI 无命中测试敏感。

### ADR-2 渐变金字 = ShaderMask 包数字
- `ShaderMask(blendMode: srcIn, gradient: LinearGradient(acc→accDeep))` 包 RichText(仅暗色;亮色直出 fg)。仓内 spark/hero 金渐变填充先例同手法。

### ADR-3 主题分支 = YucaiTheme.brightness 判定
- `Theme.of(context).brightness` 暗亮分支描边/渐变字 vs 白卡阴影;色值全部 context.yucai 语义令牌(accent/accentDeep/surface/shadow 口径走 AppTheme cardTheme 先例)。

### ADR-4 金晕两主题保留,随 prototype
- 单值 0.18 双主题(prototype .glow 单一定义,亮色无覆盖;评审修正了亮 0.10 的失实出处)。

## HLD

```
auth/presentation/pages/home_page.dart        净资产 hero 变体 A(抽 HeroShell 私有件)
account/presentation/pages/account_detail_page.dart   hero 同款迁移(复用同手法/如结构同则抽共享件)
test/...hero_theme_follow_test.dart           NFR-1 探针(双主题)
```

## LLD

- 卡:padding 32 保持;radius AppRadius.xl=24(此前笔误写 lgBorder);暗=描边 1.5(内层同心 24−1.5);亮=双层柔影(prototype --shadow 双层口径)。
- 数字排版(21 cur + 42 value/600/-0.6 letterSpacing/tabular)不变,仅色随主题。
- 探针断言用 widget 树特征(存在 ShaderMask/描边双容器/Container boxShadow),避免 golden 脆测。

## Risks

| 风险 | 缓解 |
|---|---|
| 双层容器圆角接缝(1.5px 内缩弧) | 内层半径同心内缩(xl−1.5);视觉走查 |
| 账户详情 hero 结构差异(字段多) | 只换容器皮,内容不动 |

## Migration

纯视觉;豁免清单两条目退役标注(home/account_detail 文件头豁免注释改「已退役 F26」)。

## Open Questions

- 描边宽 1.5 vs 1.0——实装看走查(变体页 1.5)。
