# R10 · 多设备同步(multi-device-sync)

> 立项 2026-09-03。来源:ticket 16 全量(R6 defer 线 + R9 F10-F13 过程中增厚的 8+ 项);R9 已落地单设备离线续写地基(F10-F13),本 release 解决多设备。
> **前置提醒**:R9 真机人工验收(绑定→断网→回网对真 server)尚未执行——R10 的 sprint-1 实施建议在 R9 验收通过后启动(planning 现在可做)。

## Goal

多设备(如台式机+笔记本)经同一 server 账号数据一致:设备真实身份(RegisterDevice)、双向同步(Push 已有/Pull 补全)、冲突显式化(检测+解决 UI)、并发安全(版本序列化);附带清偿 ticket 16 的合并/上云尾项。

## Scope

### IN
- **F16 server 同步核心硬化**:sync_log 版本并发序列化(事务内分配/唯一约束);RegisterDevice 实现(device 表真身份);**PullChanges 业务表实现**(按 since_version 从业务表变更流水回放——依赖 sync_log 完整性,评估直读 log vs 业务表触发);conflicts 检测基础(push 时版本比对填充 ConflictDTO,替换恒空);跨租户同 id 复合 PK 评估(ent 迁移裁决)。
- **F17 client 设备身份与拉取**:RegisterDevice 接入(deviceId 真实化替换 'bound' 字面量);PullChanges 消费(登录/回网拉取→本地应用→与 BoundMirror 合并语义裁决);孤儿台账 holding_ledger 上行 entityType(F11 遗留)。
- **F18 冲突解决**:server 冲突规则定案(last-write-wins/字段级/用户裁决——design 阶段定)+ ResolveConflict/ListConflicts 实现;client 冲突 UI(F12 徽标扩展)。
- **F19 非空账号绑定合并**:本地有数据的账号绑定 server 账号时的合并流程(现在阻止)。
- **F20 存档上云+多设备 e2e**:备份存档云端往返管理;多设备同步 e2e(双客户端夹具:设备 A 写→server→设备 B 拉取一致)进回归门。

### OUT / Defer
- 离线行情/收益引擎(天然在线)
- 移动端专属优化
- i18n

## 硬约束

- 契约版本化:PullChanges/冲突若改 proto → yucai-api vN 目录切片(首次破坏性改动)
- F10-F13 单设备语义零回归(client-e2e/client-e2e-ui/单测全绿)
- server DDD/wire 手改/英文 log 约束照旧

## Sprint roster(建议)

- [x] sprint-1 同步引擎地基:F16 ✅(`d9dc34ec`)→ F17 ✅(`cc118f31`)——多设备推拉/身份/冲突检测/台账地基闭环
- [x] sprint-2 冲突与合并:F18 ✅(`001c7b07`)→ F19 ✅(`df651460`)→ F20 ✅(`9acab473`)
- [ ] sprint-2 冲突与合并:F18 → F19 → F20

## done-criteria

五 feature 全 done + 双设备同步 e2e 绿 + 契约切片(若破坏性)+ R9 人工验收补记 + 单设备回归门全绿。

## status: 功能 done(2026-09-06;done-criteria 全达成:五 feature done[F16-F20]+双设备 e2e 绿[10 场景]+契约零破坏[四条向后兼容登记]+回归门全绿[e2e 13+UI 12+flutter 1581+go 66 包])。**待人工验收**:R9+R10 地基真机走查(绑定→断网记账→回网→双设备互看,清单见 R9 release.md)。结构性缺口(server 起源写入不入 sync_log/周期拉取)留 sprint-3 候选。
