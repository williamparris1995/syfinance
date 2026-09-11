# Task Brief F19-T1 — 全量标记 + 合并链 + 向导 UI

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f19`,客户端 `yucai/client/`。**TDD。**

## 先读(必读)
1. `docs/.../2026-09-06-bind-merge/{spec.md 全部,design.md 全部}`
2. `lib/binding/presentation/bloc/binding_bloc.dart`(守卫/状态机/上传链——改造主对象)、`lib/binding/presentation/pages/binding_page.dart`(blocked/readyToUpload/uploading UI)
3. `lib/binding/data/pending_collector.dart`(收集器——合并链复用)、`lib/binding/data/grpc_offline_sync_port.dart`(push/encodeRequest)、`lib/core/localdb/daos/`(markXSynced 家族——markAllPending 落点)
4. `lib/binding/presentation/bloc/sync_coordinator_bloc.dart`(writeBack 语义——合并链的批后回写参照;**不动协调器**——合并链在 binding bloc 内联)
5. 既有测试:`test/binding/presentation/bloc/binding_bloc_test.dart`(5 测——改造对象)

## 交付物
### 1. markAllPending DAO×8(ADR-2)
8 头表各加 `markAllPendingForSync()`:`UPDATE ... SET sync_state='pending' WHERE sync_state='synced'`(drift 写法照 markXSynced 家族;返回影响行数;幂等)。**guest 墓碑不动**(guest 无墓碑,注释)。SyncStateDao 或直接各 DAO——照库内惯例。单测×8(或一个文件循环)。

### 2. binding_bloc 改造(ADR-1/3)
- **守卫采集摘要**:三面守卫的计数保留(accounts.length/totalCount/holdings.length)→ `BindingServerSummary{accountCount,transactionCount,holdingCount}`;空(全 0)与非空均走 readyToUpload/readyToMerge(状态机加 readyToMerge;readyToUpload 文案语义改"上传",内部路径合一)。
- **确认事件**:`BindingMergeConfirmed`(readyToMerge 态)→ 合并链;`BindingUploadConfirmed`(readyToUpload)→ 同链(空时等价纯上传)。
- **合并链**(内联,ADR-3):
  1. `markAllPendingForSync()`×8(事务外逐表即可,幂等);
  2. 循环:`PendingCollector.collect()` → null(全空,异常态直接成功?)或 batch → `splitBatch(batch, 200)` → 逐批 `_port.push(子批)` → 每批成功:回写 synced(**版本守卫+冲突确认**——参照协调器 _writeBack;binding 层简化版:markXSynced with versionsById + 冲突实体一并标记;批 tombstone 清除)+进度 emit(`BindingProgress(i/totalBatches,已上行 N 条)`);批失败→failed(断点续传:已推批已 synced,collect 不再收)。
  3. collect 返回 null(剩余全空)→ `mirror.refreshAll()` → `markBound('bound')` → `unawaited registerDevice`(照现有容错)→ success(带摘要:上行总数/冲突数)。
- **uploadBackup 调用移除**(ADR-1:统一 push;import 保留在 lib 中不再被绑定向导调用;exporter 同)。
- 进度态:`BindingStatus.uploading` 携带 progress 字段(或新 `uploading(progress)`——照状态类形态选最小)。

### 3. binding_page UI(ADR-4)
- `readyToMerge` 卡:server 摘要(账户 N/交易 N/持仓 N)+ 合并语义说明 +「合并上传」按钮 + 确认 dialog(合并不可自动撤销+建议先本地备份[纯文案提示,不跳转]);「取消」pop。
- `readyToUpload` 卡:文案微调(「上传」,内部同链);确认 dialog 沿用/简化。
- `uploading`:批次进度文本(「第 i/N 批·已上行 N 条」)。
- success:摘要(上行 N 条·冲突 M 项[>0 提示进冲突面板]);failed 沿用可重试。
- R8 令牌;中文文案。

### 4. TDD
- DAO:markAllPending 幂等/只动 synced 行。
- bloc:readyToMerge 判定(非空摘要)/确认→markAll→批推序列(mock port 记录批次)/200 拆分(201 条→2 批)/批间失败→failed+重试只推剩余(mock 断言第二批不含首批实体)/冲突响应透传(conflicts 实体标 synced+计数)/全空直通 success/进度事件序列。
- UI widget:readyToMerge 卡渲染/确认 dialog/进度文本/success 摘要。
- **既有 5 测适配**:blocked 测试→readyToMerge;uploadBackup 相关断言→push 断言。

## 验证
新单测绿(先红后绿)+`flutter test` 全量(≥1557)+analyze 0 新增+`make client-e2e F=integration_test/app_pages_test.dart` 抽验。

## 约束
R8 令牌;中文注释/文案;不动协调器/冲突面板(F18 零改);uploadBackup 路径 lib 保留(仅向导不再调用);不 commit。完成后报告。
