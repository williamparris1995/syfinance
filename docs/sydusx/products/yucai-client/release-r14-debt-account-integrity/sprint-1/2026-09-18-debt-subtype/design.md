# Design: F33 债务 subtype 全链路可编辑 + 9 类扩展

prototype: v3   （UI-scoped：debt_form 的 subtype 选择区 9 类 + `.callout.warn` 复用冲突警示条；产物 `products/yucai-client/prototype/v3/`（design-system.md + tokens.css + ui/subtype-affinity.html 可交互演示），CURRENT→v3，execute/review 以此为 UI 事实源）

## Context

- spec（[./spec.md](./spec.md)）四条 FR 两条 NFR 已经 grill 收敛并经用户确认；分类 9 类与「自动归位+提示」方案 B 为用户拍板。
- 现状断点：`debt_form_page.dart` 编辑模式 chips 只读（`UpdateDebtParams` 不携带 subtype）；proto `UpdateDebtRequest`（`yucai/proto/debt/v1/debt.proto:134`）字段 1-18 已用、无 subtype；server repo 层 `SetSubtype` 已存在于更新路径（`debt_repo.go:300`），缺入参通路；镜像 read 路径已带 `subtype`（`mirror_mappers.dart:108`），update 方向待核。
- 表单事实：subtype 用 `_subtypeKey` 单值状态（默认 `mortgage`）；`_onAccountChanged`（`:229`）是现成账户变更钩子；`_visibleAccounts` 仅在 subtype=credit_card 时过滤信用卡账户，其余**不过滤**——白名单提示有真实作用面。
- 在 `architecture.md`/`tech-stack.md` 内设计（flutter_bloc + injectable + drift 本地 + gRPC 远端 + Go DDD server），无新基建，不重调 architect。

## Goals / Non-Goals

**Goals**：spec FR-1~FR-4、NFR-1~NFR-2 全覆盖；一次 proto regen 同时服务 client+server。
**Non-Goals**（见 spec Scope boundary）：借入↔借出方向编辑、信用卡字段区联动校验、批量重分类、存量数据迁移（用户自助）、F36 记账治本、白名单外**阻断**保存。

## Decisions（ADRs）

- **ADR-1 proto：`UpdateDebtRequest` 追加 `string subtype = 19;`**（下一可用 field 号）。
  *Rationale*：追加字段 = NFR-2 向后兼容（旧端忽略）；与 CreateDebtRequest 的 string 语义一致。
  *Alternatives*：`optional` 包装（无缺席语义需求，拒绝）；独立 ChangeSubtype RPC（一次表单保存拆两请求，拒绝）。
- **ADR-2 兼容白名单收敛为 `DebtSubtypeAffinity` 常量**，与 `DebtSubtypes` 同文件（`lib/debt/domain/value_objects.dart`）单一事实源（NFR-1）。
  *Rationale*：归位默认值、提示判定、未来维护都指向同一张表；review grep 门可验「无第二处硬编码」。
  *Alternatives*：判定逻辑散落表单两处（=两处真相，拒绝）；服务端校验（服务端无账户类别联动语义，且该规则是 UX 引导非数据完整性，拒绝）。
- **ADR-3 自动归位挂 `_onAccountChanged`，`_subtypeTouched` 标志守护**；仅创建模式联动，编辑模式不归位（存量修正走 FR-1 自由编辑）。
  *Rationale*：用户碰过 subtype 即视为表达意图，机器不再覆盖（grill 拍板条件）；编辑模式归位会与「改分类」操作互相踩踏。
  *Alternatives*：无守护直接覆盖（抢用户输入，拒绝）；编辑也联动（与 FR-1 语义打架，拒绝）。
- **ADR-4 提示 = subtype 选择区下方 inline warn 警示条**（design-v2 warn 语义令牌），非阻断、随选择实时出现/消失。
  *Rationale*：表单常驻语义需要常驻可视；阻断 dialog 已被 spec 排除；toast 转瞬即逝不适配「组合错误是持续状态」。
  *Alternatives*：保存时 dialog 拦截（spec Non-Goal）；仅文案后缀小字（视觉分量不足，用户明确要提示）。
- **ADR-5 proto regen = 既有 `make gen-dart` + F13 手工补丁重套 + server 侧 `protoc` go 生成**。
  *Rationale*：AGENTS.md 标注的高风险路径，regen 后第一动作=套补丁+全量构建/单测验证；server ent **零 schema 变更**（subtype 列已存在），仅 handler/params 接线。
  *Alternatives*：手写 pb 文件（不可维护，拒绝）。
- **ADR-6 编辑解禁 = 移除 chips 只读分支 + `UpdateDebtParams` 增 `subtype` 字段全链透传**；update 方向镜像若缺字段则补（execute 时以 mirror update envelope 实际结构为准）。
  *Rationale*：最小改动复用既有 params/repo/DS 管道；subtype 为纯 string 透传，无映射层。
  *Alternatives*：编辑模式禁改、仅提供「删除重建」（丢已还历史，拒绝——行业分层模型里 subtype 是标签层）。

## HLD

