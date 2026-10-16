# Release R21 — 表单 UX 治理(form-ux)

> /sydusx-portfolio 2026-10-15 立项。product checkpoint:vision(商业级,UI 交互达行业 4-5 分)ongoing;表单交互治理在路径内。
> 起因:用户实测批评债务表单「分类与关联账户不一致」警示违反 About Face(错误纠正非预防/暴露实现模型/非目标导向);调研(NN/g 灰显过滤/渐进披露/智能默认)+ OD 对比页(debt-form-ux)拍板五项改造。

## Release Goal

表单从「实现模型暴露+事后纠错」转为「用户心理模型+事前预防」:产品先行场景卡推导分类、账户选择器灰显过滤(冲突不可能发生,警示条退役)、载体户隐形、渐进披露分段、期供即时预览;范式随后推广到账户表单。

## Decisions(用户拍板 2026-10-15,OD debt-form-ux)

- 五项改造(场景卡/灰显过滤/载体隐形/渐进披露/期供预览)按对比页区块二落地;依据 About Face Ch.15/NN/g/Zuko(调研留档 release 附注)。
- 白名单(domain DebtSubtypeAffinity)保留为**过滤器数据源**,UI 警示调用点退役。
- 债务表单先行(F62),账户表单同范式随 F63。

## Sprint roster

- [x] [sprint-1](sprint-1/sprint.md) ✅(2026-10-16 两票收官;F62 合并 12a326c6/F63 合并 0c2a71c6) — F62 债务表单重做 / F63 范式推广(串行)

## Done criteria

1. 新建债务流程:场景卡选择 → 分类自动推导,全程零「分类与关联账户不一致」可能;账户选择器仅亮兼容项+灰显原因。
2. 载体户概念从表单消失(自动建隐藏);「钱到账哪张卡」为用户语言字段。
3. 渐进披露三段 + 期供实时预览;编辑态按存量 subtype 反选场景卡,存量数据零迁移零 diff。
4. 全门:flutter test 全绿 + analyze 基线 + make client-e2e;金图波及重录。

## status: done(2026-10-16 功能面收官;发版待用户)
