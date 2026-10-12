# F57 design — 期表首期锚点选项

> /sydusx-design 2026-10-12。消费 spec.md(根因修正版);零新基建。
> **prototype: v15**(形态 B 段=常驻选项的视觉/文案基准;形态 A 段作废留档)。

## Decisions(ADR)

- **ADR-1 选项=生成期参数,物化进期表日期**(CreateDebtParams 增可选 `firstPeriodFromDisbursement = false`,仅 local DS 消费;零 drift 列/零 proto)。备选否决:债字段持久化(编辑不重排守卫下无消费方)、按卡记忆(Backlog)。
- **ADR-2 常驻单选,v15 形态 B**(数据反转定案:分歧是每笔起点问题非窗口问题)。副行实例化日期随起始日联动。
- **ADR-3 生成器最小分叉**:`_cardLoanScheduleDates` 增锚点参——次月=现状路径原样;当期=首期取 start 本身,后续照既有逐月推进(nextAfter pinned 契约含月末钳制,不改引擎)。

## HLD/LLD(契约)

| 单元 | 内容 |
|---|---|
| 1 生成器 | `_cardLoanScheduleDates(rule, start, n, {bool currentPeriod = false})`:currentPeriod 且 start 可作首期 → `[start, ...逐月]`;否则现状。`_flatFeeSchedule`/创建链路透传 CreateDebtParams 新参 |
| 2 表单 | debt_form_page 卡贷区(并入模式,`!_cardLoanIndependent`)常驻 `_ODField`「首期锚点」`_ResponsiveRadioRow` 两项(照 spec FR-1 文案 + v15 B 形态,实例化日期副行);提交透传;独立模式不渲染;排期预览联动(既有预览面) |
| 3 测试 | 生成器:当期/次月/月末钳制(1/31 起始)/存量回归零变化;表单:默认次月/选当期透传/独立模式不显示 |

## Risks

月末边界(如 1/31 起始当期→2 月钳制)沿用引擎 pinned 契约,单测钉死;编辑路径不触生成器(守卫既有)。

## Migration

无(存量零影响,回归钉死)。

## Open Questions

无。