单元与依赖方向（沿 DDD 四层，不新增模块）：

1. **proto 契约层**：`debt.proto` UpdateDebtRequest +19 → regen 出 client dart + server go 两份生成物。
2. **server 应用/基础设施层**：`debt_handler.go#UpdateDebt` 将 `req.Subtype` 填入 update DTO（字段已存在）→ repo `SetSubtype` 既有通路生效。
3. **client data 层**：`UpdateDebtParams(+subtype)` → `debt_repository_impl.update` 透传 → `debt_remote_ds.update`（组装 req 字段 19）→ `debt_local_ds.update`（drift 行 subtype 列更新）→ 镜像 update envelope（`mirror_mappers` 按需补字段）。
4. **client domain 层**：`DebtSubtypes` 5→9 类 + 新增 `DebtSubtypeAffinity`（白名单 + 默认值函数）。
5. **client presentation 层**：`debt_form_page`（chips 解禁/归位钩子/警示条）+ `debt_list_widgets`、`debt_detail_page`、`debts_page` chips（labels 迭代自动覆盖，核对无 subtype 硬编码 switch 漏项）。

```
proto(19) ─→ server handler ─→ repo.SetSubtype（已有）
        └─→ client params/repo ─→ remote DS ─→ local DS ─→ mirror
presentation 只依赖 domain 常量（DebtSubtypes + DebtSubtypeAffinity）
```

## LLD

**① `DebtSubtypeAffinity`（design contract）**

```dart
// value_objects.dart，与 DebtSubtypes 同文件
abstract final class DebtSubtypeAffinity {
  /// 账户类别 → 兼容 subtype 集；other 永不提示（判定处特判）。
  static const Map<AccountCategory, Set<String>> compatible = {
    AccountCategory.loan: {mortgage, autoLoan, creditLoan, cashInstallment,
                           consumptionLoan, businessLoan},
    AccountCategory.creditCard: {creditCard},
    AccountCategory.otherLiability: {family},
  };
  /// 创建归位默认值；无兼容值的类别返回 null（不联动）。
  static String? defaultSubtypeFor(AccountCategory category);
  /// 提示判定：other 恒 false；其余查表。
  static bool isConflict(AccountCategory? category, String subtypeKey);
}
```

**② 归位状态机（form 内，pseudocode）**

```
subtypeTouched = false                    // 编辑装载已有值时 = true（不联动）
onSubtypeRadioTap(key): subtypeKey = key; subtypeTouched = true
onAccountChanged(v):
    _accountId = v; _refillCreditCardFields()          // 现状不动
    if (!isEditMode && !subtypeTouched):
        d = DebtSubtypeAffinity.defaultSubtypeFor(account(v).category)
        if (d != null) subtypeKey = d
```

**③ 提示判定与渲染（pseudocode）**

```
conflict = DebtSubtypeAffinity.isConflict(selectedAccount?.category, _subtypeKey)
conflict → subtype 区下方渲染 WarnBanner('该分类与关联账户类别通常不一致…可照常保存')
提交路径零改动（validator 不看 conflict）
```

**④ update 链路字段清单**：`UpdateDebtParams.subtype` → repo.update 透传 → `remote: UpdateDebtRequest(subtype: params.subtype)` → `local: DebtsCompanion(subtype: Value(...))` → mirror update envelope 校验补 `subtype`。

**⑤ 新 4 类 key/label**：`credit_loan` 信用贷款 / `cash_installment` 现金分期 / `consumption_loan` 消费贷 / `business_loan` 经营贷；图标/色候选在 prototype 阶段定稿（Lucide，风格对齐既有 5 类）。

## Risks / Trade-offs

- **proto regen 高风险路径**（F13 sync.pbjson 手工补丁）→ regen 后第一个动作：套补丁 → `flutter test` 全量 + `go build/test`；补丁 checklist 写入 PR 描述。
- **归位 × 信用卡过滤交互**：subtype 切到 credit_card 时 `_visibleAccounts` 突变为仅信用卡账户，已选非信用卡 accountId 失效 → e2e 覆盖「选贷款账户(归位 credit_loan)→手动切 credit_card→账户下拉切换」序列；现状行为保持，不新增语义。
- **白名单随分类/账户类别演进** → NFR-1 单表 + 评审 grep 门（`isConflict\|defaultSubtypeFor` 唯一定义点）。
- **analyze 基线 439** → 新增代码零新增 info；golden：debt 表单不在 golden 集，无像素门影响（e2e full_audit 已含 debt 页巡检，改后重跑）。
- **旧 server / 新 client 交错部署** → ADR-1 追加字段语义保证双向安全；本地 pending 债务在旧 server 上行时 subtype 被忽略、下次全量同步收敛（现状既有语义，非本票新增风险）。

## Migration Plan

无数据迁移。部署顺序任意（NFR-2）；regen 提交与接线提交同一 PR，避免中间态构建失败。

## Open Questions

- 新 4 类的 Lucide 图标与语义色 —— prototype 阶段与用户定稿。
- 警示条文案措辞 —— prototype 阶段定稿（初稿：「该分类与关联账户类别通常不一致，可照常保存」）。
