# Spec — F26 净资产 hero 重设计(变体 A 终态)

> 2026-09-15 变体三选一用户拍板:**A design-v2 正统**(prototype v2)。R12 sprint-1;R8 收官 defer 头号项。

## Requirements

- **FR-1 home hero 终态化(变体 A)**:净资产 hero 从 v1 固定深渐变面(#1C1E21→#2A2D33 两主题同款)迁到 design-v2 §4 随主题形态——**暗色**=surface 墨面卡 + 1.5px 金渐变描边(#E8C07A→#C9964A)+ 数字**渐变金**(ShaderMask)+ 金晕保留;**亮色**=surface 白卡 + 柔影(--shadow 口径)+ 数字 fg 黑。pill/label 走既有语义令牌(不变)。
- **FR-2 账户详情 hero 同款迁移**:account_detail hero(同款深渐变豁免面)同步迁变体 A 形态,两处一致。
- **FR-3 豁免退役**:F15 豁免清单「固定深色面」中 home/账户详情两条目标注退役(深渐变面/白系文本豁免声明作废,语义令牌化达成)。
- **NFR-1 theme-follow 探针**:hero 双主题断言(暗色:渐变描边层存在+数字 ShaderMask;亮色:阴影存在;label/pill 语义色)。
- **NFR-2 零回归**:既有 hero 相关测试适配(文本/骨架/错误态不变);全量 `flutter test` + `flutter analyze` 基线一致。

### Scenario(NFR-1)
- GIVEN 暗色主题 WHEN 渲染 hero THEN 存在金渐变描边容器与 ShaderMask 数字层,无固定深色面。
- GIVEN 亮色主题 WHEN 渲染 hero THEN 卡面为 surface + 阴影,数字非渐变。

## Scope boundary(排除项 + 辩护)

| 排除 | 理由 |
|---|---|
| 迷你 hero(38px 次级档)同步 | sprint defer(拍板后另议;当前无豁免问题) |
| B/C 变体 | 用户拍板 A |
| 移动端断点特调 | 沿用现有响应式布局,仅换皮 |

## Grill record

| 决策 | 挑战 | 定案 |
|---|---|---|
| 变体 | A 正统/B 氛围/C 血统(实渲对比) | A(用户拍板;§4 字面,克制耐看) |
| 亮色金晕 | 变体 A 亮色含极淡金晕(prototype 如此) | 随 prototype(事实源);实现后视觉走查可微调 |
| 两处 hero | 只迁 home vs 一并迁账户详情 | 一并(F15 同款豁免,一致性) |

## Feasibility

技术 ✅(渐变描边=双层容器;渐变字=ShaderMask,仓内 spark 渐变先例);经济 ✅(纯 UI 小改);运营 ✅(豁免清单闭环,design-debt 减账)。
