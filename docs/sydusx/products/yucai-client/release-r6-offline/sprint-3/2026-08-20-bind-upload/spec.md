---
feature: 2026-08-20-bind-upload
status: confirmed
---

# Spec — 绑定上传(空账号 guard + 本地快照上云 + 回切在线)

> R6 sprint-3 feature G。**wire 事实修正(2026-08-23 analysis)**:backup 服务为「服务端自管存储」模型——CreateBackup(encrypted?,password?) 由 server 从自身 DB 导出,RestoreBackup(backup_id,password) 从备份存储恢复,**无任何 RPC 接受客户端数据**。R6 立项时「经现有 RestoreBackup 单向上传」的假设在 wire 层不成立(release.md 已定决策需同步修订,见下)。
> 佐证:业务 CRUD 的 server 侧 NewAccount 等自产 UUID(不接受 caller ID)→ CRUD 逐条上传需跨 8 模块的 ID 映射重写;backup Service 的 ports/purge+import 基建(R5 D6 加固)齐备,仅缺接受 envelope 字节的 driving 入口。

## 通路决策(已裁定 2026-08-23:选 B)

- **选项 A:CRUD 逐条上传(维持零 server)**——绑定后逐模块调业务 Create RPC。代价:①server 自产 ID → 本地需维护 UUID→serverID 映射并**重写全部跨模块外键**(entries.accountId/budget_items/goal links/holding/debt schedule/template 账户引用/余额联动交易),8 模块×两种 ID 空间的映射引擎,复杂且脆弱;②数百条 RPC 的部分失败恢复(重试幂等)复杂;③transaction_tag 联结也须逐条(且 backup 契约不含它,server 端仍会丢)。
- **选项 B(推荐):server 增一个上传 RPC**——`UploadBackup(bytes envelope, optional password)`:driving 层新入口 → 校验/解密 → **复用现有 R5 D6 加固的 purge+import 原子路径**(orderedPortsForPurge/Import + sqltx.WithTx + 快照安全备份)。R6 立项时「零 server」的理由(避免撞 R5 在途 D6)**已消失**(R5 已 merge);client 侧一个 RPC 单向上传,绑定语义与原 spec 完全一致;server 改动面小(proto 一字段+handler+service 方法+测试)。代价:破「零 server」约束,server 侧约 +1 RPC 面。

## ADDED Requirements

### Requirement: FR-1 本地快照导出(drift → BackupEnvelope)
- [ ] client SHALL 能将本地 drift 全量导出为 server BackupEnvelope 格态:`{version:1, tenant_id:绑定账号 tenant, created_at, modules:{"account":...,...}}`——8 契约模块(account/transaction/debt/budget/goal/holding/tag/template),逐模块 JSON 与 server exporter 输出**同构**(PascalCase key、int 枚举、RFC3339Nano、金额 int64 分;转换规则 5 条逆向:嵌套聚合/goal uuid 数组/tenant 注入;**不含** currency/security 等引用数据与 transaction_tag[契约不含,accepted R1])。
- [ ] 导出 SHALL 幂等只读(不动本地库)。

### Requirement: FR-2 空账号 guard(M3)
- [ ] 绑定流程在登录成功后、上传前 SHALL 预检远端账号为空:调用远端 list(accounts + transactions + holdings 摘要);任一非空 → **阻止上传**并明示(该账号已有数据;合并流程 defer;用户可换账号或放弃)。

### Requirement: FR-3 单向上传与绑定状态机
- [ ] 绑定流程 SHALL 按 状态机推进:`guest →(登录成功)→ guard →(空)→ uploading(进度/可取消)→(成功)→ bound`;任一步失败 → 回到可重试态,本地数据不受影响(单向性)。上传采用**通路决策裁定的机制**(A:CRUD 映射引擎/B:UploadBackup RPC——见决策节)。
- [ ] 成功后 SHALL 验证:远端 list 条目数/关键实体抽查与本地一致;`SessionModeTracker.isGuest=false`(AuthBloc Authenticated 已驱动)自动回切在线模式;本地 drift 数据**保留不动**(H 镜像起点)。

#### Scenario: 断网记账后绑定上云(成功判据②)
- GIVEN Guest 本地有账户/交易/持仓数据
- WHEN 设置页登录(guard 空)→ 上传成功
- THEN server 端出现全部数据(条目比对一致),app 回切在线模式,本地库保留

#### Scenario: 非空账号被 guard 阻止
- GIVEN 登录的账号已有服务端数据
- WHEN 触发绑定
- THEN 明确阻止提示,零上传,可换账号/放弃

#### Scenario: 上传中途断网可重试
- GIVEN uploading 中网络断开失败
- THEN 状态回退可重试;本地数据完好;重试成功路径闭环

### Requirement: FR-4 绑定向导 UI
- [ ] 设置页(Guest 态)现有「登录账号」入口登录成功后,若本地存在业务数据 SHALL 引导进入绑定向导(guard → 上传 → 完成反馈);本地为空则直接进入在线模式(无向导)。向导各步进度/失败/重试可见。

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;分层不倒置;若裁定 B,server `go test ./...` 全绿 + 新 RPC 有单测。

### Requirement: NFR-2 server 改动面(裁定 B)
- [ ] server 改动 SHALL 限定在 backup 模块:proto +`UploadBackup(bytes data, string password)` 一字段 + handler + Service.UploadExternal(解析 envelope→**tenant_id 以鉴权身份覆盖**(防跨租户注入)→复用 R5 D6 purge+import 原子路径含 safety 快照) + 单测;业务模块零改动;`go test ./...` 全绿。R6 release「v1 零 server」条目同步修订为「除 feature G 的 backup 上传 RPC 外零 server」。

## scope boundary

- **IN**:导出器(8 模块逆向映射)/guard/绑定状态机与向导 UI/上传通路(按裁定)/成功验证/回切。
- **OUT**:非空账号合并(defer)/绑定后镜像写穿透(H)/绑定后离线续写(ticket 16)/transaction_tag 上云(契约不含,accepted R1 维持)/导出文件落盘与加密存档(J 复用导出器时补)。
- **依赖**:sprint-1/2 全部(drift 数据面/Guest/联动);B 的设置页登录入口。

## 可行性

- **technical**:A 可行但映射引擎复杂脆弱;B 可行且复用 R5 加固(推荐)。
- **economic**:B 的 server 面小;A 的映射引擎是持续维护债。
- **operational**:B 单 RPC 原子上传,运维面最小。
