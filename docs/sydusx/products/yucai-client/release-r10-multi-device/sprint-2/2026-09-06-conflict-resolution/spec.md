# Spec — F18 冲突解决

> R10 sprint-2 · 2026-09-06 · analysis 产出(查证含阻断级发现)。

## 查证事实基线(设计输入)

- **阻断**:client 恒发 CREATE(port:128-129)× server 只检 UPDATE(service.go:328-331)→ 检测不可达,多设备互推=静默 LWW 覆盖。
- ResolveConflict 纯标记:client-wins 不落库、merged_payload 全链无人消费、解决不写 log(B 永不感知)。
- ListConflicts 链路通但 FindPending 无 ORDER BY+IDGTE 边界重复;ConflictDTO 无时间戳。
- client SyncConflictInfo 无 conflictID/双 payload;协调器只留计数;无 ListConflicts 调用。
- applier pending 保护是"一刀切跳过"——server 已裁决的更高版本也进不来(B 不收敛);毒丸条目钉死游标。
- F16 遗留:同 payload 良性冲突(无短路);conflict.go 死代码。

## Requirements

- **FR-1 冲突触达修复(阻断级)**:client port 按 SyncEntityDto 区分——`version==1`(该行从未被同步过)发 CREATE,否则 UPDATE;server 检测统一规则:**实体在 server 存在时,任意 operation**:payload 相同(**canonical 规范形比对**[T1 review fix round 1 修订:入站 payload 经 writer Canonicalize 盖 tenant 后与 server 规范形比对——Dart 线形键序/无 TenantID 不再影响等价判定])→ 静默跳过(幂等重推,**不记冲突不耗版本不写 log**——顺带落地 F16 的同 payload 短路);payload 不同且 `client.version <= server.version` → 冲突(跳过+记录+响应);`client.version > server.version` → 正常落库。单设备幂等重推测试语义更新(重推不再追加 log)。
- **FR-2 client 冲突确认**:push 响应 conflicts 中的实体 → 本地**标记 synced**(内容已保存在 server 冲突记录,解决时裁决;防反复重推堆冲突);协调器保留完整 `List<SyncConflictInfo>`(扩展 conflictId+双 payload+时间戳[proto 加 created_at,非破坏])。
- **FR-3 ResolveConflict 落库语义**:`server` → 仅标记(server 行已权威);`client` → writer.Upsert(client_payload)+写 log(同 sqltx);`merged` → Upsert(merged_payload)+写 log。解决后冲突行 resolved,B 经 pull 收敛(见 FR-4)。
- **FR-4 applier 版本感知 pending 规则**(替换一刀切):下行变更 `pulled.version > 本地 pending 行.version` → **应用**(server 已裁决/他设备更新胜出,本地 pending 内容已在冲突记录或已过时);`<=` → 跳过保 pending。单设备不变式保持(server 不可能有本地 pending 行的更新版本)。**毒丸复议**:per-change try/catch(坏条目记 log 跳过,游标前进,不再钉死)。
- **FR-5 client 冲突面板**:badge 扩展——`conflictCount>0` 且非 failed → amber chip「冲突 N」onTap 进面板;面板(路由 `/settings/conflicts`,bind-only):ListConflicts 分页列表;每条=模块徽章+实体摘要(双 payload 按模块解码关键字段对照:服务端版本 vs 我的版本);操作:**保留服务端 / 保留我的** 二选一(v1 不做 merged 编辑器,proto/API 保留 merged 通道);解决后面板刷新+badge 计数经 ListConflicts 重取。
- **FR-6 ListConflicts 修缮**:ORDER BY created_at DESC,id + keyset 修复(边界重复);ConflictDTO proto 加 `created_at`(非破坏)。
- **FR-7 吸收项**:conflict.go 死代码删除(Resolver/DetectConflict);GetSyncStatus client 消费不做(YAGNI,面板计数走 ListConflicts totalCount)。
- **FR-8 测试与门**:server(触达修复全矩阵/短路/解决落库+log/分页修复);client(port 区分 CREATE/UPDATE/确认标记/面板 widget/协调器完整列表);e2e fake 扩展(conflicts 可编程+listConflicts/resolveConflict 实现)——**双设备冲突全链 e2e**(A、B 分歧→B push 冲突→面板解决→A pull 收敛);全部门零回归。

## NFR

单设备零回归(检测规则对单设备:重推短路=行为变化但终态等价——测试语义更新注释论证);中文注释(client)/英文(server);R8 令牌(UI)。

## Scope boundary

| 排除 | 理由 |
|---|---|
| merged 编辑器 UI(字段级合并界面) | v1 二选一;proto/API 通道保留,编辑器=sprint-2 后 backlog |
| 自动解决策略(LWW auto) | 用户定"显式化"方向 |
| 冲突批量操作 | YAGNI |

## Grill record

| 决策 | 定案 |
|---|---|
| 冲突处理模式 | R10 分解已定:显式面板(非 auto LWW) |
| v1 解决操作 | 二选一(server/client),merged 通道保留无 UI——技术推荐 |
| 触达修复方式 | client 区分 CREATE/UPDATE + server 存在性统一检测(含同 payload 短路)——技术推荐(修复阻断+F16 遗留一并落地) |
| pending 下行规则 | 版本感知(>应用/≤跳过)——技术推荐(多设备收敛必需,单设备不变式保持) |

## Feasibility

technical ✓(查证:全链骨架在,proto 字段就位,解码先例现成);economic ✓;operational ✓(fake e2e 可编程双设备冲突)。
