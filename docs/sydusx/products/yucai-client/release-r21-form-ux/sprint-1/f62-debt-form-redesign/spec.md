---
feature: f62-debt-form-redesign
status: confirmed
---

# F62 债务表单重做 — spec

> 依据:R21 Decisions + OD 对比页 debt-form-ux(用户 2026-10-15 拍板);About Face Ch.15/NN/g/Zuko 调研。
> 2026-10-15 用户扩展裁定:F62 的表单容器形态(整页/弹窗/sheet)以 [ux-interaction.md](../../../../ux-interaction.md) 规范裁定为准,先规范后实现。

## ADDED Requirements

### Requirement: FR-1 场景卡首问 + 分类推导
- [ ] 新建债务首问 SHALL 为 4 张场景卡(用户语言):`借钱到银行卡`→信用贷款 / `信用卡里的分期`→信用卡分期 / `房贷·车贷`→mortgage/autoLoan(卡内二级选择) / `亲友借款`→family;每卡角标显推导的分类名;另有「更多类型」入口展开完整分类枚举(消费贷/经营贷/现金分期/其他等保底);术语下拉不再作为默认路径;编辑态按存量 subtype 自动反选对应卡片/入口,零迁移。

#### Scenario: 美团网贷路径
- GIVEN 用户点「借钱到银行卡」卡
- THEN 分类自动=信用贷款(角标可见),表单不出现 10 术语下拉;「钱到账哪张卡」选择器仅亮储蓄卡

#### Scenario: 编辑态反选
- GIVEN 打开存量 card_loan 债务编辑
- THEN 「信用卡里的分期」卡呈选中态,挂接字段组按既有语义展开

### Requirement: FR-2 账户选择器灰显过滤(冲突不可能)
- [ ] 账户类选择器(到账卡/挂接卡/放款账户)SHALL 仅亮兼容账户,不兼容项灰显+一句原因(如「信用卡不能作为到账卡」);domain `DebtSubtypeAffinity` 白名单保留为过滤器数据源,`isConflict` 的 UI 警示调用点 SHALL 退役(「分类与关联账户不一致」不再可能出现)。

### Requirement: FR-3 载体户隐形
- [ ] 普通贷款(非信用卡分期)表单 SHALL 不出现「关联账户/载体」字段;保存时自动创建隐藏载体户(isSystem 既有机制),字段区小字说明「系统将自动生成管理账户」;「钱到账到了哪张卡」为资产类到账账户字段(用户语言)。

### Requirement: FR-4 渐进披露三段 + 期供预览
- [ ] 表单 SHALL 分三段:①基本(债权方/本金/期数或月供)+ 期供**实时预览**(粗口径=本金÷期数,附「以保存后生成的期表为准」)②到账与还款(到账卡/起始日;信用卡分期含挂卡/出账方式/首期锚点)③高级默认折叠(利率方式/每期手续费/占用开关/担保人/合同附件,折叠头显「已收起 N 项」)。

### Requirement: FR-5 信用卡分期路径字段组
- [ ] 选「信用卡里的分期」SHALL 展开:挂接卡选择器(仅亮信用卡账户,灰显其余)+出账方式(并入/独立)+占用开关+首期锚点——既有语义逐项保留,归入对应段;e招贷式独立账单路径可达。

## NFR

### Requirement: NFR-1 视觉与可达
- [ ] 全令牌/双主题;场景卡与灰显态可键盘操作;tooltip 覆盖。

### Requirement: NFR-2 回归门
- [ ] flutter test 全绿 + analyze 基线 + make client-e2e;表单既有行为断言(提交链路/守卫/预填)零弱化;金图波及重录。

## Feasibility

technical 可行(表单重构,提交链路/领域层零改动——纯 presentation;F52 预设层兼容);economic 可行(单票 ~4 文件+测试);operational 可行(e2e 表单链路既有)。

## Out of scope

- 账户表单同范式 — owner: F63 — excluded because: 范式先在债务表单沉淀。
- 移动端表单布局重排 — owner: none(维持既有响应式) — excluded because: 桌面为主战场,移动端随 F63 观察议。
- 域层改动(白名单/载体机制) — owner: none — excluded because: 仅 UI 消费方式变化,域零 diff。

## Grill record

- 五项改造方案 — challenged: OD 对比页(debt-form-ux)现状还原 vs 重设计,交互可点验 — defended: 用户「同意」(2026-10-15);依据 About Face Ch.15/NN/g 灰显过滤/渐进披露/智能默认(调研留档 release 附注)。
- 期供预览口径 — challenged: 精算 vs 粗估 — defended(设计定): 粗口径本金÷期数+「以期表为准」附注(预览是反馈不是承诺,精算在保存后)。
- 更多类型保底入口 — challenged: 4 卡是否会困住非主流类型 — defended(设计定): 「更多类型」入口保留完整枚举,编辑态反选覆盖全部存量 subtype。
