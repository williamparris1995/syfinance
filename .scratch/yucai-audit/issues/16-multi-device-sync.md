# 16 · 多设备同步(重开决策)

Type: research
Status: open
Blocked by: 12

## Question

memory 记录 2026-07-25 cancelled(理由:server+Postgres 已持久化、client 直连)。但审计发现家庭多设备/出差/手机记账/夫妻并发编辑需求客观存在(详见 `findings.md` G14 + U3)。用户决定纳入本 map 为决策 ticket。

架构上 server 本就是天然数据汇聚点(Postgres 单源真相),实际等同"局域网/内网多设备同步"。但以下场景未覆盖:
- 夫妻各一台 PC 同时连同一 server → 并发编辑冲突
- 出差离线编辑 → 重连同步
- 移动端(手机记账)尚未覆盖

**研究 + 决策点:**
1. 现状(server 单源 + client 直连)在"家庭局域网多设备"标尺下是否已足够?哪些场景是真 gap?
2. 并发编辑冲突:当前 ent 无乐观锁(见 05 的 version 装饰性问题),多用户并发写如何处理?operational transformation / last-write-wins / 字段级 merge?
3. 移动端:Flutter mobile(手机记账)是否纳入产品范围?offline + 重连同步方案?
4. 是否复用已存在的 sync 模块 schema(SyncLog/SyncConflict/SyncDevice)?它当前状态(server-to-server?client 端无 counterpart)?
5. 重开 vs 保持 cancelled vs 部分(只做并发控制不做离线)的成本/收益?

注:深度依赖 12 的 offline 策略决策,故 Blocked by 12。本 ticket 先 research 调研方案,再据结论决定是否升级为实施 ticket。

## Research findings(2026-07-26)

调研完成,详见 [`research/multi-device-sync.md`](../research/multi-device-sync.md)(~13KB,60+ 信源)。

**超预期发现**:御财 sync 模块**非 memory 所说"schema 空"**,而是"服务端 80% 就位、客户端 0%"的半成品 —— ent schema(SyncLog/SyncConflict/SyncDevice)+ domain + application(6 方法)+ repo + gRPC handler + proto + Dart stub + wire 注入全有,但**无 `client/lib/sync/` 目录,无人调用 stub**。

**服务端 7 处硬伤**(任何方案都要先修):
1. `PushChanges` **从不调用 `DetectConflict`**(注入的 resolver 是死代码,conflicts 永远 nil)
2. 版本号分配**非原子**(LatestVersion+1+Append 三步分离,并发撞号)
3. **不写真实业务表**(只 append sync_log,客户端推上来的变更服务端看不到)
4. `GetSyncStatus` **用 tenantID 当 deviceID**(注释明写 "placeholder")
5. `mapError` 全部塌缩 `codes.Internal`
6. `ConflictResolver.Resolve` 硬编码 server-wins(无字段级合并)
7. 业务表 ent schema **无乐观锁 version 字段**(关联 05)

**推荐 Option A(复用 scaffolding)**:保留现有 8 个 server 文件 + 修 4 项 P0 + ent 加 version + 自建 client 四层(Drift `pending_changes` queue + cache + SyncCubit + IndicatorWidget + ConflictListPage),3-5 周。同步策略:server 权威 + 乐观锁 + 字段分类冲突(**金额永不静默合并**)。
- Option B(PowerSync/ElectricSQL):工时相近但丢 scaffolding + 外部依赖,与"client 直连无中间服务"哲学冲突。**不推荐**。
- Option C(全 CRDT,Actual Budget-style):2-3 个月,**破坏 transaction 双账不变量**(message 独立到达 → 借贷可能暂时不平),家庭稀疏编辑无收益。**不推荐**。

关键信源:Actual Budget CRDT 内部机制(James Long "Using CRDTs in the Wild",字段级 LWW + HLC + Merkle,作者承认无法保证跨字段不变量 → 对御财双账是硬伤);Transactional Outbox(microservices.io);乐观锁+悲观锁混合(Modern Treasury)。

→ 决策待用户拍板:重开 Option A / 保持 cancelled / 仅做并发控制(乐观锁,见 05)不做离线。
