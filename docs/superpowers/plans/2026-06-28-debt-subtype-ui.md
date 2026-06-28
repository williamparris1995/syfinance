# 债务子类型驱动 UI(debt subtype UI)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Checkbox (`- [ ]`) syntax.

**Goal:** debt_form 子类型持久化(subtype field)+ 信用卡子类型驱动字段(联动 credit_card account);receivable_form 子类型持久化。

**Architecture:** server 加 subtype(proto/ent/domain/service,对称 debt_type);client domain/data/bloc 贯通 subtype + const 常量类(DebtSubtypes/ReceivableSubtypes);debt_form 选信用卡子类型 → 信用卡字段区(联动 account,提交 updateAccount);详情页信用卡区 + 列表 badge 用持久化 subtype。

**Tech Stack:** Go(ent + gRPC + proto) + Flutter(flutter_bloc + injectable + grpc-dart + 御财 token)。

## Global Constraints

- **subtype 英文语义 key(const),禁硬编码字符串,禁裸字符串判断**:Dart `DebtSubtypes`/`ReceivableSubtypes` const 类(keys + labels map);Go const 对称。判断用 `subtype == DebtSubtypes.creditCard`。
- **信用卡字段留 account(已有)**:`credit_billing_day`/`credit_repayment_day`/`credit_limit_cents`/`credit_annual_fee_cents`。**不在 debt_details 重复**。debt_form 选信用卡 + 关联 credit_card account → 编辑该 account 字段(提交 `AccountRepository.updateAccount`)。
- **对称 debt_type 贯通**:proto/ent/domain/service/handler + client domain/mapper/remote_ds/repo_impl/bloc(参考债权模块 Task 1-6 模式)。
- **const 值**:DebtSubtypes `mortgage`/`auto_loan`/`credit_card`/`family`/`other`;ReceivableSubtypes `personal`/`business`/`family`/`other`。
- **分支**:`debt-subtype-ui`,BASE `97c3b21`(spec)。
- **参考**:debt module(`lib/debt/`)+ 债权模块(receivables,刚 merge main)。
- **regen**:`make` 未装,用 `buf generate --template proto/buf.gen.go.yaml` + `bash gen-dart.sh`(根 Makefile);ent `cd yucai/server && go generate ./internal/debt/ent/...`(scoped,根 `internal/ent/` 空包会失败)。
- **i18n**:御财 client 中文 const(labels map),不 i18next(御财 client 非 Tauri 主项目)。

---

### Task 1: server proto subtype + dart stub regen

**Files:**
- Modify: `yucai/proto/debt/v1/debt.proto`(DebtDTO + CreateDebtRequest 加 subtype)
- Regen: Go stub(`buf generate`)+ dart stub(`gen-dart.sh`)

**Interfaces:**
- Produces: proto `DebtDTO.subtype` + `CreateDebtRequest.subtype` → Task 2 ent + Task 3 service + Task 5 mapper 用

- [ ] **Step 1: 加 proto subtype field**

在 `debt.proto` DebtDTO(在 `debt_type = 13;` 后)加 `string subtype = 14;`。CreateDebtRequest(在 `debt_type = 8;` 后)加 `string subtype = 9;`。

- [ ] **Step 2: regen Go + dart stub**

```bash
cd yucai && buf generate --template proto/buf.gen.go.yaml   # Go stub
cd yucai && bash proto/gen-dart.sh                           # dart stub
```

- [ ] **Step 3: 验证 + commit**

确认 Go stub(`yucai/server/internal/proto/debt/v1/debt.pb.go`)含 `Subtype` field;dart stub(`yucai/client/lib/proto/debt/v1/debt.pb.dart`)含 `subtype`。

```bash
git add yucai/proto/debt/v1/debt.proto yucai/server/internal/proto/debt/v1/debt.pb.go yucai/client/lib/proto/debt/v1/
git commit -m "feat(debt-proto): DebtDTO/CreateDebtRequest subtype field"
```

---

### Task 2: server ent subtype column + migrate

**Files:**
- Modify: `yucai/server/internal/debt/ent/schema/debt_details.go`(加 subtype field)

**Interfaces:**
- Consumes: Task 1 proto subtype
- Produces: ent `debt_details.subtype` column → Task 3 domain/ent↔domain

- [ ] **Step 1: 加 ent field**

`debt_details.go` Fields()(在 `debt_type` field 后)加:
```go
field.String("subtype").
    Default("").
    Comment("debt subtype key: mortgage/auto_loan/credit_card/family/other (borrowedIn); personal/business/family/other (borrowedOut)"),
```

