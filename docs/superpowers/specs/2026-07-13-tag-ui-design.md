# tag client UI · 设计 spec

- **日期**: 2026-07-13
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: tag client UI 新建 —— tag 管理(settings 子页 CRUD)+ transaction 表单集成(占位 chip-row → 真 tag)+ transaction 列表/详情显示 tag chip。client DDD 四层新建,零 proto/server 改动(server TagService 7 RPC + TagDTO 全实现,client proto stub 全有)。
- **decompose**: tag/template 是 2 独立子系统。本 spec = tag(template 周期交易模板后续独立 spec)。

## 1. 背景

御财 server **TagService 全实现**(7 RPC:CreateTag/UpdateTag/DeleteTag/ListTags + AddTagToTransaction/RemoveTagFromTransaction/GetTransactionTags),client proto stub 全有(`lib/proto/tag/v1/tag.pbgrpc.dart`),但**client 无 tag UI**(`lib/tag/` 不存在)。

transaction 表单(`transaction_form_page.dart:132-245`)有**占位 tag chip-row**:4 个硬编码 chip(日常/出差/请客/报销),本地 `Set<String> _tags` toggle,**不持久化**,标 🔒 待 Tags 模块。

memory `holding-asset-management-todo`:后续模块 tag/template UI(server 有,client 无)。

## 2. 目标

tag client UI:管理(CRUD name/color)+ transaction 表单选 tag(多选持久化)+ transaction 列表/详情显示 tag chip。client DDD 四层新建。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| tag domain/data/presentation/core 四层新建 | template UI(周期交易模板,独立 spec) |
| tag 管理 settings 子页 `/settings/tags`(CRUD name/color) | tag 筛选 transaction(列表按 tag 过滤,follow-up) |
| transaction 表单集成(占位 → 真 tag,多选 + AddTag/RemoveTag 持久化) | server 改动(零 proto/server,TagService 7 RPC 全有) |
| transaction 列表/详情显示 tag chip(并发 GetTransactionTags) | tag 合并/重命名批量(transaction 级联) |
| color 预置色板 picker | tag 导入/导出 |

**零 proto/server 改动**(TagServiceClient stub + TagDTO 全有)。

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | decompose | tag 先(template 后续) | tag/template 独立子系统,单 spec 太大 |
| 2 | 范围 | 核心(管理+表单)+ 列表显示 | 最小可用 + 显示低成本;筛选 defer |
| 3 | 管理入口 | settings 子页 `/settings/tags` | 低频 CRUD,对齐 backup `/settings/backup` |
| 4 | 列表 N+1 | client 并发 GetTransactionTags(per txn,分页 20 并发 ~10ms) | TransactionDTO 无 tags,client-only 零 server;并发可接受 |
| 5 | 架构 | DDD 四层(对齐 backup/debt) | 复用范式,remote_ds AuthRetryCaller + repo Either<Failure> |

## 5. 架构(client DDD 四层)

| 层 | 组件 | 职责 |
|---|---|---|
| **domain**(`lib/tag/domain/`) | `Tag` entity(Equatable)+ `TagRepository` abstract | entity(id/name/color/version)+ repo 接口(7 method) |
| **data**(`lib/tag/data/`) | `TagRemoteDataSource`(@LazySingleton)+ `TagRepositoryImpl`(@LazySingleton(as:TagRepository))+ `tag_mapper.dart` | 7 RPC(AuthRetryCaller wrap,对齐 debt/backup)+ Either<Failure> + proto→entity |
| **presentation**(`lib/tag/presentation/`) | `TagBloc`(@injectable)+ `TagPage` + `TagCard` + `TagColorPicker` | event(load/create/update/delete)+ state(Loading/Loaded/Submitting/ActionSuccess/Error)+ 管理 UI |
| **集成**(transaction 模块改) | `transaction_form_page.dart`(占位 → 真 tag)+ transaction 列表(card tag chip) | 表单多选 + 列表显示 |
| **core** | DI(@injectable)+ router | `/settings/tags` route + settings `_NavRow` 入口 + build_runner |

