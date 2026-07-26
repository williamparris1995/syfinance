# 御财行业规范审计 · 发现汇总(findings)

2026-07-26 · 标尺:家庭多用户(私域) · 6 维度并行只读 agent 审计。
格式:`[ID] [P级] 问题 — 位置 — 决策问题`。建 ticket 时按主题归组(见 map.md)。

---

## 维度 1 · 财务计算正确性(ac39)

- [F1][P0] 多币种换算汇率基数约定错:ConvertToBase 公式假 CNY-base(rate[CNY]=1.0),Frankfurter 落库 EUR-base(rate[USD]=1.08=1EUR兑1.08USD),seed 同 EUR-base → 生产 USD→CNY 错~52倍且方向乘反;unit test 用 CNY-base mock 永远绿掩盖 — `currency/domain/convert.go:9-14` + `adapter/driven/exchangerate/frankfurter.go:33-69` + `application/service.go:98-161`;影响 networth/holding/budget 全跨币种聚合 — 决策:SyncRates 落库前重基 CNY-base vs 改公式 amount×rateBase/rateFrom;补 Frankfurter 真实样本→ConvertToBase 端到端断言测试
- [F2][P0] portfolioCAGR 全期方法论 bug:initial=currentCostBasisInBase(当前头寸,卖出后缩减)配 days=earliestHoldingCreated→now(含已清仓最早日),换仓后年化失真 — `holding/application/service.go:1582-1600`;是 memory P1-6 真实根因 — 决策:initial 改 earliest 时点成本 vs days 改"当前头寸最早建仓日",使两者同源
- [F3][P1] XIRR 收敛阈值绝对值 1e-7,大额组合(1e8 cents)NPV 浮点噪声>阈值永不收敛→bisection→ErrNoSolution→静默 nil — `holding/domain/xirr.go:74,101` — 决策:改相对收敛 `|f|<1e-7*sumAbsCF`
- [F4][P1] XIRR bracket 硬编码[-0.9999,1000],短日暴利(年化>1000)漏解 — `xirr.go:92` — 决策:扩上界到1e6/自适应+Newton 阻尼
- [F5][P1] Buy/SellHolding AmountCents=int64(float64×)截断非四舍五入,逐笔分位漂移进 XIRR — `holding/application/service.go:132,202` — 决策:统一 int64(math.Round)
- [F6][P1] TWR 全期 totalDays=cashFlowDays[0]→now,完全清仓+重建仓后分母稀释(GIPS 应重启子链) — `service.go:1366,1510` — 决策:qty=0 期间切分子链
- [F7][P1] 等额本金摊销中间月本金整型截断+利息按截断后 remaining 复算,系统性偏利 — `debt/domain/service.go:50-71` — 决策:浮点均摊+每月四舍五入
- [F8][P1] 预算 actuals 跨币种用月末单点汇率换算全月,波动月偏差 — `budget/application/service.go:333,369-385` — 决策:改每笔 entry 按交易日汇率
- [F9][P1] 汇率缺失静默回退 1.0,用户看到"€100 当 ¥100"(P1-3 加了 Warn 但 1.0 仍返回) — `currency/adapter/driven/repository/rate_history_repo.go:50-55` — 决策:降级 nil 或显式标"汇率缺失"
- [F10][P1] TWR 年化 math.Pow(1+cumulative,…),cumulative<-1 返回 NaN 未防御,DTO 序列化为 0/null 掩盖灾难 — `holding/domain/twr.go:56` — 决策:cumulative<-1 返回 sentinel/nil
- [F11][P2] XIRR 全程 float64,>2^53 cents(~$90T)精度丢失 — `xirr.go:21,58` — 决策:文档化上限+超限降级
- [F12][P2] ApplySplit 不校验 ratio,ratio≤0 时 Quantity 静默归零/翻负 — `holding/domain/entity.go:107-114` — 决策:ratio≤0 返回 error
- [F13][P2] LumpSum 摊销只算单利,跨年与 APY 口径不一致 — `debt/domain/service.go:28-44` — 决策:改复利或 UI 标注单利
- [F14][P2] 持仓 snapshot 仅存原币 MV 无本位币列,历史曲线需 N×M rate 重算 — `service.go:535-544` — 决策:snapshot 加 MarketValueBaseCents 列

