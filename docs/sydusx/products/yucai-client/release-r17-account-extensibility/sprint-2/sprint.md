# Sprint 2 — 预设层 + 期表锚点

> /sydusx-portfolio 2026-10-10 立项(sprint-1 三票收官后)。前置:R17 立项决策「花呗/白条以 creditCard 类别+预设接入,零 schema」+ 账户字段审计(记忆 account-fields-audit)。

## Sprint Goal

常见信用产品一键接入:建户预设模板层让花呗/白条等免手填;期表首期锚点选项闭合平安「当期即扣 vs 顺延一天」的口径分歧窗口,并与预设可组合。

## Features

- [x] **F52 花呗/白条等建户预设模板层** — creditCard 类别预设(预填额度/账单日/还款日/机构名),零 schema 改动;per-product 属性(如「不参与支付推荐」)不加 STI 列,metadata 方向仅在 spec 评估;预设清单与呈现形态 spec 拍板。 ✅ done 2026-10-10 合并 `65f8e81a`(全链:grill 两决策+平权修正/v14 原型 OD×2/评审 pass/2629 绿+e2e 15 套件全绿;两条 Minor 入 ledger)
- [ ] **F57 期表首期锚点选项** — 排期生成器首期锚定可选「起始日当天(平安当期即扣)/ 起始日==账单日顺延(现状假设)」;根因=分歧窗口仅此一天;与 F52 预设可组合(2026-10-10 另会话立票,排 sprint-2)。

## status: pending
