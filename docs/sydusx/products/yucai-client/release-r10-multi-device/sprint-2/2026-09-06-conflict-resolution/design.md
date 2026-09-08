# Design — F18 冲突解决

> R10 sprint-2 · 2026-09-06。spec 四决策内嵌推荐;查证事实为输入。

## ADRs

- **ADR-1 触达=双层修复**:client port `encodeRequest` 按 `dto.version==1 → CREATE else UPDATE`(collector 的 version 来自 drift 行,本地首建恒 v1、编辑 bump——语义注释);server 检测改统一存在性检测(不再按 op 分流):`CurrentState.exists` → 字节比对 payload(相同→静默 skip,不耗版本不写 log——幂等重推语义收紧)→ 不同且 `probe.Version<=server.version` → 冲突;`probe.Version>server.version` → 落库。CREATE(server 无该 id)→ 落库。DELETE 不变(不检测)。
- **ADR-2 确认语义**:PushChanges 响应的 conflicts → client writeBack 阶段把对应 entityId 标 synced(markXSynced 复用,版本守卫同款);SyncConflictInfo 扩 `conflictId/module/entityId/conflictType/serverPayload/clientPayload/createdAt`;协调器 state 增 `conflicts: List<SyncConflictInfo>`(完整保留,clean 态携带)。
- **ADR-3 解决落库**:service.ResolveConflict 增 `payload []byte` 参数(handler 读 merged_payload 透传);`client`→payload=conflict 行 client_payload(忽略 merged 参数);`merged`→payload=merged_payload(空→InvalidArgument);`server`→无 payload。client/merged:sqltx{writer.Upsert(payload)+logRepo.Append(该实体 entityType/entityId,log version=LatestVersion+1,operation=UPDATE)}——B pull 收敛通路。【T1 实现修订(review fix round 1):log version 取 LatestVersion+1 而非初稿的"payload 内 Version"——sync_log.version 是每租户 pull 游标且有 (tenant_id,version) 唯一索引,实体版本既会撞索引(client-wins 的 v1 与既有 log v1 冲突)也低于游标永不被 pull;payload 自身实体版本仍经 writer 落业务行】
- **ADR-4 applier 版本感知**:下行 upsert 前读本地行——存在且 pending 且 `local.version >= pulled.version` → skip;`local.version < pulled.version` → 应用(pending 保护升级为版本比较;本地非 pending(synced)照常 insertOnConflictUpdate);DELETE 照旧不问版本。per-change try/catch:坏条目(debugPrint+跳过)不阻批、不回滚整事务——**事务粒度改为 per-change**(整批原子性降级注释论证:下行是幂等重放,单条失败不再钉死全局;毒丸吸收)。
- **ADR-5 面板**:`ConflictPanelPage`(bind-only 路由 `/settings/conflicts`);数据=bloc(`ConflictListBloc`:Load/Resolve/分页,port.listConflicts);条目卡:模块徽章+摘要行(server/client 双栏关键字段——`ConflictFieldFormatter`(新,per-module 从 payload JSON 抽 2-3 关键字段[名称/金额/日期],复用 envelope 键知识);操作按钮=保留服务端(server)/保留我的(client);解决→port.resolveConflict→刷新;badge 扩展 amber 冲突 chip(conflictCount>0 且非 syncing/failed;onTap→面板)。
- **ADR-6 port 扩展**:`OfflineSyncPort` 增 `listConflicts({pageToken}) → ConflictPage{items,totalCount,nextToken}` 与 `resolveConflict(conflictId,resolution,{mergedPayload})`;Grpc 实现真调;Noop 空实现(测试默认)。
- **ADR-7 FindPending 修缮**:`ORDER BY created_at DESC, id DESC` + keyset(cursor=末条 (created_at,id),查询 `OR(created_at<, id< AND created_at<=)` 形态——SQLite/PG 兼容元组比较写法,实现时验证);proto ConflictDTO 加 `google.protobuf.Timestamp created_at = 8`(非破坏,server 映射)。

## HLD 改动面

- server:service(检测统一/解决落库/pull applier 无关)、repo(FindPending 修缮)、handler(merged 透传/created_at 映射)、conflict.go 删、proto(+created_at,regen Go;Dart regen 同步)
- client:port(区分 op+两新方法+DTO 扩展)、coordinator(确认标记+完整列表)、applier(版本感知+per-change)、ConflictListBloc+ConflictPanelPage+ConflictFieldFormatter(新)、badge 扩展、router
- e2e:fake 三能力(conflicts 可编程响应/listConflicts 真 backlog/resolveConflict 记录)+双设备冲突全链测试

## Risks

| 风险 | 缓解 |
|---|---|
| 检测规则变化破坏单设备测试(幂等重推语义) | FR-1 测试语义更新清单在案;F13 契约 e2e(全新 id 全 CREATE 不受扰) |
| per-change 事务降级的部分应用 | 下行幂等重放论证+重拉自愈;e2e 钉 |
| applier 版本感知误覆盖未上行编辑 | 严格 `<` 才应用;单设备不变式注释+测试 |
| proto regen(F13 手补丁/F17 警示) | regen 后 diff 面断言+手补丁重套流程照走 |

## Open Questions

无(实现自由度已授权;元组 keyset 兼容性实现时验证)。
