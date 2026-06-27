# 债权模块(BorrowedOut) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Checkbox (`- [ ]`) syntax.

**Goal:** 扩展 debt type(BORROWED_OUT 别人欠我)+ 独立 /receivables 债权页(对称 debt module,收款而非还款)。

**Architecture:** server 加 DebtType(proto/ent/migrate/service type filter);client 加 DebtType enum + typeFilter + 独立 receivables_page/receivable_detail_page/receivable_form_page(对称 debt pages)+ router /receivables branch。

**Tech Stack:** Go(ent + gRPC + proto) + Flutter(flutter_bloc + injectable + grpc-dart + 御财 token)。

## Global Constraints

- **DebtType enum**:proto `BORROWED_IN=1/BORROWED_OUT=2`(UNSPECIFIED=0),domain `borrowedIn/borrowedOut`。default BORROWED_IN(现有债务自动)。
- **对称 debt module**:client domain/data/bloc/pages 对齐 `lib/debt/`(Task 1-9 of debt-module),收款语义对称还款。
- **account 关联**:BorrowedOut → asset 应收(category otherAsset);BorrowedIn → liability(现有)。
- **收款语义**:RecordPayment = 确认收款(别人还我 → to 我的收款账户)。proto 复用 RecordPayment。
- **DI**:新 page/bloc 用 @injectable 或 router create(对齐 debt)。
- **御财 token**:奶油白/金/深色/绿/红/serif/mono。进度条 金色已收 + 灰底。已收绿✓/待收中性/逾期红。
- **分支**:`receivables-module`,BASE `97c1938`(spec)。
- **参考**:debt module(`lib/debt/`)+ OD `yucai-receivables-prototype-558f`(9 页)。

---

### Task 1: server proto DebtType + dart stub regen

**Files:**
- Modify: `yucai/proto/debt/v1/debt.proto`(加 DebtType enum + DebtDTO/CreateDebtRequest/ListDebtsRequest type field)
- Modify: client dart stub regen(`make gen-dart` or local protoc-gen-dart)

**Interfaces:**
- Produces: proto `DebtType` enum + DTO type fields → Task 2 ent + Task 3 service + Task 5 mapper 用

- [ ] **Step 1: 加 proto DebtType**

在 `debt.proto` 加(在 AmortizationMethod 后):
```proto
enum DebtType {
  DEBT_TYPE_UNSPECIFIED = 0;
  DEBT_TYPE_BORROWED_IN = 1;
  DEBT_TYPE_BORROWED_OUT = 2;
}
```

DebtDTO 加 `DebtType debt_type = 13;`(在 version 后)。CreateDebtRequest 加 `DebtType debt_type = 8;`。ListDebtsRequest 加 `DebtType type_filter = 2;`。

- [ ] **Step 2: regen Go + dart stub**

```bash
cd yucai/server && go generate ./...  # ent/proto Go stub
cd yucai/client && make gen-dart  # dart stub(本地 protoc-gen-dart)
```

- [ ] **Step 3: commit**

```bash
git add yucai/proto/ yucai/server/internal/proto/ yucai/client/lib/proto/debt/
git commit -m "feat(debt-proto): DebtType enum + DTO type fields(BorrowedOut 债权)"
```

---

### Task 2: server ent debt_type column + migrate

**Files:**
- Modify: `yucai/server/internal/debt/ent/schema/debt_details.go`(加 debt_type field)
- Run: `go generate ./...`(ent regen)+ migrate(自动 ent migrate)

- [ ] **Step 1: 加 ent field**

`debt_details.go` Fields() 加:
```go
field.String("debt_type").
    Default("borrowed_in").
    Comment("borrowed_in(我借入) / borrowed_out(我借出/债权)"),
```

- [ ] **Step 2: regen ent + migrate**

`go generate ./...` → ent 自动 migrate(加 debt_type column,default borrowed_in,现有行自动)。

- [ ] **Step 3: 验证 + commit**

`go test ./internal/debt/...` + `git commit -m "feat(debt-ent): debt_type column + migrate(default borrowed_in)"`

---

### Task 3: server domain/service/handler type 映射 + filter