## 维度 2 · 数据完整性(schema 层 a37ab + 代码层 ae70)

- [D1][P0] 交易创建全程无事务:header+N entries+余额=N+1+M 独立写,任一崩溃即复式记账破缺/余额未变/Transfer split-brain — `transaction/adapter/driven/repository/transaction_repo.go:79-109` + `balance/updater.go:33-48` — 决策:包同一 ent Tx+CAS 重试
- [D2][P0] Holding 交易 5 写 fan-out(handler 注释"trade not rolled back"+slog 吞错),跨模块 RecordTransaction 失败→持仓有但现金未扣 — `holding/application/service.go:93-147,150-211,231-272` + `holding_handler.go:535-565` — 决策:包 tx 或 outbox/saga+对账
- [D3][P0] Debt 还款 best-effort 吞错:schedule.Paid+principal 已落库但现金 RecordTransaction 失败→净资产虚高 — `debt/application/service.go:235-263` + `debt_handler.go:412-462` — 决策:原子化或对账校验 Paid↔现金流
- [D4][P0] Template autoRecord 假幂等:recorder 成功+NextDate 推进失败→下 tick 重复记账;两 scheduler 实例→双扣(TOCTOU) — `template/application/service.go:180-218` + `scheduler/scheduler.go:88-114` — 决策:DB 唯一键(tenant_id,template_id,last_record_date)或 SELECT FOR UPDATE/advisory lock
- [D5][P0] Backup 无 snapshot isolation:循环 Export 各 Query().All 默认隔离,并发写产生撕裂备份(账户 T1+交易 T2),sha256 只防传输损坏 — `backup/application/service.go:56-62` — 决策:全模块共享 REPEATABLE READ tx 或 pg_export_snapshot 或停写
- [D6][P0] Restore 非原子:purge 成功+import 失败=永久丢失;pre-restore safety backup 本身也非快照+明文 — `backup/application/service.go:178-194` — 决策:共享 *sql.DB+跨模块 Tx 或 maintenance mode+pg_dump/restore
- [D7][P0] 架构根因:整个 server 仅 1 处手写 ent Tx(`budget_repo.go:172-225`),跨模块 write port 签名只接 ctx 无 tx 传播通道 — 决策:统一 tx 抽象(共享 *sql.DB+Tx context 传播,参照 budget 范式)或 outbox/saga+对账 job
- [D8][P1] 全库无真实 FK(除 User↔UserIdentity),所有 *_id 裸列,orphan rows 可能;无 OnDelete 策略 — 各 schema `Edges()` 返回 nil — 决策:加 DEFERRABLE Postgres FK
- [D9][P1] 4 子表无 tenant_id 列(TransactionEntry/BudgetItem/PaymentSchedule/TransactionTag),跨 tenant 泄漏无 DB 兜底;FindUpcomingPayments N+1 全表扫 — 决策:反规范化 tenant_id+重写 tenant-scoped JOIN
- [D10][P1] 金额字段无符号/范围约束(无 Min(0)/CHECK),余额/本金可负;全库仅 1 个 CHECK(transaction_entry debit/credit 互斥) — 决策:加 field.Min(0)+DB CHECK(金额非负、liability≤credit_limit)
- [D11][P1] version 字段多为装饰性(ent 不自动 CAS);SyncLog.(tenant_id,version) 非 UNIQUE 破坏单调版本契约 — 决策:repo WHERE version=? 或确认装饰用途
- [D12][P1] Restore 期间无写冻结+无 mutex,scheduler/用户写竞争 destructive — `backup/application/service.go:111-128` — 决策:maintenance mode+per-tenant mutex+scheduler 暂停
- [D13][P1] auto/safety 备份硬编码明文(encrypted=false)绕过用户加密姿态 — `service.go:113` + `scheduler.go:147` — 决策:继承 BackupSettings encryption preference+DEK
- [D14][P1] ent auto-migrate 每次启动跑,无版本化/无 review gate/无回滚 — `wire/providers.go` 各 client.Schema.Create — 决策:脱离运行时改 atlas/ent-versioned-migrate
- [D15][P1] 缺唯一约束:User.email、SyncDevice.device_name、Backup.filename、BudgetItem.(budget_id,account_id)、PaymentSchedule.(debt_id,payment_date) — 决策:补 UNIQUE
- [D16][P1] FK-like 列(account_id/security_id/budget_id 等)非 Immutable,可被 re-parent — 决策:关键 FK 列加 Immutable()
- [D17][P1] DeleteAccount 不查引用方(只查余额≠0),物理删留 orphan;DeleteByTenant 硬删全部 — `account/application/service.go:134-143` — 决策:拒绝有引用账户或级联 archive
- [D18][P2] Snapshot Save 撞 UNIQUE 硬错,重复 tick 中断当日 snapshot — `snapshot_repo.go:53-67` — 决策:OnConflictDoNothing
- [D19][P2] 加密密码丢失=数据全损(无 escrow);scrypt N=2^15 低于 OWASP 推荐 2^17 — `backup/domain/crypto.go:19-22` — 决策:UI 强提示+recovery code+scrypt 升 N
- [D20][P2] 软删仅 4/33 表+唯一索引不含 deleted_at,Budget/Tag 同名软删后重建冲突 — 决策:抽 TimeMixin+唯一索引含 deleted_at

