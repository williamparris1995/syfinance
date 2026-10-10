# F49 code-plan — 载体户隐藏(isSystem 激活)

> /sydusx-execute 2026-10-10。消费 spec.md + design.md(8 单元)+ prototype v12。测试基线:worktree `flutter test` 全绿(基线 2496)+ analyze 20 error 全 pbserver。
> 任务粒度 = 一个单元一个 TDD 周期;T1 为地基(其余依赖其 entity 字段)。

## Tasks

- [x] **T1 地基:Account.isSystem + AccountVisibility + 透传**(S1 前半) ✅(评审 PASS,ledger 见 code-ledger.md)
  文件:`account/domain/entities/account_entity.dart`、`account/domain/value_objects.dart`(或新 `account_visibility.dart`)、`account/data/account_local_ds.dart`、`mappers/account_mapper.dart`、`repositories/account_repository.dart`(CreateAccountParams.isSystem 可选参,缺省 false)
  测试:entity copyWith/mapper 往返/visibility 过滤(含 isSystem=true 被滤、false 保留、空列表)

- [ ] **T2 建户置位:并入模式 isSystem=true**(S1 后半,FR-1)
  文件:`debt/presentation/pages/debt_form_page.dart`(建户 CreateAccountParams 传参:并入 true/独立 false)
  测试:widget 测两场景(并入→载体 true;独立→false 且带账单日)

- [ ] **T3 存量 repair:标记 + 孤儿关闭**(S2,FR-2)
  文件:`core/localdb/repairs.dart`(runF49CarrierHideRepair,marker `f49_carrier_hide_v1`,挂 runRepaymentHistoryRepairOnce 链尾)
  测试:`test/core/localdb/f49_carrier_hide_test.dart` 三场景 + 幂等重入

- [ ] **T4 展示过滤 + 净资产钉死**(S3,FR-3)
  文件:`account/presentation/pages/accounts_page.dart`(列表)+ 实查枚举的账户选择器(交易表单/债务表单关联账户/报表·预算筛选等,执行时 grep `watchAccounts|accounts` 全消费点清单化)
  测试:accounts_page widget 测(载体行不见)+ 净资产 hero/负债总额逐位断言不变

- [ ] **T5 卡面分期徽标**(S4 前半,FR-4a)
  文件:`debt/domain/debt_query.dart`(cardInstallmentSummary 纯函数,与 F50 同源)、`accounts_page` 信用卡卡脚注 fchip(照 prototype v12)
  测试:纯函数单测(挂接归集/未结清口径/无分期空态)+ fchip widget 测

- [ ] **T6 卡详情分期区块**(S4 后半,FR-4b)
  文件:`account/presentation/pages/account_detail_page.dart`(既有 collectionAccountId 面板增强:每笔摘要行+查看债务入口,照 v12)
  测试:detail widget 测(每笔行字段+跳转意图)

- [ ] **T7 债删自动关户**(S5,FR-5)
  文件:`debt/data/debt_local_ds.dart`(delete 后置检查)、AccountCloser port + account 侧实现注入
  测试:debt_local_ds 测(归零+isSystem+无他债→关;非零/独立账户不动)

- [ ] **T8 备份 envelope isSystem**(S6 部分,NFR-2)
  文件:`core/localdb/envelope_codec.dart`/`envelope_row_codec.dart`(核验现状,缺则补列)
  测试:备份→恢复往返载体仍隐藏

- [ ] **T9 收口:露出回归 + grep 门 + 全门**(S6)
  文件:grep 门脚本(tool/ 或 test/ 下静态检查)+ FR-6 两露出回归测(卡详情还款计划面板/债务页信用卡账单分组)
  门:全量 `flutter test` 全绿 + analyze 基线 + `make client-e2e`(根 make)

## 依赖与并行

T1 → 其余;T2/T3/T4/T5/T7/T8 两两独立(T5 与 T4 同页但不同区域,串行更稳);T6 依赖 T1;T9 最后。SDD:每 task 派发 + 两轴评审 + fix loop。

## 复杂度裁定

跨模块(account/debt/core/presentation 多模块 + 新 port)→ **full SDD**(fresh implementer per task + per-task review)。