**Files:**
- Modify: `yucai/server/internal/debt/domain/entity.go`(DebtDetails 加 DebtType)
- Modify: `yucai/server/internal/debt/application/{service.go,dto.go}`(CreateDebt/ListDebts type)
- Modify: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go`(proto↔domain type + type_filter)

- [ ] **Step 1: domain DebtType + entity field**

`domain/entity.go` 加 `type DebtType int` 常量 + `DebtDetails.DebtType` field。`dto.go` CreateDebtRequest/ListDebtsRequest 加 DebtType。`service.go` CreateDebt 传 type;ListDebts filter type。

- [ ] **Step 2: handler proto↔domain type 映射 + ListDebts type_filter**

`debt_handler.go` debtToProto(domain→proto DebtType)+ CreateDebt handler 读 req.DebtType + ListDebts handler 传 type_filter。

- [ ] **Step 3: test + commit**

`go test ./internal/debt/...` + `git commit -m "feat(debt-server): DebtType domain/service/handler + ListDebts type_filter"`

---

### Task 4: client domain DebtType + Debt.type + repo typeFilter

**Files:**
- Modify: `yucai/client/lib/debt/domain/value_objects.dart`(加 DebtType enum)
- Modify: `yucai/client/lib/debt/domain/entities/debt_entity.dart`(Debt 加 type field)
- Modify: `yucai/client/lib/debt/domain/repositories/debt_repository.dart`(list + create 加 optional DebtType)
- Test: `yucai/client/test/debt/domain/debt_entity_test.dart`

- [ ] **Step 1: 加 DebtType enum + Debt.type**

`value_objects.dart` 加 `enum DebtType { borrowedIn, borrowedOut }`。`debt_entity.dart` Debt 加 `final DebtType type;`(default borrowedIn via constructor)。

- [ ] **Step 2: repo list/create 加 optional type**

`debt_repository.dart` `list({DebtType? typeFilter})` + `create(... DebtType type)` 签名加 type。

- [ ] **Step 3: test + commit**

test DebtType field + `git commit -m "feat(debt-domain): DebtType enum + Debt.type + repo typeFilter"`

---

### Task 5: client mapper + remote_ds type 映射

**Files:**
- Modify: `yucai/client/lib/debt/data/mappers/debt_mapper.dart`(type proto↔domain)
- Modify: `yucai/client/lib/debt/data/debt_remote_ds.dart`(list/create 传 type)
- Test: `yucai/client/test/debt/data/debt_mapper_test.dart`

- [ ] **Step 1: mapper type 双向**

`debt_mapper.dart` 加 `_debtTypeFromProto`/`debtTypeToProto`(name-based,off-by-one:UNSPECIFIED=0/BORROWED_IN=1/BORROWED_OUT=2 ↔ domain 0/1，注意 off-by-one，name-based switch)。

- [ ] **Step 2: remote_ds type**

`debt_remote_ds.dart` `list({DebtType? typeFilter})` → ListDebtsRequest.type_filter;`create(... DebtType type)` → CreateDebtRequest.debt_type。

- [ ] **Step 3: test + commit**

`git commit -m "feat(debt-data): mapper/remote_ds DebtType 映射"`

---

### Task 6: client repo_impl typeFilter + bloc typeFilter

**Files:**
- Modify: `yucai/client/lib/debt/data/debt_repository_impl.dart`(list/create type 透传)
- Modify: `yucai/client/lib/debt/presentation/bloc/debt_event.dart`(LoadDebtsRequested 加 typeFilter)+ bloc handler
- Test: `yucai/client/test/debt/presentation/bloc/debt_bloc_test.dart`

- [ ] **Step 1: repo_impl 透传**

`debt_repository_impl.dart` list/create 加 type。

- [ ] **Step 2: bloc LoadDebtsRequested typeFilter**

`debt_event.dart` LoadDebtsRequested 加 `final DebtType? typeFilter`。bloc `_onLoadDebts` 传 `repo.list(typeFilter: event.typeFilter)`。

- [ ] **Step 3: test + commit**

`git commit -m "feat(debt-bloc): LoadDebtsRequested typeFilter(债权/债务分离)"`

---

### Task 7: client receivables_page(债权列表 + 三端)

**Files:**
- Create: `yucai/client/lib/debt/presentation/pages/receivables_page.dart`
- Test: `yucai/client/test/debt/presentation/pages/receivables_page_test.dart`

**参考**: `debts_page.dart`(对称)+ OD `receivables*.html`。

- [ ] **Step 1: 实现 receivables_page**

对齐 `debts_page.dart`(_OverviewCard 总应收 + _ReceivableCard 债务人/剩余应收/progress/收款/操作 + 三端 ResponsiveLayout + FAB)。区别:LoadDebtsRequested(typeFilter: DebtType.borrowedOut);UI label「应收/收款」(非「负债/还款」)。对齐 OD receivables.html/tablet/mobile。

- [ ] **Step 2: test + commit**

test 债权卡 + progress + 收款操作 + 三端 viewport。`git commit -m "feat(receivables): receivables_page 债权列表 + 三端"`

---

### Task 8: client receivable_detail_page(收款详情 + schedule + 三端)

**Files:**
- Create: `yucai/client/lib/debt/presentation/pages/receivable_detail_page.dart`
- Test: `yucai/client/test/debt/presentation/pages/receivable_detail_page_test.dart`

**参考**: `debt_detail_page.dart`(对称)+ OD `receivable-detail*.html`。

- [ ] **Step 1: 实现 receivable_detail_page**

对齐 `debt_detail_page.dart`(_hero + _statRow + _scheduleTable/CardList + RecordPayment + 三端)。区别:label「剩余应收/收款计划/确认收款」(非「剩余本金/还款计划/记账」)。对齐 OD receivable-detail.html/tablet/mobile。LoadDebtRequested(typeFilter: borrowedOut)。

- [ ] **Step 2: test + commit**

`git commit -m "feat(receivables): receivable_detail_page 收款详情 + schedule + 三端"`

---

### Task 9: client receivable_form_page(创建债权 + step wizard)

**Files:**
- Create: `yucai/client/lib/debt/presentation/pages/receivable_form_page.dart`
- Test: `yucai/client/test/debt/presentation/pages/receivable_form_page_test.dart`

**参考**: `debt_form_page.dart`(对称)+ OD `receivable-form*.html`。

- [ ] **Step 1: 实现 receivable_form_page**

对齐 `debt_form_page.dart`(表单 + 摊还预览 + 三端 step wizard + edit mode)。区别:type=BorrowedOut 固定;account 关联 asset 应收(非 liability);label「债务人/借出本金/收款计划预览」。CreateDebtRequested(debt_type: borrowedOut)。对齐 OD receivable-form.html/tablet/mobile。

- [ ] **Step 2: test + commit**

`git commit -m "feat(receivables): receivable_form_page 创建债权 + step wizard + edit mode"`

---

### Task 10: router /receivables branch + AppShell nav + 收尾

**Files:**
- Modify: `yucai/client/lib/app/router.dart`(加 /receivables branch 4 + /receivables/:id + /receivables/new)
- Modify: `yucai/client/lib/app/widgets/app_shell.dart`(加 branch 4 债权 nav)
- Test: `yucai/client/test/app/router_test.dart`

- [ ] **Step 1: router /receivables branch**

`router.dart` 加 StatefulShellBranch(branch 4):
```dart
GoRoute(path: '/receivables',
  builder: (_, __) => MultiBlocProvider(
    providers: [
      BlocProvider<DebtBloc>(create: (_) {
        final b = DebtBloc(getIt<DebtRepository>());
        b.add(LoadDebtsRequested(typeFilter: DebtType.borrowedOut));
        return b;
      }),
      BlocProvider<CurrencyBloc>(create: (_) { final b = getIt<CurrencyBloc>(); b.add(const LoadCurrenciesRequested()); b.add(const LoadPreferencesRequested()); return b; }),
    ],
    child: const ReceivablesPage(),
  ),
  routes: [
    GoRoute(path: 'new', builder: (_, __) => BlocProvider<DebtBloc>(create: (_) => DebtBloc(getIt<DebtRepository>()), child: const ReceivableFormPage())),
    GoRoute(path: ':id', builder: (_, state) => MultiBlocProvider(
      providers: [
        BlocProvider<DebtBloc>(create: (_) { final b = DebtBloc(getIt<DebtRepository>()); b.add(LoadDebtRequested(state.pathParameters['id']!)); return b; }),
        BlocProvider<CurrencyBloc>(create: (_) { final b = getIt<CurrencyBloc>(); b.add(const LoadCurrenciesRequested()); b.add(const LoadPreferencesRequested()); return b; }),
      ],
      child: ReceivableDetailPage(id: state.pathParameters['id']!),
    )),
  ],
),
```

- [ ] **Step 2: AppShell nav branch 4**

`app_shell.dart` `_branchTitle` case 4 → '债权管理'。`_Sidebar`/`_BottomNav` nav 加 `_NavItem('债权', Icons.call_made_outlined, 4, route: '/receivables')`。redirect guard 加 `/receivables`。

- [ ] **Step 3: 全量验证 + commit**

`flutter test` + `flutter analyze lib/debt/ lib/app/`。`git commit -m "feat(receivables): router /receivables branch 4 + AppShell nav + 收尾"`

---

## Self-Review

**1. Spec coverage**:
- §3 server proto/ent/service → Task 1-3 ✓
- §4 client domain/data/bloc → Task 4-6 ✓
- §4.4 UI 3 页 → Task 7-9 ✓
- §4.5 router/nav → Task 10 ✓

**2. Placeholder**: 每 task 参考对称 debt module(`lib/debt/`)+ OD 9 页。关键 code 在 router(Task 10)。其他 task 对称 debt(Task 7-9 对称 debt pages Task 6-8)。

**3. Type consistency**: DebtType enum(domain borrowedIn/borrowedOut ↔ proto BORROWED_IN=1/BORROWED_OUT=2,off-by-one UNSPECIFIED=0,name-based mapper)。LoadDebtsRequested(typeFilter: DebtType.borrowedOut)贯穿 Task 6-10。

无 gap。
