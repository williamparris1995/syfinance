# F71 code-ledger

> /sydusx-execute 任务台账(task done / fix-rounds / rulings)。批次:T1→T2→T3 串行(SDD);评审由控制器另行安排,本表先落事实。

- **T1 迁移+sink 双投 ✅ done**(commit 11d1857f;`tables/agent_audit_table.dart` + `daos/agent_audit_dao.dart`(insert/count/watchPage 倒序分页)+ `domain/agent_audit_event.dart` 值类型 + `data/agent_audit_sink.dart`(port+双投 impl,fail-open 静默计数)+ executor logWrite 位改调 sink(4 参构造缝,缺省回退纯日志 = F70 行为等价)+ DI 手工注册;schemaVersion 15→**16**(执行期实证,见偏差①)。新增 16 用例:sink 3 + executor-sink 4(记账恰一行/失败重试两行/读零行/fail-open)+ event 2 + dao 4 + v16 迁移 2 + 备份排除 1(local_snapshot_exporter「agent audit rows stay out of the backup envelope」)。表不进 sync 白名单/备份镜像:显式注册制下不注册即排除,e2e 钉死)。
- **T2 查看对话框 ✅ done**(commit a07efc8e;`presentation/widgets/agent_audit_dialog.dart`(倒序/加载更多/空态/徽标,照 prototype v21)+ model_management_card 底部「操作记录」入口行(「N 条 ›」实时)+ settings_page 接线(auditDao 经 DI)。新增 13 用例:入口行实时/打开/列表渲染(相对时间三档+超前天兜底/工具 chip/千分位原样/成败徽标+原因)/加载更多 20+5/空态/关闭/纯函数/源码守门(只读零写路径)。
- **T3 审计帽石+全门+覆盖表 ✅ done**(commit 见 git log `test(assistant): F71-T3 审计帽石+全门+覆盖表`;新文件 `test/assistant/integration/agent_audit_pipeline_integration_test.dart` 4 用例 = 审计面五断言链,照 F70-T4 write_pipeline 装配范式:内存 drift 真库 + 真三写工具 registry + 脚本化 LlmStreamClient + 真 AgentLoopServiceImpl + 真 AssistantPanelBloc + 真 WriteExecutorImpl **4 参构造注入真 AgentAuditSinkImpl(真库 agentAuditDao)= DI injection 1m 生产装配形状**。全门:flutter test 全量 **3304 绿 + 1 自跳过**(F66 engine_smoke 引擎夹具不在场,与本票无关;= F70 门 3264 + F70 评审修复 7 + T1 16 + T2 13 + T3 4;test/assistant 430 绿 = 404+9+13+4)/ flutter analyze **466 == 基线零新增** / `git diff main -- yucai/server` **0 字节**;帽石测本机 4/4 首跑全绿)。零生产码改动(纯新增测试+本文档)。

## 需求覆盖对照表(T3 汇总;spec FR/NFR ↔ 测试,零 BLOCKED)

测试根 `yucai/client/test/`(T1=localdb/backup/domain/data,T2=presentation/widgets,T3=integration 帽石)。

| 需求 | 场景/SHALL | 测试文件 | 用例名(断言要点) | 判定 |
| --- | --- | --- | --- | --- |
| FR-1 agent_audit 表 | SHALL 迁移新增表(六列+索引,actor=agent 天然区分) | `core/localdb/schema_v16_migration_test.dart` + `core/localdb/agent_audit_dao_test.dart` + `core/localdb/app_database.dart`(AgentAudits 注册) + 帽石 | v16 迁移:`v15→v16 迁移:agent_audit 表+索引就位,存量数据零丢失` + `迁移幂等:重复启动无副作用,审计行不丢不重` / dao:`count:空库 0,追加后递增` + `watchPage:时间倒序(最新在前),nullable 列逐字段往返` + `watchPage 同毫秒并列:id 倒序次锚(后写先出)` / 帽石全 4 用例真链落表实证 | ✓ |
| FR-1 | Scenario 迁移幂等 | `schema_v16_migration_test.dart` | `迁移幂等:重复启动无副作用,审计行不丢不重`(v15 库升 v16 零丢 + 二次启动零副作用) | ✓ |
| FR-1 | 表不进 sync/备份(design ADR-2 排除面) | `test/backup/data/local_snapshot_exporter_test.dart` | `agent audit rows stay out of the backup envelope (F71 exclusion)`(8 模块封闭清单显式注册制,不注册即排除;备份往返不含审计) | ✓ |
| FR-2 审计双投 | Scenario 记账留痕(恰一行/实体可关联) | 帽石 + `assistant/data/write_executor_audit_sink_test.dart` + `assistant/data/agent_audit_sink_test.dart` | 帽石 `记账留痕①`:确认前表零行 → 确认后恰一行逐字段(tool/summary=WriteAction 全文/ok/reason null/entityId/idempotencyKey=卡键/createdMillis=执行时刻)+ 实体 id 真库 transactions 反查命中(午饭/2026-10-27)+ 同键二次确认仍一行(幂等零二次留痕)/ executor-sink `记账留痕:表恰一行,逐字段 + 实体 id 可关联交易` / sink `双投:日志行与 F70 直调 logWrite 逐字节一致 + 表恰一行逐字段`(日志投零变证) | ✓ |
| FR-2 | Scenario 失败也留痕(failed+原因;重试后同键两行) | 帽石 + `write_executor_audit_sink_test.dart` | 帽石 `失败重试同键两行③`:提案后真管道手删目标 → 确认 failed(transactionNotFound/reason 在/entityId null/键在)→ 同 id 还原 → 同键 RetryWriteRequested → ok 行(两行同一幂等键,追加新行非行更新)+ 重试执行面互证(交易真删/余额归位)/ executor-sink `失败也留痕:failed+原因;同键重试成功后再加一行 ok(同键异果两行)`(mock repo 触发 ServerFailure 路径,与帽石真链互补) | ✓ |
| FR-2 | Scenario 表写失败不阻断(fail-open) | `agent_audit_sink_test.dart` + `write_executor_audit_sink_test.dart` | sink `fail-open:dao 抛异常 → 不上抛 + 计数累积 + 日志行仍在`(连续失败累积,reason 不进日志行)/ executor-sink `表写失败 fail-open:记账照成 + 日志仍在 + 计数 +1`(交易真落库 + 会话注入照常) | ✓ |
| FR-2 | SHALL 读调用只留日志 | `assistant/data/audit_log_test.dart`(F70 组,logToolCall) + sink 头注契约 | 读路径不经 sink(logToolCall 留日志);write_executor_impl 仅确认执行后构造 AgentAuditEvent | ✓ |
| FR-3 查看入口 | Scenario 倒序与分页(N>页大小) | `assistant/presentation/widgets/agent_audit_dialog_test.dart` + `agent_audit_dao_test.dart` + 帽石 | dialog `首页 20/25 → 追加页 5 条 → 全量后按钮收起` + `恰一页(8 条)无加载更多,计数同显` + dao `watchPage 分页:limit+offset 窗口滑动,尾窗越界取空` / 帽石⑤(三用例尾互证):对话框数据源 watchPage(20/页)与原始 select 直查逐行同一 + count 同值 + limit+offset 窗口平铺 = 全序列零漏零重 | ✓ |
| FR-3 | Scenario 空态(非报错) | `agent_audit_dialog_test.dart` + 帽石 | dialog `空库入口显示「0 条」(不藏行)` + `「共 0 条」无确认后缀 + 两行文案,无加载更多` / 帽石 `取消零行④` 空表面互证(watchPage 空 + count 0 + 直查空 = 空态判定源) | ✓ |
| FR-3 | SHALL 卡内入口行/只读无编辑无删除/相对时间/徽标 | `agent_audit_dialog_test.dart` + `model_management_card_test.dart`(既有,auditDao 可选缝兼容) | `label + 副行文案 + 「N 条 ›」随入库实时刷新`(第 9 条入库条数跟涨)+ `标题「AI 助手 · 操作记录」+ 副行总数 + 确认后缀` + `相对时间今天/昨天/前天 + 三工具 chip + 摘要原样(千分位)+ 成败徽标与失败原因` + `✕ 关闭对话框回设置卡` + `源码静态检查:无裸色/无 AppColors/无 insertEvent/不 import sink`(只读守门) | ✓ |
| NFR-1 仅写事件 | 读操作后表零行(断言钉死) | `write_executor_audit_sink_test.dart` + 帽石④ | `读操作零行负测(NFR-1):跑一次只读工具,表零行`(非零基线对照:写 1 行 + 读一轮 → 仍 1 行)/ 帽石④ 取消零行(执行器不可达 = 零留痕;取消后补确认守卫拒仍零行) | ✓ |
| NFR-2 server 零改动 | git diff yucai/server 为空 | 非测试:全门 | `git diff main -- yucai/server` **0 字节** + server 子目录 status 干净(T1/T2/T3 每票全门复测通过) | ✓ |

> 漏项检查:spec ADDED 5 条需求(FR-1..3 + NFR-1..2)全部有对应测试/门,**零 BLOCKED**;FR-1 Scenario 文案的「v15 迁移」已随执行期实证订正为 v16(2510c3e2,见偏差①,非缺口)。

## 执行期偏差记档(T1-T3 沉淀)

1. **v15→v16 实证**:task-brief-1 预估「v14→v15」,执行期发现 v15 已被同日银行对账计划表占用(`schema_v15_migration_test.dart` 在库,schemaVersion 现值 15 非 14)—— 实际迁移 = schemaVersion 15→**16**(agent_audit 即 v16 迁移,`_createIndexIfAbsent` 守卫建索引)。spec 已于 2510c3e2 订正(FR-1 标题/场景文案 v15→v16),非静默偏差;v14 存量库升级语义由既有逐版迁移链承接(v15 迁移幂等先例同款)。
2. **`_createIndexIfAbsent` 新家法**:F71 是全库首个「迁移建索引」的迁移(此前迁移只 createTable/addColumn,`@TableIndex` 生成物随建表走)。既有迁移测试伪造旧库只回拨 user_version 不清库,重放迁移会撞 duplicate index(SQLite 索引名库级唯一)→ `app_database.dart` 新守卫 `_createIndexIfAbsent(Index)`(存在性探测后建)。**后续凡迁移侧建索引必走此守卫**(v16 迁移与 schema_v16_migration_test 幂等用例均实证;表头注同步记档)。
3. **入口行卡底部 + 超前天日期兜底差异(相对 v21 原型)**:① 入口行:v21 原型为独立演示块,实现按拍板形态挂 model_management_card **底部**(「数据与隐私」行之下;`auditDao` 为 null 时整行隐藏 = 旧装配/旧测试兼容缝);② 相对时间:v21 演示只到「前天」,实现更早日期补完整日期 `yyyy-MM-dd HH:mm` 兜底(纯日期比较 = 两侧各折 `DateTime.utc` 日历日差天数,零时区/夏令时运算;跨零点当日仍「今天」)。dialog 测超前天/跨零点/跨月跨年三用例钉死。
4. **dialog watch Timer 烧毁测试基建家法**:drift `QueryStream.markAsClosed`(树卸载时订阅 cancel)挂零长 Timer,而 `pump()` 缺省不推进 fake 时钟 → 框架收尾 `!timersPending` 断言炸(与组件逻辑无关)。**家法:凡挂订阅型 drift watch 组件的 widget 用例,末尾必调 `_pumpDownTree`**(`pumpWidget(SizedBox.shrink)` + `pump(16ms)` 烧掉残留 Timer;AppToast Timer 先例的 drift 变体,agent_audit_dialog_test.dart 头注记档)。

## T3 装具要点(记档)

- **双帽石并存互不扰动**:F70-T4 `write_pipeline_integration_test`(executor 3 参构造,缺省回退 `_LogOnlyAuditSink` 纯日志 = F70 行为等价证)与本票 `agent_audit_pipeline_integration_test`(4 参构造注入真 `AgentAuditSinkImpl`,= DI injection 1m 生产装配形状)各钉一条路径;两文件同范式不同缝,回归面互补。
- **失败重试两行的真链触发(零 mock)**:不 mock repo —— 提案后经真管道手删目标(`TransactionLocalDataSource.delete`,表单同款级联)→ 确认撞 executor 文档化失败路径 `transactionNotFound`;同 id 还原(头+分录 `toCompanion` 原样回插 + `BalanceLocalUpdater.applyEntries(+1)` 同向回摆,包在 drift transaction 内)→ 同键 `RetryWriteRequested` 成功。失败不耗键 = 表**追加新行**非行更新,同键异果两行;余额三摆(扣/回摆/回摆+重删)归位 = 同管道互证。
- **DAO 直查互证**:表断言双路(`AgentAuditDao` 读面 + 原始 `select(agentAudits)` 直查,与 DAO 实现独立);对话框数据源(watchPage 20/页)与直查表逐行同一 + count 同值 + limit+offset 窗口平铺零漏零重 —— 对话框所见即表所存(T2 widget 测的读面在链路级再钉)。
- **审计面 = F70 写链语义的投影**:幂等(同键二次确认零二次留痕)/取消(执行器不可达零留痕)/失败(不耗键,重试同键追加)三条 F70 语义在 agent_audit 表上的可观测面,帽石①③④分别钉死;entityId 反查关联(成功行可查回交易,delete 行实体不在库 = 表为删除后唯一回溯点)。
