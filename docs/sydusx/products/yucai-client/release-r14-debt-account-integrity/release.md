# Release R14 — 债务与账户一致性(debt-account-integrity)

> /sydusx-portfolio 2026-09-18 立项。product checkpoint:重读 [vision.md](../vision.md),Product Goal(商业级个人理财客户端、19 模块行业级)ongoing,本线属 debt/account 模块数据一致性打磨。
> 起因:用户实测「账户页贷款分组小计 ≠ 负债页分类总览」——根因 = 两页分组维度不同(账户类别 vs 债务 subtype),数据面存在错位样本(贷款账户挂「房贷」标签债);叠加用户 5 点需求(diagnosis 2026-09-18,含 dev 库实算对数)。

## Release Goal

债务分类体系对齐行业口径(9 类)且创建后可编辑;支出支付方式支持信用卡;贷款账户详情页接入还款计划;负债记账治本使「负债账户余额 = −未还本金」成为不变式——账户页与负债页账目可对账。

## Decisions(用户拍板 2026-09-18)

- **分类集合 9 类**:`mortgage` 房贷 / `auto_loan` 车贷 / `credit_loan` 信用贷款* / `cash_installment` 现金分期* / `consumption_loan` 消费贷* / `business_loan` 经营贷* / `credit_card` 信用卡 / `family` 亲友借款 / `other` 其他(* 新增)。行业调研:银行按担保方式×用途两轴,个人记账 App 通行「分期 vs 循环」+ 用途扁平子类;本表取用途扁平制,后续加种类 = 纯客户端改常量表(subtype 全链纯 string 透传)。
- **F-D 走方案 A(记账治本)**:借入创建即入账、还款全额过账,负债账户余额=−未还本金,含存量数据修复;否决显示治标 B。
- **优先级**:F33 → F34 → F35 → F36。

## Sprint roster

- [x] [sprint-1](sprint-1/sprint.md) — F33/F34/F35/F36 四件 ✅(2026-09-19 收官:F33 `fd3be313`/F34 `c45127bb`/F35 `e9b6d94a`/F36 `d81a3539`;验收热修 F33 ×2)

## Done criteria

1. 用户可在 app 内修改存量债务分类(如把「房贷」改「信用贷款」),9 类在表单/负债页 chips/图标色一致。
2. 支出交易支付方式可选信用卡账户,分录 dr expense / cr credit-card,余额与统计口径正确。
3. 贷款类账户详情页显示名下债务还款计划(一户多笔聚合)。
4. 负债账户余额不变式成立,存量 debt 关联账户余额修复;账户页总负债与负债页「待还本金」恒等。
5. `flutter test` 全绿 + analyze 基线 + `make client-e2e` 门 + `go test ./...` 绿(proto 变更过 server 门)。

## status: done (deploy: released)——**v1.0.6+7 已发布**(2026-09-19:tag `v1.0.6` 推送→Actions release 流水线绿[run 35432382581,~7min]→Release 双资产[yucai-setup-1.0.6.exe 14.8MB+DSA 签名 appcast];稳定订阅地址已供 1.0.6,WinSparkle 自动更新链路生效)

## 验收取证(2026-09-19)

- F36 真库修复:dev 库 5 贷款账户启动管道修复后 balance==+Σ剩余(取证见 progress)。
- 原始对账问题闭环:账户页贷款分组=负债页对应分类(用户改分类后口径一致,¥5,753.26 差异归零)。