- [ ] **Step 2: regen ent**

```bash
cd yucai/server && go generate ./internal/debt/ent/...
```

- [ ] **Step 3: 验证 + commit**

确认生成 entity 含 `Subtype` field(default "")。`go test ./internal/debt/...`。无 SQL 文件(ent auto-migrate)。

```bash
git add yucai/server/internal/debt/ent/
git commit -m "feat(debt-ent): subtype column + migrate(default empty)"
```

---

### Task 3: server domain/service/handler subtype + Go const

**Files:**
- Modify: `yucai/server/internal/debt/domain/entity.go`(DebtDetails 加 Subtype)
- Modify: `yucai/server/internal/debt/domain/valueobject.go`(加 Go const)
- Modify: `yucai/server/internal/debt/application/{service.go,dto.go}`(CreateDebt 传 subtype)
- Modify: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go`(DTO↔domain subtype)
- Modify: ent↔domain 转换处(repo,加 subtype 双向)

**Interfaces:**
- Consumes: Task 1 proto + Task 2 ent subtype
- Produces: server subtype 端到端(CreateDebt 持久化 + ListDebts 返回 subtype)

- [ ] **Step 1: Go const + domain field**

`valueobject.go` 加(集中声明,不硬编码):
```go
// Debt subtype keys(borrowedIn)。判断用这些 const,禁裸字符串。
const (
	DebtSubtypeMortgage   = "mortgage"
	DebtSubtypeAutoLoan   = "auto_loan"
	DebtSubtypeCreditCard = "credit_card"
	DebtSubtypeFamily     = "family"
	DebtSubtypeOther      = "other"
)
// Receivable subtype keys(borrowedOut)。
const (
	ReceivableSubtypePersonal = "personal"
	ReceivableSubtypeBusiness = "business"
)
```
`entity.go` DebtDetails 加 `Subtype string` field + 构造。

- [ ] **Step 2: service/dto + handler + ent↔domain**

`dto.go` CreateDebtRequest 加 Subtype。`service.go` CreateDebt 传 subtype。`debt_handler.go`:CreateDebt 读 `req.Subtype`;debtToProto 写 `DebtDTO.Subtype`。ent↔domain 转换(repo Save/toDomain)双向 subtype(string 直传,无 enum 映射)。

- [ ] **Step 3: test + commit**

加测试:CreateDebt 持久化 subtype;ListDebts 返回 subtype。

```bash
cd yucai/server && go test ./internal/debt/...
git add yucai/server/internal/debt/
git commit -m "feat(debt-server): subtype domain/service/handler + Go const"
```

---

### Task 4: client const 常量类 + domain Debt.subtype

**Files:**
- Modify: `yucai/client/lib/debt/domain/value_objects.dart`(加 DebtSubtypes + ReceivableSubtypes)
- Modify: `yucai/client/lib/debt/domain/entities/debt_entity.dart`(Debt 加 subtype)
- Test: `yucai/client/test/debt/domain/debt_entity_test.dart`

**Interfaces:**
- Produces: `DebtSubtypes`/`ReceivableSubtypes` const + `Debt.subtype` → Task 5-9 用

- [ ] **Step 1: 加 const 常量类**

`value_objects.dart` 加(英文 key + 中文 labels,禁硬编码判断):
```dart
/// borrowedIn 子类型 const(英文 key + 中文 label)。判断用 const,禁裸字符串。
abstract final class DebtSubtypes {
  static const mortgage = 'mortgage';
  static const autoLoan = 'auto_loan';
  static const creditCard = 'credit_card';
  static const family = 'family';
  static const other = 'other';
  static const all = [mortgage, autoLoan, creditCard, family, other];
  static const labels = {
    mortgage: '房贷', autoLoan: '车贷', creditCard: '信用卡',
    family: '亲友借款', other: '其他',
  };
}