## 维度 3 · 安全与多租户隔离(af7 + a8e7)

- [S1][P0] GetHoldingPerformance 跨租户读 IDOR:handler 丢弃 tenantID,repo FindByID 无 tenant 过滤(注释"caller's responsibility"但无 caller 过滤),任意认证用户传他人 holding_id 读收益/成本/价格曲线 — `holding/adapter/driving/grpc/holding_handler.go:322-346` + `application/service.go:986-1040` + `adapter/driven/repository/holding_repo.go:67-78` — 决策:FindByID 加 TenantID 过滤+service 签名加 tenantID+handler 透传(照 GetPortfolioPerformance 范式)+跨租户拒绝测试
- [S2][P0] gRPC 无 TLS 且绑 `0.0.0.0:9090`:Bearer JWT/refresh/金额明文,LAN 全暴露,同 WiFi 可抓包接管 — `wire/providers.go:906-914`(无 Creds)+ `cmd/server/main.go:144-145`(`:9090`) — 决策:server 加 TLS(自签+客户端 pin)或绑 127.0.0.1+反代 TLS
- [S3][P0] JWT_SECRET 无强度校验:config 仅 required,误填短串可离线爆破 HS256 — `pkg/config/config.go:14` + `auth/infrastructure/jwt/token.go:19-25,47` — 决策:启动强制 ≥32 字节(或 SHA-256 派生)+warn
- [S4][P0] 10+ handler 默认分支 err.Error() 透传客户端(信息泄漏:字段名/约束名/内部路径) — `budget/account/transaction/tag/goal/holding/debt/currency/sync/template *_handler.go` mapError default + 30+ 处 Unauthenticated err.Error() — 决策:统一 gRPC 错误映射器+泛化 message+err 走 slog
- [S5][P1] RecordTransaction 不校验 entries.account_id 归属:cross-tenant entry 落库→污染 budget actuals(SumEntryTotalsByAccount 无 tenant_id 过滤) — `transaction/application/service.go:34-62` + `transaction_repo.go:890-914` — 决策:Save 前对每 entry 跑 accountRepo.FindByID(tenantID,…),NotFound 即 InvalidArgument
- [S6][P1] OIDC state/nonce 服务端不校验:CSRF/login-fixation 防护全靠 Flutter client — `auth_handler.go:50-63` + `oidc_exchange.go:49-66` + `oidc/verifier.go` — 决策:proto 加 state(server 校验)+Verifier 注入 nonce
- [S7][P1] 全局 securities 写操作无 admin/role 控制:任何登录用户可改任意 security 价格污染所有租户市值/收益;BackfillPriceHistory/SyncPrices 可被滥用打外部 API — `holding_handler.go:33,67-73,263-275,351-360` — 决策:写类 RPC 限运维 CLI 或加 role claim
- [S8][P1] JWT access token 不可撤销+无 aud/iss 校验:登出/改密/删 tenant 后 15min TTL 内仍有效 — `jwt/token.go:51-74`(refresh 层稳健,access 层缺口) — 决策:Redis jti blacklist 或缩 TTL+Parser 加 WithAudience/WithIssuer
- [S9][P1] 只注册 UnaryInterceptor 无 StreamServerInterceptor:未来加 streaming RPC 会跳过 JWT 校验 — `providers.go:909-912` — 决策:补 StreamInterceptor
- [S10][P1] JIT provisioning 非事务:tenant→preset→user→identity 跨 4 表/2 repo 顺序 Save(已知 followup) — `auth/application/command/oidc_exchange.go:81-113` — 决策:封装 WithTx
- [S11][P1] Holding SaveOrUpdate/FindByAccountAndSecurity 查重缺 tenantID 过滤(防御纵深) — `holding_repo.go:24-55` — 决策:Where 补 holding.TenantID
- [S12][P2] parseUUID 静默吞错返回 uuid.Nil,畸形 UUID 进下游 — 各 handler — 决策:(uuid,error) 返回+显式校验
- [S13][P2] RefreshToken/OIDCExchange 无速率限制 — `auth_handler.go:50,67` — 决策:Redis token-bucket
- [S14][P2] JWT 无密钥轮换/kid — `jwt/token.go` — 决策:JWT_SECRET_CURRENT+PREVIOUS+token 带 kid

