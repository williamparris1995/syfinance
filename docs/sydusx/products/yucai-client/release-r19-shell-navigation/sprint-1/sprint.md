# Sprint 1 — 壳层地基 + 全量扫页

> /sydusx-portfolio 2026-10-12 立项(与 R19 release 同日;单 sprint 两票串行,F59 依赖 F58)。

## Sprint Goal

顶栏面包屑成为唯一导航面包屑(全路径、page 级可点回退),第二层导航条全量退役,页面操作右下角常驻竖排 FAB 悬浮(形态 B)。

## Features

- [x] **F58 壳层导航地基+范式迁移** — AppShell 顶栏面包屑可点化(page 级→列表 root,section 纯标签,当前级加粗)+ detail 当前级标题注入机制(ADR:shell↔detail 标题数据通道)+ 全局竖排 FAB 悬浮簇组件(主 FAB 金圆+次级钮,按页配置;组件归属按 ADR-007 选取次序评估 design_kit)+ 债务/债权/账户详情三页 AppBar 退役作范式 + `_isReceivableDetail` hideTopBar 特例收敛。 ✅ done 2026-10-12 合并 `425399ba`(SDD T1-T6 每任务两轴评审+修复;DetailTitleSync 跨分支回填根治;门:2711 绿[合并树]+analyze 463 基线+e2e 15 套件+需求覆盖 11/11;移交 F59:J-2 范式择一/A12 存量/复用件清单,见 feature.md 移交节)
- [ ] **F59 全量扫页** — 其余 detail/form 页(budget/goal/holding/security/transaction detail 及各 form 页)第二层导航退役迁移 + categories/订阅管理专属 topbar 收敛 + 「‹ 返回」链接退役 + e2e/金图回归钉死。(依赖 F58) `claimed: zcode sess_647913c9 2026-10-13`

## status: pending
