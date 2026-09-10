# Design — F19 非空账号绑定合并

> R10 sprint-2 · 2026-09-06。查证:合并=sync push+镜像拉回;两缺口=全量标记+批拆分。

## ADRs

- **ADR-1 统一合并路径**:绑定向导去掉 readyToUpload/uploadBackup 分支——**空与非空统一走合并 push**(空时合并=纯上传,语义等价但少一路径+少一次 envelope 导出;uploadBackup RPC 留在库中作 F20 cloud 恢复通道评估,绑定向导不再调用)。守卫改为"数据摘要采集"(非空→readyToMerge 带计数;空→readyToUpload 文案改"上传"(内部同 merge 路径)或直接同态——**实现:两态文案区分,代码路径合一**)。
- **ADR-2 全量标记**:`SyncStateDao.markAllPendingForSync()`(或各 DAO 加 markAllPending;8 头表单 SQL UPDATE syncState='pending' WHERE syncState='synced';幂等;guest 墓碑不动——guest 无墓碑)。合并确认后执行。
- **ADR-3 批次拆分**:binding bloc 合并执行链:`markAllPending → collect(现 PendingCollector 全量)→ 按 200 条拆 SyncPayload → 逐批 OfflineSyncPort.push(批 = tombstones+entities 混合切;每批后 writeBack 语义由协调器复用或内联)→ 全部完成 mirror.refreshAll → markBound → registerDevice`。批间失败→failed 态(已推批次已 synced,重试只推剩余 pending——**自然断点续传**:收集器只收 pending,重试幂等)。进度事件 `BindingProgress(batch i/N)`。
- **ADR-4 UI**:readyToMerge 卡(摘要+合并按钮+确认 dialog 含"建议先本地备份"提示);uploading 态显示批次进度;其余态沿用。冲突后置 badge 自然出现(零接线)。
- **ADR-5 测试**:bloc 单测(mock port 记批序列/断点续传/冲突响应透传);批拆分纯函数单测;e2e fake 预置 server 行(模拟已有数据)+合并全链(推→并集→冲突场景)。

## HLD 改动面

`binding_bloc`(状态机扩展+合并链)/`binding_page`(readyToMerge+进度)/`core/localdb`(markAllPending DAO×8)/`offline_sync_port` 或协调器(批推 API——binding 层内联循环即可,不动协调器)/测试×3+e2e。

## Risks

| 风险 | 缓解 |
|---|---|
| 大量级首次合并慢(几千笔×批) | 200/批+进度;个人量级分钟级可接受 |
| 中途失败状态 | 断点续传(收集器只收 pending)+failed 可重试 |
| 空账号绑定行为变化 | 等价论证(纯上传)+既有测试语义更新 |

## Open Questions

无。