## 维度 4 · 架构与测试(a8e7)

- [A1][P0] ent 类型/错误泄漏进 auth application 层 — `auth/application/command/oidc_exchange.go:9`(import auth/ent)+`:74`(ent.IsNotFound) — 决策:repo 边界翻译为 domain.ErrNotFound+删 import
- [A2][P0] 跨模块直 import producer domain:transaction/debt/application ← account/domain.Account(违反 CLAUDE.md port 规则) — `transaction/application/service.go:9,18` + `debt/application/service.go:10` + `transaction/application/recorder_adapter.go:8` — 决策:port 搬各自 domain+返回 primitive DTO(AccountSnapshot)
- [A3][P1] typed DomainError 建而不用,handler 改脆弱子串匹配 — `shared/errors/errors.go:6-41` 被 12 处 mapError 绕过 — 决策:中央 ToGRPCStatus(handler 调它,backup_handler 范式)
- [A4][P1] intra-module application 直 import infrastructure(auth/currency/holding 无 domain port) — `auth/application/service.go:14-15` + `currency/application/service.go:10,17,22` + `holding/application/service.go:14,23,27,387,403` — 决策:定义 domain port(JWTService/OIDCRegistry/RateFetcher/PriceRouter)
- [A5][P1] driving handler 跨模块 import producer application(debt/holding ← transaction/application) — `debt/adapter/driving/grpc/debt_handler.go:15` + `holding_handler.go:15` — 决策:debt/domain TransactionRecorder port
- [A6][P1] wire.go 落后 wire_gen.go ~30 provider,无校验测试(误跑 go generate 静默丢依赖) — `wire/wire.go:14-114` + `providers_test.go` — 决策:composition 测试(断言 provide* 集合)或删 wire.go 注释退役
- [A7][P1] slog "op" key 强制规则零执行(0 匹配);CurvePoint.value double 语义模糊 — 全 server + `proto/holding/v1/holding.proto:171-174` — 决策:加 op key 或更新 CLAUDE.md+CurvePoint 改名
- [A8][P1] Sync 破坏 pagination 约定(version-cursor vs common PageRequest);AccountService 混 Account+Category 两 context — `proto/sync/v1/sync.proto:68-78` + `proto/account/v1/account.proto:13-25` — 决策:统一 PageRequest 或拆 CategoryService
- [A9][P1] 测试覆盖盲区:计算边界/授权/事务路径覆盖不足;interface 加方法 implementer 全量 suite 风险(CLAUDE.md 约束 6) — 决策:补授权负向测试+跨租户拒绝+事务回滚测试+计算边界
- [A10][P2] 无 TimeMixin/AuditMixin,14+ schema 内联时间戳已漂移 — 决策:抽 TimeMixin 统一应用+Holding 软删决策

