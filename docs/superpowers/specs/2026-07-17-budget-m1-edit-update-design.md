# budget M1 · edit delete+recreate → UpdateBudget · 设计 spec

- **日期**: 2026-07-17
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans → subagent session)
- **分支**: 待定(main-driven,从 main 最新 `ded0027`)
- **范围**: budget M1 defer —— budget 编辑(整体 name+currency+items)的 **DeleteBudget + CreateBudget(delete+recreate)→ 真正 UpdateBudget RPC**。根除 ID 变 / 竞态 / 非原子。零 ent schema 改动。

## 1. 背景

D-budget([2026-07-01-holding-budget-design.md](2026-07-01-holding-budget-design.md))交付的 budget 编辑流程是 MVP 妥协:[budget_form_page.dart:265-274](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart#L265) 的 `_submit()` 在 `_isEdit` 时:

```dart
// 编辑模式 MVP:删旧 + 重建(对齐 brief 决策)。
if (_isEdit) {
  bloc.add(DeleteBudgetRequested(widget.budgetId!));
}
bloc.add(CreateBudgetRequested(name: ..., month: ..., currencyCode: ..., items: items));
```

即 **edit = DeleteBudget + CreateBudget**(删旧 budget + 重建,**新 budget ID**)。后果:
1. **budget ID 变** —— 任何对旧 ID 的导航/引用(client route `/budgets/:id`、clone `SourceBudgetID`、外键)断裂
2. **非原子** —— delete 成功但 create 失败(网络/校验)→ budget 丢失,无回滚
3. **竞态 hack** —— 触发 2 次 `BudgetListLoaded`,靠 [`_editCreateCount >= 2`](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart#L170) 计数等第 2 次才 pop(脆弱,顺序依赖)

**根因**:server 无 `UpdateBudget` RPC([budget_grpc.pb.go](../../yucai/server/internal/proto/budget/v1/budget_grpc.pb.go) 只有 Create/Delete/AddBudgetItem/RemoveBudgetItem/ComputeBudgetActuals/CloneBudgetToMonth);client bloc events 也无 Update([budget_event.dart](../../yucai/client/lib/budget/presentation/bloc/budget_event.dart))。

memory `holding-asset-management-todo` D-budget defer M1:"edit delete+recreate"。

**关键洞察**:[budget_repo.go:165-199](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165) 的 `Update` **已实现 items 全量替换 + 乐观锁**(删旧 items + 建新 + `Where(budget.Version(b.Version-1))`),照 [transaction_repo.go Update](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go#L405) 范式。但有 **2 个现有缺陷**(M1 顺修):① [line 167](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L167) delete items **未检查 err**;② [line 187-194](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L187) update **漏 `SetCurrencyCode`**(currency edit 现在不落库)。M1 复用 repo.Update + 补这 2 缺陷。

## 2. 目标

- budget 编辑(整体)用**单 `UpdateBudget` RPC**(原子,**budget ID 不变**)
- 根除 delete+recreate(ID 变 / 竞态 / 非原子 三大痛点)
- 顺修 repo.Update 2 缺陷(currency 持久化 + delete items err 检查)
- month 不可改(budget 身份标识)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 范围 | **整体 UpdateBudget(name+currency+items)** | 匹配 form 现有全量提交模式;直击根因;范围最内聚 |
| 2 | month | **锁(edit 时 disabled)** | budget = 月度预算,month 是身份标识;挪月应走 `CloneBudgetToMonth` 或新建;避开 (tenant,month) 唯一约束 / actuals 重算 / 语义混乱 |
| 3 | items 语义 | **A 全量替换**(repo.Update 已支持:删旧+建新) | 简单,匹配 form 全量提交;budget ID 稳定(M1 主目标);item ID 变无感(actuals 读时算,无 item 级持久引用) |
| 4 | 单 item edit | **不在范围**(无 `UpdateBudgetItem` RPC) | form 全量提交已覆盖编辑需求;detail page 无单 item edit UI;Approach B(diff 保 item ID)收益小复杂度高,未选 |
| 5 | version 锁 | **server repo `WHERE Version(v-1)`(client 不传 version)** | 照 budget 现状 `AddBudgetItem`/`RemoveBudgetItem`(client path 不传 version);repo 锁已检测 FindByID→commit 间并发。**与 debt/template 传 version 不同**(模块内一致优先;若需更严格 stale 检测,follow-up 加 client version) |
| 6 | proto | **+`UpdateBudget` RPC + `UpdateBudgetRequest` message,regen Go+Dart(protoc_plugin 25.0.0)** | 标准;无 schema 改动 |
| 7 | edit 成功 client 刷新 | **`_onUpdate` → `getBudget` → `BudgetDetailLoaded`**(照 `_onAddItem`/`_onRemoveItem`) | edit 返回 BudgetDTO(无 items),重新拉 detail 回填 items;form pop 返回 detail 页带新数据 |

## 4. 范围边界

| 在范围(M1) | 不在范围(defer / out) |
|---|---|
| server proto +`UpdateBudget` RPC + `UpdateBudgetRequest` | `UpdateBudgetItem` 单 item edit RPC |
| domain `Budget.Update(name, currencyCode, items)` 方法 | month 可改(锁) |
| repo `Update` 补 `SetCurrencyCode` + 修 delete items err | detail page 单 item edit UI |
| application `Service.UpdateBudget` + handler `UpdateBudget` | ComputeActuals persist(保留单 entryFunc) |
| client bloc `UpdateBudgetRequested` event + handler | actuals 读时算 batch(M2 已做) |
| client remote_ds/repo `updateBudget` + form `_submit` 改 update + month disabled + 去 `_editCreateCount` | backup/restore 链路(已有 FindAllForBackup/DeleteByTenant) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| **proto** | `proto/budget/v1/budget.proto` | +`rpc UpdateBudget(UpdateBudgetRequest) returns (BudgetResponse)` + `UpdateBudgetRequest{id,name,currency_code,items}`;regen Go+Dart stub |
| **domain**(budget) | `Budget` aggregate([entity.go](../../yucai/server/internal/budget/domain/entity.go)) | +`Update(name, currencyCode string, items []BudgetItem) error` —— 校验 + 替换 items + 重算 total + `IncrementVersion` |
| **adapter/driven**(budget) | `BudgetRepository.Update`([budget_repo.go:165](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165)) | 补 `SetCurrencyCode(b.CurrencyCode)` + 修 delete items err 检查(items 全量替换 + 乐观锁已就绪) |
| **application**(budget) | `Service`([service.go](../../yucai/server/internal/budget/application/service.go)) | +`UpdateBudget(ctx, UpdateBudgetRequest) (*BudgetDTO, error)` |
| **adapter/driving**(budget) | `BudgetHandler`([budget_handler.go](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go)) | +`UpdateBudget` handler |
| **client data** | `budget_remote_ds.dart` + `budget_repository(_abstract/_impl)` | +`updateBudget({id, name, currencyCode, items})` |
| **client presentation** | `budget_event.dart` + `budget_bloc.dart` + `budget_form_page.dart` | +`UpdateBudgetRequested` event + `_onUpdate` handler;form `_submit` `_isEdit` 改 dispatch update;month picker `_isEdit` disabled;去 `_editCreateCount` hack |

## 6. 核心改动

### 6.1 proto — UpdateBudget RPC + Request

[proto/budget/v1/budget.proto](../../yucai/proto/budget/v1/budget.proto)(加在现有 RPC 列表末尾,如 CloneBudgetToMonth 之后):

```proto
rpc UpdateBudget(UpdateBudgetRequest) returns (BudgetResponse) {
  option (google.api.http) = {
    put: "/v1/budgets/{id}"
    body: "*"
  };
}

// UpdateBudgetRequest edits a budget's editable fields in place (no ID change,
// no delete+recreate). Month is immutable (budget identity). items is a full
// replacement (old items deleted, new items inserted — item IDs change, budget
// ID stable). No client version: optimistic lock is server-side (repo
// WHERE version = v-1), matching AddBudgetItem/RemoveBudgetItem.
message UpdateBudgetRequest {
  string id = 1;
  string name = 2;
  string currency_code = 3;
  repeated BudgetItemInput items = 4;
}
```

regen:`cd yucai/server && buf generate --template buf.gen.go.yaml` + `cd yucai && make gen-dart`(**protoc_plugin 25.0.0**)。

### 6.2 domain — Budget.Update

[entity.go](../../yucai/server/internal/budget/domain/entity.go)(加在 `UpdateItemAmount` 之后,`NewBudget` 校验逻辑的 in-place 版):

```go
// Update replaces editable fields (name, currency, items) in place. Month is
// immutable (budget identity). Validates like NewBudget (name non-empty,
// items ≥ 1), reassigns item IDs/BudgetID, recomputes TotalAmountCents, and
// bumps the optimistic-lock version. Items are fully replaced — the repo
// deletes old items and inserts new ones, so item IDs change but the budget
// ID stays stable (the whole point of M1: no delete+recreate of the budget).
func (b *Budget) Update(name, currencyCode string, items []BudgetItem) error {
	name = trimAndCheck(name)
	if name == "" {
		return fmt.Errorf("budget name must not be empty")
	}
	if len(items) == 0 {
		return fmt.Errorf("budget must have at least 1 item")
	}
	var total int64
	for i := range items {
		if items[i].ID == uuid.Nil {
			items[i].ID = uuid.New()
		}
		items[i].BudgetID = b.ID
		total += items[i].PlannedAmountCents
	}
	b.Name = name
	b.CurrencyCode = currencyCode
	b.Items = items
	b.TotalAmountCents = total
	b.IncrementVersion()
	return nil
}
```

注:不调 `NewBudget`(它创新 ID + Version=1);`Update` 改现有 budget + `IncrementVersion`(Version+1)。`month` / `IsActive` / `TenantID` 不动。

### 6.3 repo — Update 补 SetCurrencyCode + 修 delete items err

[budget_repo.go:165-199](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165)(items 全量替换 + 乐观锁已就绪,只补 2 处):

```go
func (r *BudgetRepository) Update(ctx context.Context, b *domain.Budget) error {
	// Delete old items (FIX: 现状 line 167 忽略 err)
	if _, err := r.client.BudgetItem.Delete().
		Where(budgetitem.BudgetID(b.ID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("delete old budget items: %w", err)
	}

	// Insert new items
	for _, item := range b.Items {
		_, err := r.client.BudgetItem.Create().
			SetID(item.ID).
			SetBudgetID(item.BudgetID).
			SetAccountID(item.AccountID).
			SetPlannedAmountCents(item.PlannedAmountCents).
			SetActualAmountCents(item.ActualAmountCents).
			SetNotes(item.Notes).
			Save(ctx)
		if err != nil {
			return fmt.Errorf("insert budget item: %w", err)
		}
	}

	// Update budget (FIX: 补 SetCurrencyCode —— 现状漏, currency edit 不落库)
	_, err := r.client.Budget.UpdateOneID(b.ID).
		Where(budget.Version(b.Version - 1)).       // 乐观锁
		SetName(b.Name).
		SetCurrencyCode(b.CurrencyCode).            // FIX: 新增
		SetTotalAmountCents(b.TotalAmountCents).
		SetIsActive(b.IsActive).
		SetVersion(b.Version).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update budget: %w", err)
	}
	return nil
}
```

### 6.4 application — Service.UpdateBudget

[service.go](../../yucai/server/internal/budget/application/service.go)(加在 `AddBudgetItem` 之前,整体编辑入口):

```go
// UpdateBudgetRequest edits a budget in place (no ID change, no delete+recreate).
type UpdateBudgetRequest struct {
	TenantID     uuid.UUID
	BudgetID     uuid.UUID
	Name         string
	CurrencyCode string
	Items        []BudgetItemInput
}

// UpdateBudget edits a budget's name/currency/items. Month is immutable.
// Optimistic lock: domain.Update bumps version (v→v+1), repo.Update matches
// WHERE version = v-1 — concurrent edits since FindByID are rejected. Best-effort
// recompute of read-time actuals happens on next GetBudget (read-time path,
// not persisted here).
func (s *Service) UpdateBudget(ctx context.Context, req UpdateBudgetRequest) (*BudgetDTO, error) {
	budget, err := s.repo.FindByID(ctx, req.TenantID, req.BudgetID)
	if err != nil {
		return nil, fmt.Errorf("budget not found: %w", err)
	}
	items := make([]domain.BudgetItem, len(req.Items))
	for i, input := range req.Items {
		items[i] = domain.BudgetItem{
			AccountID:          input.AccountID,
			PlannedAmountCents: input.PlannedAmountCents,
			Notes:              input.Notes,
		}
	}
	if err := budget.Update(req.Name, req.CurrencyCode, items); err != nil {
		return nil, fmt.Errorf("update budget: %w", err)
	}
	if err := s.repo.Update(ctx, budget); err != nil {
		return nil, fmt.Errorf("persist budget: %w", err)
	}
	dto := BudgetToDTO(budget)
	return &dto, nil
}
```

### 6.5 handler — UpdateBudget

[budget_handler.go](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go)(对齐 `CreateBudget` handler 解析范式):

```go
// UpdateBudget edits a budget in place.
func (h *BudgetHandler) UpdateBudget(ctx context.Context, req *pb.UpdateBudgetRequest) (*pb.BudgetResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	budgetID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}
	items := make([]application.BudgetItemInput, len(req.Items))
	for i, item := range req.Items {
		aid, err := uuid.Parse(item.AccountId)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid account_id in item %d", i)
		}
		items[i] = application.BudgetItemInput{
			AccountID:          aid,
			PlannedAmountCents: item.PlannedAmountCents,
			Notes:              item.Notes,
		}
	}
	resp, err := h.service.UpdateBudget(ctx, application.UpdateBudgetRequest{
		TenantID:     tenantID,
		BudgetID:     budgetID,
		Name:         req.Name,
		CurrencyCode: req.CurrencyCode,
		Items:        items,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetResponse{Budget: budgetToProto(*resp)}, nil
}
```

### 6.6 client data — remote_ds + repo

[budget_remote_ds.dart](../../yucai/client/lib/budget/data/budget_remote_ds.dart)(对齐 `createBudget` / debt `update` 范式):

```dart
Future<BudgetView> updateBudget({
  required String id,
  required String name,
  required String currencyCode,
  required List<({String accountId, int plannedAmountCents, String? notes})> items,
}) {
  return _retry.call(() async {
    final res = await _client.updateBudget(pb.UpdateBudgetRequest(
      id: id,
      name: name,
      currencyCode: currencyCode,
      items: items.map((it) => pb.BudgetItemInput(
        accountId: it.accountId,
        plannedAmountCents: Int64(it.plannedAmountCents),
        notes: it.notes ?? '',
      )).toList(),
    ));
    return BudgetMapper.toView(res.budget);
  });
}
```

`BudgetRepository`(abstract)+ `BudgetRepositoryImpl` 加对应 `updateBudget(...)`(`_guard` 包装,照 `createBudget`)。

### 6.7 client presentation — bloc event + handler + form

[budget_event.dart](../../yucai/client/lib/budget/presentation/bloc/budget_event.dart)(加 event,对齐 `CreateBudgetRequested`):

```dart
/// 编辑预算(整体 name+currency+items 原地更新,不删旧重建)。
/// month 不可改(budget 身份);items 全量替换。
class UpdateBudgetRequested extends BudgetEvent {
  const UpdateBudgetRequested({
    required this.budgetId,
    required this.name,
    required this.currencyCode,
    required this.items,
  });
  final String budgetId;
  final String name;
  final String currencyCode;
  final List<({String accountId, int plannedAmountCents, String? notes})> items;

  @override
  List<Object?> get props => [budgetId, name, currencyCode, items];
}
```

[budget_bloc.dart](../../yucai/client/lib/budget/presentation/bloc/budget_bloc.dart)(注册 handler,照 `_onAddItem` 成功后重拉 detail):

```dart
on<UpdateBudgetRequested>(_onUpdate);

/// updateBudget 返回 BudgetDTO(无 items),重新拉完整 budget 回填 items
/// (照 _onAddItem/_onRemoveItem 范式)。
Future<void> _onUpdate(UpdateBudgetRequested event, Emitter<BudgetState> emit) async {
  emit(BudgetLoading());
  final result = await _repo.updateBudget(
    id: event.budgetId,
    name: event.name,
    currencyCode: event.currencyCode,
    items: event.items,
  );
  await result.fold(
    (failure) async => emit(BudgetError(failure.displayMessage)),
    (_) async {
      final detail = await _repo.getBudget(event.budgetId);
      detail.fold(
        (failure) => emit(BudgetError(failure.displayMessage)),
        (budget) => emit(BudgetDetailLoaded(budget)),
      );
    },
  );
}
```

[budget_form_page.dart](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart):

`_submit()`([line 265-274](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart#L265))—— edit 改用 update:
```dart
// 编辑模式:原地 UpdateBudget(不再 delete+recreate)。
if (_isEdit) {
  bloc.add(UpdateBudgetRequested(
    budgetId: widget.budgetId!,
    name: _nameCtrl.text.trim(),
    currencyCode: _currencyCode,
    items: items,
  ));
} else {
  bloc.add(CreateBudgetRequested(
    name: _nameCtrl.text.trim(),
    month: _month,
    currencyCode: _currencyCode,
    items: items,
  ));
}
```

`_onBudgetStateChanged` 第二段([line 165-179](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart#L165),`_submitted` pop 逻辑)—— 去 `_editCreateCount` hack。**第一段([line 148-164](../../yucai/client/lib/budget/presentation/pages/budget_form_page.dart#L148),`BudgetDetailLoaded` + `_existingBudget == null` 预填 load)保留不动**:edit 提交后 `_existingBudget != null`,第一段不触发,第二段(`_submitted && _isEdit`)接 `BudgetDetailLoaded` pop。
```dart
// edit 成功:update → BudgetDetailLoaded(单次)→ pop
// create 成功:BudgetListLoaded → pop
if (_submitted && _isEdit && state is BudgetDetailLoaded) {
  _submitted = false;
  Navigator.of(context).pop(true);
}
if (_submitted && !_isEdit && state is BudgetListLoaded) {
  _submitted = false;
  Navigator.of(context).pop(true);
}
```

month picker `_isEdit` 时 disabled(`_pickMonth` 入口在 edit 模式 AbsorbPointer / 灰显 + 不可点);删除 `_editCreateCount` field。

## 7. 数据流

- **edit 提交**:form `_submit`(`_isEdit`)→ `UpdateBudgetRequested` → bloc `_onUpdate` → `repo.updateBudget` → remote_ds `updateBudget` RPC → server `BudgetHandler.UpdateBudget` → `Service.UpdateBudget`(FindByID → `domain.Update` 校验+替换+version+1 → `repo.Update` 删旧 items+建新+乐观锁 `WHERE Version(v-1)`)→ `BudgetResponse`(BudgetDTO,**同 ID**)→ client `_onUpdate` 重拉 `getBudget` → `BudgetDetailLoaded`(新数据)→ form pop。
- **单 RPC、原子、budget ID 不变**。actuals 不在 update 持久(下次 GetBudget 读时算 M2 batch)。

## 8. 测试

- **server domain** `Budget.Update`:校验(name 空 / items 0 → err);替换 items(item IDs 重分配 / BudgetID 设);重算 TotalAmountCents(Σ planned);currency 更新;month 不变;IncrementVersion(v+1)。
- **server repo** `Update`(enttest SQLite):补的 `SetCurrencyCode` 持久化(currency edit 落库);items 全量替换(旧删+新建);**乐观锁** version 冲突(并发改后 WHERE Version(v-1) 不匹配 → 失败);delete items err 检查。
- **server application** `Service.UpdateBudget`:FindByID + Update + repo.Update 委托;version 冲突 propagate(repo 锁失败 → error)。
- **server handler** `UpdateBudget`:req 解析(account_id invalid → InvalidArgument);mapError。
- **server 约束 6**:`BudgetRepository` interface 无新方法(Update 已存在),无 implementer 影响。proto 加 RPC → handler 嵌入 Unimplemented(替换默认)。**NewService 签名不变**(`entryFunc`/`entryMonthFunc` 已在 M2 加,不动)→ wire/wire_gen.go **不改**。
- **client** bloc `_onUpdate`(成功 → BudgetDetailLoaded;失败 → BudgetError);form `_submit` edit 路径 dispatch UpdateBudgetRequested(无 delete+recreate);month picker edit disabled;`_editCreateCount` 删除。

## 9. 风险

1. **proto regen**(CLAUDE.md):protoc_plugin **25.0.0**(Dart);Go+Dart stub 都 regen。加 RPC 不破坏现有(append-only)。
2. **乐观锁语义**(决策 5):server `FindByID` 读最新 version,`domain.Update` IncrementVersion(v+1),repo `WHERE Version(v)`(= (v+1)-1)匹配 → 成功。并发场景:FindByID 后、commit 前另一 edit 让 DB v+1 → 我的 WHERE v 不匹配 → 失败(repo 锁检测)。**client 不传 version**(照 budget 现状 AddItem/RemoveItem);若需更严格 stale UI 检测,follow-up 加 client version + service 显式校验。
3. **wire 不改**:M1 不动 `NewService` 签名(M2 已加 entryMonthFunc),`provideBudgetService` 不变 → wire_gen.go 不改(memory `yucai-wire-handmaintained` 无触发)。
4. **month disabled UX**:form edit 时 month picker 须真 disabled(AbsorbPointer + 视觉灰显),否则用户改 month 但 RPC 不含 month → 静默丢失。双向保证:UI 禁用 + proto 无 month 字段(即使传也忽略)。
5. **item ID 变**(决策 3):全量替换致 item IDs 变。actuals 读时算(M2)无 item 级引用,用户无感。若未来加 item 级引用(如 recurring rule 关联 item),需重新评估 diff 方案。
6. **edit 返回 BudgetDTO 无 items**:`_onUpdate` 照 `_onAddItem` 重拉 `getBudget` 回填 items(BudgetDetailLoaded),避免 detail 页 items 丢失。
7. **budget_integration_test.go**:现有 [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go) 若测 edit 路径(M2 时 NewService 改 3 参已动过),M1 加 UpdateBudget 测试 + 确认现有 edit/delete 测试不回归。

## 10. 参考

- D-budget spec:[2026-07-01-holding-budget-design.md](2026-07-01-holding-budget-design.md)(budget actuals 读时算 + edit MVP delete+recreate 决策)
- budget M2 spec:[2026-07-17-budget-m2-batch-actuals-design.md](2026-07-17-budget-m2-batch-actuals-design.md)(entryMonthFunc port + 约束 6 教训:签名变更 grep 全调用方含 tests/ 集成测)
- items 全量替换 + 乐观锁范式:[budget_repo.go Update:165](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165) + [transaction_repo.go Update:405](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go#L405)
- debt client update(传 version 范式,本 spec 不照):[debt_remote_ds.dart update:104](../../yucai/client/lib/debt/data/debt_remote_ds.dart#L104)
- memory:`holding-asset-management-todo`(D-budget M1 defer)、`yucai-wire-handmaintained`(wire 不改判定)、CLAUDE.md 约束 6
