# Release — R6 御财 Client Offline-First 本地模式

> Release Goal + sprint roster + done-criteria。由 `/sydusx-portfolio` 分解(2026-08-20)。
> 决策溯源:本 release 经 clarify→approach→grill 收敛(2026-08-20,方案 A);背景调研 [.scratch/yucai-audit/research/multi-device-sync.md](../../../../../.scratch/yucai-audit/research/multi-device-sync.md)。
> 编号延续统一里程碑序列(R1-R4 统一,R5 归 server 审计整改,R6 归 client)。

## Release Goal

御财客户端**无账号单机可用**:断网全新安装即可记账理财;绑定 Google 账号后本地数据单向上传服务端(云备份);不绑定则永远本地运行。服务 [vision](../vision.md) 终态「可分发的商业级个人理财应用」——可分发的前提是不依赖自建 server。

## 已定决策(approach A,grill 收敛)

- drift 为**未绑定态主存储**(可读可写);绑定后回切 server 权威在线模式。
- 启动鉴权分流:`NetworkFailure ≠ Unauthenticated`,所有用户离线不被踢登录页;游客模式路由放开。
- 绑定=OIDC 登录 → **空账号预检 guard**(非空阻止,合并 defer)→ 本地快照经现有 `RestoreBackup` 路径单向上传 → 回切在线。
- 绑定后本地 drift 作**镜像持续写入**(写穿透);登出=回本地模式用最后镜像(M2)。
- 绑定后离线**续写** defer ticket 16(M1:绑定后离线=现状降级,矛盾显式接受)。
- **硬约束:v1 零 server 代码改动**(避免撞 R5 在途的 D6 区域;若必须动 server,等 R5 merge 后走 fast-lane)。
- 双 schema 漂移(G1):drift↔ent 以 backup 格式/proto DTO 为唯一契约;模式切换 seam(G2)为 LLD 决策。

## Scope

### IN
| 领域 | 内容 |
|---|---|
| 本地库 | drift schema 覆盖全部业务实体 + DI 注册 + proto DTO 契约对齐 |
| 鉴权 | AppStarted 失败分流(NetworkFailure/AuthFailure)+ 游客模式 + 路由守卫放开 |
| 双源改造 | 19 模块 repository 本地/远端双源(渐进:seam 试点 → 全模块) |
| 绑定上传 | 空账号 guard + RestoreBackup 单向上传 + 回切在线 |
| 镜像 | 绑定后写穿透镜像 + 登出回本地 |
| 验收 | 三条成功判据 e2e |

### OUT(留后续 release)
- **绑定后离线续写 / 多设备同步** — ticket 16(sync engine:client UUID + 乐观锁 + server sync 8 硬伤修复,即被拒方案 B)。
- **非空账号绑定合并** — v1 只允许空账号首绑,合并流程 defer。
- **任何 server 代码改动** — v1 硬约束;必要时 R5 merge 后 fast-lane。
- **i18n 阶段二** — 不在本 release(ADR-006 不变)。
- **实时行情/收益引擎离线化** — Yahoo 依赖天然在线,离线时展示最后快照。

## Sprint roster

> sprint 分组提案(依赖排序,可调)。

- [x] **sprint-1**:本地模式地基(drift schema + 鉴权分流 + 双源 seam 试点)✅ done(2026-08-22)
- [x] **sprint-2**:全模块本地读写(核心记账 + 资产类 + 写完整性)✅ done(2026-08-23)
- [ ] **sprint-3**:绑定上传 + 镜像 + e2e 验收

## Done-criteria(release gate)

- 三条成功判据 e2e 全过:①断网全新安装、无账号 → 可启动并记账/看资产;②登录 → 本地数据出现在服务端;③从不绑定 → 数据一直本地、app 一直可用。
- 各 feature 过 `sydusx-review` + `sydusx-test` gate(DoD:conventions + ai-harness invariants + acceptance + coverage)。
- `flutter test` 基线不退化(≤ 3 fail/2 文件)+ `flutter analyze` 不新增(`*.pbserver` 基线外)。
- `go test ./...` 全绿(server 零改动,不应受影响)。
- vision 近期豁免的「离线能力」条目解除(已随本 release 立项更新 vision)。

## status: pending