## 维度 5 · 多平台/部署/UX(afe6 + a968b2e)

- [U1][P0] docker-compose 引用不存在的 server/Dockerfile,家人照文档部署直接失败 — `deploy/docker-compose.yml:5` — 决策:补 Dockerfile(多阶段 Go build)或改 compose 拉镜像
- [U2][P0] server 地址=--dart-define 编译期常量(localhost:9090 兜底),换服务器需重新 flutter build — `client/lib/core/config/app_config.dart:11-14` + `grpc_client.dart:13-21` — 决策:首启 onboarding 输入 server URL 持久化 secure storage
- [U3][P0] 纯在线架构:server 宕机即踢登录页(AppStarted→GetProfile 失败→Unauthenticated→/login);Drift/connectivity_plus 死依赖(零 wiring);写失败即丢失无 outbox — `auth_bloc.dart:26-33` + `injection.dart` + `pubspec.yaml:32-33,37` — 决策:接受现状(标尺私域)vs 真 offline-first(读缓存+write queue)
- [U4][P0] OIDC discovery 是 server 启动硬依赖:Google well-known 不可达→InitializeApp 失败→os.Exit(1),无 cache 无重试,air-gapped LAN 永远启不来 — `auth/infrastructure/oidc/provider.go:42` + `registry.go:59-62` — 决策:discovery JSON 本地 cache(boot 优先 cache 后台刷新)vs fallback IdP
- [U5][P0] 无自动更新机制:客户端靠手动重装 MSIX/APK,版本漂移 — `pubspec.yaml:24-45` — 决策:Windows Sparkle/自检版本+Android Play/Sideload vs 接受手动
- [U6][P1] Windows release 卡 accessibility_bridge 循环,全家只能 debug JIT — Flutter engine 层 — 决策:升 Flutter stable 复测/--disable-accessibility 绕/接受 debug-only
- [U7][P1] 列表无虚拟化(transactions_page:1532 等 eager ListView),大数据卡顿;无 server 分页 — 决策:ListView.builder+server cursor 分页
- [U8][P1] 无 gRPC health check+compose 无 healthcheck,server 挂死不可观测 — `cmd/server/main.go:144-149` + `docker-compose.yml:13-18` — 决策:注册 grpc_health_v1+compose healthcheck
- [U9][P1] 客户端零崩溃上报 — 决策:SaaS Sentry/自建 GlitchTip/本地环形日志
- [U10][P1] AuthRetryCaller 只捕 unauthenticated,瞬态错误直抛无重试无进度 — `auth_retry.dart:39-44` — 决策:通用 RetryPolicy(exp backoff+jitter,仅 idempotent)
- [U11][P1] 无 dark mode+固定字号 px+Windows 字体栈 — `app/app.dart:22` + `core/theme/app_design.dart:56,66` + `app_theme.dart` — 决策:落地 Phase5 dark mode+MediaQuery.textScaler
- [U12][P1] 客户端版本硬编码 '1.0.0',server 只 log 不 enforce,版本协商不存在 — `injection.dart:75` + `middleware/logging.go:39-41` — 决策:package_info_plus+server 最低版本拒绝+客户端升级提示
- [U13][P2] 死 UI(通知铃铛空 handler+"高级会员"标签误导) — `app_shell.dart:493,328` — 决策:移除或接功能
- [U14][P2] 无 FlutterError.onError/PlatformDispatcher 兜底+无首启 wizard — `main.dart:5-9` — 决策:加 onError+onboarding wizard