**零 proto/server**(TagServiceClient 7 method stub 全有;TagDTO 字段全有)。

## 6. tag 管理(`/settings/tags`,对齐 backup)

### 6.1 TagPage
- **Header**:标题「标签管理」+ 「新建标签」FilledButton
- **ListView**:`TagCard[]`(对齐 list 卡片模式)
- **empty state**:「暂无标签,点击「新建标签」创建」
- **error state**:TagError(msg) + retry

### 6.2 TagCard
- color 圆点(tag.color)+ name + edit(lucide `pencil`)+ delete(lucide `trash2`)icon
- edit → dialog(name TextField + TagColorPicker)→ UpdateTag
- delete → confirm dialog → DeleteTag

### 6.3 TagColorPicker
- 预置色板(御财 token 色 + 几色:#b08d57 金 / #2e7d32 绿 / #c0392b 红 / #1976d2 蓝 / #7b1fa2 紫 / #f57c00 橙 / #54504a 灰)
- 选中态(border + check)
- 选色 → color(#RRGGBB,server hexColorRegex 校验)

### 6.4 交互
| 操作 | 流程 |
|---|---|
| **创建** | 「新建标签」→ dialog(name + color)→ CreateTag → 列表刷新 + SnackBar |
| **编辑** | card edit icon → dialog(预填 name/color)→ UpdateTag → 刷新 |
| **删除** | card delete → confirm → DeleteTag → 刷新 |
| **in-progress** | AbsorbPointer + spinner |

## 7. transaction 表单集成(替换占位 chip-row)

`transaction_form_page.dart` 现占位 `_tagsChipRow`(L132-245:4 硬编码 chip,本地 `_tags`,不持久化)→ 真 tag:

- **加载**:进入表单 → `ListTags`(全部 tag)+ 编辑时 `GetTransactionTags(txnId)`(预选)
- **多选 chip**:toggle(选中态 = tag.color 背景 + 白字;未选 = border + tag.color 字)。横向滚动(Overflow)
- **提交 diff**:表单 save → 计算 diff(新增 `AddTagToTransaction(tagId, txnId)` / 移除 `RemoveTagFromTransaction(tagId, txnId)`)。新建 transaction 先 create 拿 txnId 再 AddTag
- **TagBloc 复用**:表单 inject TagBloc(load tags + 关联操作)。或 transaction bloc 扩展 tag 子 state —— 推荐 TagBloc 复用(管理 + 表单选)

**关键**:占位 `_tags` `Set<String>`(本地名)→ 真 `Set<String>` tag IDs(持久化)。`_tagOptions` 硬编码 → ListTags 加载。

## 8. transaction 列表/详情显示 tag chip

### 8.1 列表(card/row)
- transaction card 显示 tag chip(name + tag.color 背景)
- **加载**:**per-card `FutureBuilder`**(每 card 独立 `getTransactionTags(txnId)`,列表 N card 各自 FutureBuilder 自然并发 ~10ms/页,不进 TagBloc state 避免 N state 累积)。失败降级(card 无 chip,不阻塞列表)
- chip 紧凑(小号,name 截断)

### 8.2 详情
- transaction 详情页:`GetTransactionTags(txnId)`(单 txn,1 RPC)→ 显示 tag chip section

## 9. TagBloc(event/state)

### 9.1 event
- `LoadTagsRequested`(管理页/表单加载 tag list)
- `CreateTagRequested(name, color)`
- `UpdateTagRequested(id, name, color, version)`
- `DeleteTagRequested(id)`
- `LoadTransactionTagsRequested(txnId)`(列表/详情/表单预选)

### 9.2 state
- `TagInitial` / `TagLoading` / `TagsLoaded(tags)` / `TagSubmitting` / `TagActionSuccess(message)` / `TagError(message)`
- `TransactionTagsLoaded(txnId, tags)`(单 txn —— **表单编辑预选用**;列表/详情用 per-card FutureBuilder 不进 Bloc state)

(对齐 backup BackupBloc 模式:ActionSuccess 一次性 SnackBar 反馈 + fold 双 emit + add refresh)

## 10. domain/data 细节

### Tag entity
```dart
class Tag extends Equatable {
  const Tag({required this.id, required this.name, required this.color, required this.version});
  final String id; final String name; final String color; final int version;
  @override List<Object?> get props => [id, name, color, version];
}
```

### TagRepository abstract(7 method)
```dart
abstract class TagRepository {
  Future<Either<Failure, List<Tag>>> list();
  Future<Either<Failure, Tag>> create({required String name, required String color});
  Future<Either<Failure, Tag>> update({required String id, required String name, required String color, required int version});
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, void>> addTagToTransaction({required String tagId, required String transactionId});
  Future<Either<Failure, void>> removeTagFromTransaction({required String tagId, required String transactionId});
  Future<Either<Failure, List<Tag>>> getTransactionTags(String transactionId);
}
```

### TagRemoteDataSource(@LazySingleton)
- 7 RPC,AuthRetryCaller wrap,对齐 debt/backup(throw GrpcError 给 repo catch)
- list:ListTagsRequest(pageSize 100)
- create/update/delete/add/remove/getTransactionTags

### tag_mapper
- TagDTO → Tag(`id/name/color/version.toInt()`)
- proto TagDTO 字段:id/name/color/version/created_at/updated_at

## 11. 降级 + 测试

**降级**:
| 场景 | 处理 |
|---|---|
| RPC fail(list/create/update/delete/关联) | TagError(msg) + retry / SnackBar |
| 空列表 | empty state |
| 表单 ListTags fail | chip-row 空 + 提示(不阻塞表单 save) |
| 列表 GetTransactionTags fail | card 不显示 tag(降级,不阻塞列表) |
| color 非 #RRGGBB | 前端 picker 限制(预置色),server 兜底 ValidationFailure |

**测试**:
- **TagBloc** test(mocktail MockTagRepository;load/create/update/delete/getTransactionTags + state 流 + ActionSuccess)
- **TagPage** widget test(CRUD 渲染 + create dialog + edit/delete confirm + empty/error state)
- **transaction 表单集成** widget test(chip 多选 toggle + 提交 AddTag/RemoveTag verify)
- **mapper test**(TagDTO → Tag)
- **回归**:tag 新模块 + transaction 表单/列表改,现有测不破(flutter test 1 预存 fail account_detail;analyze 22 基线)

## 12. 风险

1. **列表 N+1**(TransactionDTO 无 tags,并发 GetTransactionTags per txn ~10ms/页)—— 可接受;follow-up server TransactionDTO 加 tags 或 batch RPC
2. **表单提交 diff**(AddTag/RemoveTag 精确:原 tags vs 新选,diff 增删)—— 测覆盖
3. **新建 transaction 无 txnId**(create 后拿 txnId 再 AddTag,两步)—— 表单 save 流程:先 create txn → 拿 id → AddTag per selected
4. **tag 删除后 transaction 关联**(server cascade RemoveTagFromTransaction?或 transaction 残留 tag_id)—— server 行为,client 删除后刷新(列表 GetTransactionTags 返回空若 server cascade)
5. **color 校验**(#RRGGBB hexColorRegex,server ValidationFailure 兜底)—— 前端 picker 预置色避错
6. **TagBloc 复用**(管理页 + 表单 + 列表/详情多场景)—— state 设计清晰(TagsLoaded 全量 + TransactionTagsLoaded per txn)

## 13. 参考

- server proto:[tag.proto TagService 7 RPC + TagDTO](../../yucai/proto/tag/v1/tag.proto)
- client stub:[TagServiceClient](../../yucai/client/lib/proto/tag/v1/tag.pbgrpc.dart)(7 method)
- 占位:transaction_form_page.dart:132-245(`_tagsChipRow` 🔒 待 Tags 模块)
- 范式:backup client UI([2026-07-13-backup-local-design.md](2026-07-13-backup-local-design.md),settings 子页 + DDD 四层 + Bloc ActionSuccess)
- memory:[[holding-asset-management-todo]](tag/template 后续模块)
