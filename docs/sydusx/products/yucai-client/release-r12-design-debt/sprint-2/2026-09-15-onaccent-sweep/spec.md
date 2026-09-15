# Spec — F27 onAccent sweep

> 2026-09-15 F15 backlog 票承接;库存实测 75 处 Colors.white/black 于 lib/(令牌定义处除外)。R12 sprint-2。

## Requirements

- **FR-1 库存全量分类迁移**:75 处逐处判定并迁移,判定准则(按序适用):
  1. **accent 面前景**(金渐变按钮/金色徽标/翡翠主按钮上的文字图标)→ `context.yucai.onAccent`;
  2. **quick 四宫格彩底/图表序列色底上的固定白**(q1-q4/seg 系类目身份底)→ 保留(类目身份色豁免,F15 同类目;加注释);
  3. **阴影/暗底/scrim**(黑色投影、深色面)→ 保留(F15 黑/深灰阴影豁免类目;已有注释的不动);
  4. **其余白/黑裸色**(应随主题的普通前景/背景)→ 对应语义(fg/muted/surface/border…),逐处注释判定依据。
- **FR-2 零裸色门**:迁移后 lib/(除 app_design/app_theme 令牌定义与上述豁免类目)grep `Colors.white|Colors.black` 仅剩带「豁免注释」的行;豁免行注释含类目名。
- **FR-3 测试守门**:受影响页的既有色彩断言按语义适配(不削);高频面(按钮/徽标)补 1-2 个 theme-follow 探针(onAccent 随主题断言)。
- **NFR-1 视觉零变化**:除误用修正外,双主题观感不变(裸色→语义后色值等值:暗 onAccent=#1A1408 vs 原 Colors.white 在金底上?**非等值即修正**——白→金底深字是 design-v2 语义本意,逐处走查暗亮两态)。
- **NFR-2 全量门**:flutter test 全量绿 + analyze 不增。

## Scope boundary

| 排除 | 理由 |
|---|---|
| app_design/app_theme 令牌定义处 | 令牌源头 |
| demo/test fixture | 非生产面 |
| 深色面内部白系(debt 深金渐变卡/LIVE 面内) | F15 既有豁免(OD 刻意深底),不属本票 |

## Grill record

| 决策 | 挑战 | 定案 |
|---|---|---|
| 范围 | ~20 票面 vs 实测 75 | 全量(票面数字过期;豁免类目承接 F15 口径) |
| 非等值迁移 | 白→onAccent(#1A1408)暗色下是视觉变化 | 是修正非回归(design-v2 语义;NFR-1 走查) |

## Feasibility

技术 ✅(机械+判定;语义令牌齐备)/经济 ✅/运营 ✅(一次清账,FR-2 门防复发)。