/// borrowedOut 子类型 const。
abstract final class ReceivableSubtypes {
  static const personal = 'personal';
  static const business = 'business';
  static const family = 'family';
  static const other = 'other';
  static const all = [personal, business, family, other];
  static const labels = {
    personal: '私人', business: '商业', family: '亲友', other: '其他',
  };
}
```

- [ ] **Step 2: Debt.subtype field**

`debt_entity.dart` Debt 加 `final String subtype;`,构造 `this.subtype = ''`(default 空,现有调用点不破坏)。

- [ ] **Step 3: test + commit**

test:Debt 默认 subtype='';可构造 subtype=DebtSubtypes.creditCard。

```bash
cd yucai/client && flutter test test/debt/domain/debt_entity_test.dart
git add yucai/client/lib/debt/domain/ yucai/client/test/debt/domain/debt_entity_test.dart
git commit -m "feat(debt-domain): DebtSubtypes/ReceivableSubtypes const + Debt.subtype"
```

---

### Task 5: client mapper + remote_ds subtype

**Files:**
- Modify: `yucai/client/lib/debt/data/mappers/debt_mapper.dart`(subtype proto↔domain)
- Modify: `yucai/client/lib/debt/data/debt_remote_ds.dart`(create 传 subtype)
- Test: `yucai/client/test/debt/data/debt_mapper_test.dart`

**Interfaces:**
- Consumes: Task 4 Debt.subtype + proto subtype(Task 1)
- Produces: mapper subtype 双向 + remote_ds create 传 subtype

- [ ] **Step 1: mapper subtype**

`debt_mapper.dart` toDomain 加 `subtype: dto.subtype`;toCreateRequest 加 `subtype: debt.subtype`(string 直传,无映射)。

- [ ] **Step 2: remote_ds create**

`debt_remote_ds.dart` create 加 `String subtype` param → `CreateDebtRequest.subtype`。

- [ ] **Step 3: test + commit**

test mapper subtype 双向。

```bash
cd yucai/client && flutter test test/debt/data/debt_mapper_test.dart
git commit -m "feat(debt-data): mapper/remote_ds subtype"
```

---

### Task 6: client repo_impl + bloc subtype

**Files:**
- Modify: `yucai/client/lib/debt/data/debt_repository_impl.dart`(create 透传 subtype)
- Modify: `yucai/client/lib/debt/presentation/bloc/debt_event.dart`(CreateDebtParams 加 subtype)
- Test: `yucai/client/test/debt/presentation/bloc/debt_bloc_test.dart`

**Interfaces:**
- Consumes: Task 5 remote_ds create subtype
- Produces: client subtype 端到端(create 传 subtype)

- [ ] **Step 1: repo_impl + CreateDebtParams**

`debt_repository_impl.dart` create 加 subtype 透传。`debt_event.dart` CreateDebtParams 加 `final String subtype`(default '')。

- [ ] **Step 2: test + commit**

test CreateDebtParams.subtype 透传。

```bash
cd yucai/client && flutter test test/debt/presentation/bloc/debt_bloc_test.dart
git commit -m "feat(debt-bloc): CreateDebtParams subtype"
```

---

### Task 7: debt_form 子类型驱动 + 信用卡区(account 联动)

**Files:**
- Modify: `yucai/client/lib/debt/presentation/pages/debt_form_page.dart`(子类型选项 const + 信用卡驱动区 + updateAccount)
- Test: `yucai/client/test/debt/presentation/pages/debt_form_page_test.dart`

**Interfaces:**
- Consumes: Task 4 DebtSubtypes const + Task 6 CreateDebtParams.subtype + AccountRepository(getIt)

- [ ] **Step 1: 子类型选项用 const**

`debt_form_page.dart` 删 `static const _debtTypes = ['房贷','车贷','信用卡','亲友借款','其他']`(硬编码)。改用 `DebtSubtypes.all` + `DebtSubtypes.labels`。`_debtType` String 改存 **key**(`DebtSubtypes.mortgage` 等,非中文),UI 显示 `DebtSubtypes.labels[key]`。

- [ ] **Step 2: 信用卡驱动区**

`subtype == DebtSubtypes.creditCard`(const 判断)→ 显示「💳 信用卡信息」区(account 联动):
- account 选择聚焦 credit_card category(filter `AccountCategory.creditCard`,只列信用卡账户;无则提示「请先在账户管理创建信用卡账户」+ 跳转 `/accounts/new`)
- 信用卡字段(账单日/还款日/额度/年费)= 选中 credit_card account 的字段,TextEditingController 预填 + 可编辑

- [ ] **Step 3: 提交 updateAccount + CreateDebt(subtype)**

提交时:CreateDebtParams 加 `subtype: _subtypeKey`;若 subtype==creditCard 且信用卡字段有变 → `getIt<AccountRepository>().updateAccount(UpdateAccountParams(... creditBillingDay/repaymentDay/limitCents/annualFeeCents ...))`。

- [ ] **Step 4: test + commit**

test:选 creditCard 子类型 → 信用卡字段区出现(非信用卡不出现);提交 create subtype + updateAccount。

```bash
cd yucai/client && flutter test test/debt/presentation/pages/debt_form_page_test.dart
git commit -m "feat(debt-form): 子类型驱动 + 信用卡区(account 联动 updateAccount)"
```

---

### Task 8: receivable_form subtype 持久化

**Files:**
- Modify: `yucai/client/lib/debt/presentation/pages/receivable_form_page.dart`(子类型选项 const + 提交 subtype)
- Test: `yucai/client/test/debt/presentation/pages/receivable_form_page_test.dart`

**Interfaces:**
- Consumes: Task 4 ReceivableSubtypes + Task 6 CreateDebtParams.subtype

- [ ] **Step 1: 子类型选项 const + 提交**

`receivable_form_page.dart` receivableType 改用 `ReceivableSubtypes.all` + labels;`_receivableType` 存 key;CreateDebtParams 加 `subtype: _subtypeKey`。**不驱动字段**(债权无信用卡)。

- [ ] **Step 2: test + commit**

test:receivable form 提交 subtype;子类型选项 = ReceivableSubtypes.all。

```bash
cd yucai/client && flutter test test/debt/presentation/pages/receivable_form_page_test.dart
git commit -m "feat(receivable-form): subtype 持久化(ReceivableSubtypes const)"
```

---

### Task 9: 详情页信用卡区 + 列表 badge

**Files:**
- Modify: `yucai/client/lib/debt/presentation/pages/debt_detail_page.dart`(信用卡 StatRow + 利用率)
- Modify: `yucai/client/lib/debt/presentation/pages/debts_page.dart`(badge 用持久化 subtype)
- Modify: `yucai/client/lib/debt/presentation/pages/receivables_page.dart`(badge 用持久化 subtype)
- Test: 三个 page test

**Interfaces:**
- Consumes: Task 4 const labels + Debt.subtype + account credit 字段

- [ ] **Step 1: detail 信用卡区**

`debt_detail_page.dart`:`debt.subtype == DebtSubtypes.creditCard`(const)→ StatRow 加「信用卡」卡片(账单日/还款日/额度/利用率 from account;利用率 = currentBalance/creditLimit,颜色 绿<30%/黄<70%/红≥70%)。

- [ ] **Step 2: 列表 badge 用持久化 subtype**

`debts_page.dart` + `receivables_page.dart` 卡 badge 改用 `DebtSubtypes.labels[debt.subtype]`/`ReceivableSubtypes.labels[debt.subtype]`(替代 `_inferBadge` 推断)。subtype 空 → fallback 现有推断或不显示。

- [ ] **Step 3: test + commit**

test:detail 信用卡债务显示信用卡卡(非信用卡不显示);badge 用 labels。

```bash
cd yucai/client && flutter test test/debt/presentation/pages/
git commit -m "feat(debt-ui): 详情信用卡区 + 列表 badge 持久化 subtype"
```

---

### Task 10: 全量验证 + 收尾

**Files:**
- 全 debt module + app

- [ ] **Step 1: 全量验证**

```bash
cd yucai/server && go test ./internal/debt/...     # server
cd yucai/client && flutter test test/debt/ test/app/   # client debt + app
cd yucai/client && flutter analyze lib/debt/ lib/app/  # 0 errors
```

- [ ] **Step 2: GUI 验证(可选)**

```bash
cd yucai/server && go build -o bin/server ./cmd/server   # rebuild server
# 启动 server(podman DB + env vars,见 memory yucai-dev-env)
cd yucai/client && flutter build windows --debug          # debug 绕过 release accessibility
```
GUI:登录 → 创建信用卡债务(debt_form 选「信用卡」→ 填账单日/额度 → 提交)→ 详情页看信用卡卡 + 利用率。

- [ ] **Step 3: commit 收尾**

```bash
git commit --allow-empty -m "chore(debt-subtype-ui): 全量验证通过"
```

---

## Self-Review

**1. Spec coverage**:
- §3 数据模型(debt_details.subtype + const + account 已有 + 贯通)→ Task 1-6 ✓
- §4 form(debt_form 信用卡驱动 + receivable_form 持久化)→ Task 7-8 ✓
- §5 详情/列表/测试 → Task 9-10 ✓
- const 约束(英文 key,禁硬编码判断)→ Task 4 const 类 + Task 7-9 用 const 判断 ✓

**2. Placeholder scan**:无 TBD/TODO。每 task 有 code/命令。Task 7 信用卡区实现细节(field 联动 account)描述清晰(updateAccount params 列出)。

**3. Type consistency**:`DebtSubtypes.creditCard`/`ReceivableSubtypes.personal` 等 const 名一致(Task 4 定义,Task 7-9 用)。`Debt.subtype` String 一致。`CreateDebtParams.subtype` String 一致。

无 gap。