## 维度 6 · 功能完整性 gap(ab3a,对照 14 竞品)

- [G1][P0] 数据导出 CSV/Excel/PDF(用户可移植):行业 100% 标配,真缺(backup 仅内部 JSON) — 决策:报表+流水导出(复用 backup exporter 序列化)
- [G2][P0] 家庭共享账本+权限角色:标尺核心,真缺(memory followup family tenant;当前一 tenant 一用户) — 决策:tenant+member+role(只读/编辑)
- [G3][P0] 应用锁 PIN/Windows Hello+自动锁定+隐藏余额:桌面家庭共用必备,真缺 — 决策:App Lock+privacy mode
- [G4][P0] 账单到期提醒+日历视图:template autoRecord 有引擎缺通知层,真缺 — 决策:reminder 模块+即将到期日历 UI
- [G5][P0] 全局搜索+高级筛选:查账刚需,真缺(Phase4 规划未做) — 决策:server query DSL+client search bar
- [G6][P0] 报表 PDF 导出/现金流表:复盘/报税/给会计,真缺(report 有图表无输出) — 决策:PDF 导出+正式 Cash Flow/Balance Sheet 报表
- [G7][P1] 银行流水导入 CSV/OFX/QFX/Excel+规则自动分类:真缺,迁移成本高 — 决策:import 模块+规则映射
- [G8][P1] 拆单 split transaction(一笔跨多类别):真缺(account-as-category 单分类) — 决策:多 entry 支持或 split 子结构
- [G9][P1] 凭证/发票/合同附件:真缺 — 决策:attachment 模块(本地路径挂接低成本)
- [G10][P1] 对账 reconcile:真缺(无 cleared/reconciled flag) — 决策:reconcile 状态字段+workflow
- [G11][P1] 预算超支提醒+pace tracking+滚动预算:已有 UI 缺智能提醒 — 决策:实时超支通知+pace
- [G12][P1] 暗色模式+主题(同 U11)
- [G13][P1] 投资组合分析增强(目标配置%+drift+再平衡+股息日历):holding 已强,边际 — 决策:目标配置+drift 告警
- [G14][P1] 多设备同步:cancelled 但 gap 存在(出差/手机记账/夫妻并发) — 决策:重开 vs 保持 cancelled(标尺边界,待用户定)
- [G15][P1] 大件资产(房产/车辆)净值追踪:真缺(家庭净值最大头,中国家庭房产占资产 70%+) — 决策:asset 实体(估值+历史曲线)
- [G16][P1] 引导/新手向导:真缺 — 决策:onboarding wizard
- [G17-G24][P2] 债务雪崩/雪球、保险管理、税务辅助、OCR 票据、桌面 widget、YoY 对比、订阅管理、帮助中心 — 行业非主流,视反馈投入

---

## 主题归组建议(建 ticket 时)

1. **跨租户数据隔离**:S1/S5/S7/S11/D9 + 相关授权测试 A9
2. **传输与密钥安全**:S2/S3/S8/S14
3. **事务一致性架构(根因)**:D7 + D1/D2/D3/D4 + S10
4. **备份恢复可靠性**:D5/D6/D12/D13/D18/D19
5. **DB 完整性约束**:D8/D10/D11/D15/D16/D17/D20
6. **财务计算正确性**:F1-F10(F1 汇率基数最高)
7. **跨币种汇率体系**:F1/F8/F9(汇率基数+时点+缺失降级)
8. **错误处理统一**:S4/A3(+ gRPC status code)
9. **DDD/port 边界**:A1/A2/A4/A5
10. **wire 与 schema 工程债**:A6/A7/A8/A10/D14
11. **部署通路**:U1/U2/U4/U5
12. **offline/可用性/可观测**:U3/U6/U7/U8/U9/U10/U12/U14
13. **功能 gap · 数据进出**:G1/G5/G6/G7
14. **功能 gap · 家庭多用户**:G2/G3(+ 应用锁)
15. **功能 gap · 提醒与资产**:G4/G15(+ G8/G9/G10/G11)
