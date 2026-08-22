---
feature: 2026-08-20-offline-write-integrity
status: drafted
---

# Spec — 离线写完整性(余额联动 + 引用完整 + 断网 UX)

> R6 sprint-2 收口 feature(依赖 D,E)。**D/E 累积 accepted 边界的清偿池**。
> server 语义锚点(2026-08-22 提取):①`ApplyEntryDelta`(account/domain/repository.go:27-36):**asset/expense=debit−credit;liability/equity/income=credit−debit;未知=0**;②UpdateBalances=×1,ReverseBalances=×−1(balance/updater.go);每 entry 查账户(找不到→error→**整事务回滚**)+账户 version+1;③update=Reverse 旧 entries+Update 新;delete=Reverse 旧(transaction/service.go:249-252)。

## ADDED Requirements

### Requirement: FR-1 余额联动引擎(guest 记账路径内嵌)
- [ ] Guest 态 transaction local ds 的写入路径 SHALL 内嵌余额联动镜像:recordTransaction(Simple* 经此)=UpdateBalances;update=ReverseBalances(旧)+UpdateBalances(新)同事务;delete=ReverseBalances(旧)。方向规则照抄锚点①②;账户 currentBalanceCents 与 version 随之变动。联动后:holding buy 的余额校验对**真实余额**生效;账户页余额随记账活起来。
- [ ] **联动口径迁移**:E 的 networth「冻结余额+gain 层」accepted 口径随之修正为「真实余额+gain 层」(经济上等价——转移不改净值;注释与测试同步)。

#### Scenario: 记支出联动余额
- GIVEN Guest,现金账户余额 10000
- WHEN recordExpense(5000 餐饮)
- THEN 现金账户余额=5000(asset=credit−debit 方向),version+1

#### Scenario: 删除交易反向恢复
- GIVEN 上述交易存在
- WHEN delete(该交易)
- THEN 现金账户余额恢复 10000

#### Scenario: 坏 accountId 整包回滚(D 的承诺兑现)
- GIVEN Guest
- WHEN recordTransaction 引用不存在的账户
- THEN 余额/头/子表零写入(联动查账户失败即整包回滚)

### Requirement: FR-2 引用完整性收口
- [ ] **FIFO 余量不足 SHALL 明确报错**(ValidationFailure '持仓数量不足'口径,sell 超 lot 余量时——不再静默少算);**tag junction 打标前 SHALL 校验** tag 与 transaction 存在(不存在→ServerFailure);**重复打标 SHALL 幂等**(已存在→成功无操作,记 accepted 差异——server 为 notFound 错型,幂等对单机 UX 更合理)。

### Requirement: FR-3 断网/恢复 UX
- [ ] 游客态 SHALL 全程无「网络错误」误导文案(guest 路径不触网——审计现有文案面,guest 错误均为业务语义);AppShell 顶栏 SHALL 显示在线/离线指示(消费 B 的 ConnectivityGateway,离线小徽标;Guest+在线=正常无徽标干扰)。

#### Scenario: 离线徽标
- GIVEN app 运行中在线
- WHEN 网络断开
- THEN 顶栏出现离线指示;恢复后消失

### Requirement: FR-4 启动一致性自检
- [ ] app 启动时 SHALL 对本地库做轻量自检(SQLite `PRAGMA integrity_check` + 关键表悬挂引用计数),异常 SHALL 降级为非侵入提示(横幅/banner)而非崩溃;正常时零感知。

### Requirement: FR-5 断网 CRUD 全链路 e2e(重启持久)
- [ ] 集成测试 SHALL 覆盖:内存库全链路(建账户→记账→买卖持仓→打标→预算/目标/债务)→ 关闭重开数据库 → 全部数据完好且余额/持仓/lot 状态一致。

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;分层不倒置。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server;`go test ./...` 保持全绿。

## scope boundary

- **IN**:余额联动引擎(含 update/delete 反向)+口径迁移/FIFO 报错/tag 校验幂等/断网徽标/启动自检/重启持久 e2e。
- **OUT**:绑定态镜像的余额维护(H——绑定态走远端,server 自维护)/goal currentAmount 的 scheduler 重算时机(读时三源已覆盖)/错误文案 i18n/自检的修复能力(只提示不修复)。
- **依赖**:D(transaction local ds)/E(holding/debt local ds,余额校验与 FIFO 调用点)/B(ConnectivityGateway)。

## 可行性

- **technical**:可行——方向规则纯函数照抄;联动嵌入既有 drift 事务;自检两条 pragma/查询。
- **economic**:可行——收口性质,代码集中三处。
- **operational**:可行——自检轻量(启动一次性);徽标零成本。
