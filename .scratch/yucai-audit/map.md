# 御财行业规范审计 · Wayfinder Map

## Destination

在「家庭多用户(私域)」标尺下,对御财(Go + Flutter)做一次全面独立审计 —— 系统对照个人/家庭理财应用的行业最佳实践(产品实践 + 工程规范 + 金融计算标准),既评估已实现功能的质量规范,也找功能完整性 gap;独立确认已知问题并挖掘未意识到的盲点。**产出一张改进决策地图**:每个发现的问题或遗漏成为一个待决策的 ticket(修不修 / 怎么修 / 优先级)。

## Notes

- **标尺**:家庭多用户(私域)。要求:工程最佳实践 + 财务计算准确 + 多用户数据隔离 + 备份可靠 + 基础安全。**豁免**:公众级合规(GDPR/PIPL 完整合规、商业级安全审计)、i18n 国际化(中文直写)。
- **视角**:全面独立审计 —— 已实现质量 + 功能 gap 都在范围;既独立确认 memory 已记录的 followup,也挖未意识到的盲点。
- **审计已执行**:6 维度并行只读 agent 审计(财务计算 / 数据完整性 schema+代码层 / 安全与多租户隔离 / 架构与测试 / 多平台·部署·UX / 功能完整性 gap)。各维度发现见对应 ticket。
- **决策时应 consult 的 skills**:`grilling` + `domain-modeling`(ticket 决策时);`research`(金融计算标准、竞品深度对比);`prototype`(UI gap 原型)。
- **已知有意取舍(非 bug,ticket 化时勿误判)**:account-as-category + 双账 Transfer;wire_gen.go 手维护(CLI 坏);中文 UI 直写;local-first Postgres + client gRPC 直连(云备份/多设备同步 cancelled 2026-07-25)。
- **glm subagent 已知问题**:复杂多重点 prompt 会角色错乱;聚焦单一任务或 SendMessage 挽救可产出优质内容。work 阶段派 research/prototype 子 agent 时 prompt 要聚焦单一问题。
- **Frontier 确认(2026-07-26)**:全量主题 ticket 化 —— 16 张决策 ticket 覆盖 P0 + 关键 P1,P2 进 fog;多设备同步纳入为决策 ticket(16),不划 out-of-scope。

## Decisions so far

<!-- 一行 per closed ticket:足够判断相关性,然后 zoom 链接看 ticket 详情 -->

- [01 跨租户数据隔离与授权](issues/01-tenant-isolation.md) — IDOR 透传 tenantID 修(GetHoldingPerformance 全链)+ entries 归属校验;防御纵深=应用层 ownership + repo 强制 tenant_id Where(子表 DB 约束留 05);securities 全局写=admin role claim(first-user-is-admin,与 14 协同);建全量跨租户拒绝矩阵作 CI 回归门。**已实施(4 commits fdf39ee/50a14f8/06972cf/642897d,本地 main 未 push,59 包测试绿)**。
- [07 跨币种汇率体系](issues/07-multi-currency-fx.md) — `SyncRates` 落库前重基 Frankfurter EUR-base→**CNY-base**(F1 P0 修根,公式不变);预算 actuals 改每笔交易日汇率(F8);本位币保持现状不加 tenant 字段;汇率缺失 1.0 回退 + UI 提示(F9);补 Frankfurter 真实样本端到端测试。**F1 已实施(commit 本地 main,16 包测试绿);F8/F9/FetchExchangeRate 单币路径/seed 值留 follow-up**。
- [02 传输与密钥安全](issues/02-transport-key-security.md) — server 自签 TLS + 客户端 pin 证书指纹(S2);JWT_SECRET 启动强制 ≥32 字节 reject(S3);access token Redis jti blacklist + Parser 加 aud/iss(S8);单密钥不轮换(S14 接受中断)。**密钥安全已实施(commit 本地 main,全包测试绿);TLS/proto Logout/miniredis 留 follow-up**。
- [03 事务一致性架构](issues/03-transactional-architecture.md) — 根因(整个 server 仅 1 处真事务)。决策:共享 `*sql.DB` + Tx context 传播(参照 budget);范围只 P0 财务写(交易/holding/debt/template);autoRecord 加 DB 唯一键 `(tenant_id,template_id,last_record_date)`;不引入对账 job。**unblocks 04**。实施规模大,单独 plan/session。
- [04 备份恢复可靠性](issues/04-backup-restore-reliability.md) — 建立在 03 之上:backup 共享 `REPEATABLE READ` 只读 tx 拍快照(D5);restore purge+import 包跨模块 tx 原子化 + 保留升级版 safety backup 作「人为错误」兜底(D6);per-tenant 内存 flag 三件套写冻结(restore mutex / middleware 该 tenant 写 RPC 返 UNAVAILABLE 读放行 / scheduler 跳过)(D12);加密分层(safety backup restore 时用户密码加密 / auto backup server-local 明文 UI 标「未加密·仅本机」+ 文件 0600,**不**引 server-held DEK)(D13);polish: snapshot `OnConflictDoNothing` + scrypt N 2^15→2^17 版本化自描述 KDF header(D18/D19a),recovery code(D19b)defer 进 P2。**依赖 03 阶段 A;实施留专项 plan/session**。
- [05 DB 完整性约束](issues/05-db-integrity-constraints.md) — 同模块 ent edge FK 加(budget↔BudgetItem / transaction↔Entry / holding↔Trade·Lot / debt↔PaymentSchedule),跨模块**不加**(ent 跨 codegen + D14 migrate 债 + 03/01 app 层已防);`field.Min(0)` 精细非负字段(余额·PnL 不加),不加 DB CHECK;**findings D11 纠正:7 模块 version 已 CAS 非装饰**(account/transaction/tag/debt/goal/template/budget),保持现状;D15 unique 4 项(User.email / Backup.filename / BudgetItem.(budget_id,account_id) / PaymentSchedule.(debt_id,payment_date),SyncDevice 挂 16)+ D16 Immutable 关键 FK 列;现软删表 partial unique(含 deleted_at)+ Holding 不软删 + DeleteAccount 改拒绝有引用;TimeMixin 抽取挂 10,SyncLog/SyncDevice unique 挂 16。**实施留专项 plan**。
- [06 财务计算正确性](issues/06-financial-calculation-correctness.md) — research(14 信源)支撑:portfolioCAGR(F2 P0,=P1-6 真根因)切 `portfolioXIRR` 为主指标(已存在)+ CAGR 降级辅助 UI 标口径(CAGR 不适合多现金流,MWRR 才正确);XIRR(F3/F4/F11)入口归一化(数学等价,解大额不收敛 + 精度边界)+ 自适应 bracket + Brent 替换 bisection;TWR(F6/F10)零端值 sentinel + 清仓段分段链乘(GIPS)+ cumulative<-1 NaN 防御;F5 AmountCents math.Round + F7 等额本金浮点均摊每月四舍五入;真实样本端到端测试(Excel/scipy oracle)防 mock 掩盖。F11 归一化解,F12/F13 P2。**实施留专项 plan**。
- [08 错误处理统一](issues/08-error-handling.md) — `shared/errors` 加中央 `ToGRPCStatus(err)`(`errors.As` 派发 `DomainError.Code` → NotFound/InvalidArgument/FailedPrecondition 乐观锁/PermissionDenied/Unauthenticated;非 DomainError → Internal 固定 `"internal error"` 不透传 `err.Error()` + slog);各 handler 删 `mapError`/`contains` 统一调;service 抛 `DomainError` 替代 `fmt.Errorf`。解 S4 信息泄漏 + A3 子串脆弱。迁移:handler 一次性全切 + service DomainError 渐进(default Internal 兜底)。**实施留专项 plan**。
- [09 DDD/port 边界](issues/09-ddd-port-boundaries.md) — 修 A1(repo 包 ent.NotFound→`domain.ErrUserNotFound` sentinel,application 删 auth/ent import)+ A2(各 consumer `domain/` 读端口 + per-consumer 最小 primitive snapshot:debt `{CurrencyCode}`、transaction/template `{+CurrentBalanceCents}`;写路径 `BalanceUpdater` 已净不动)+ A5(holding 泄漏被 A2 覆盖,现金记录已 TradeCashRecorder;**debt CreateDebt 双写** 加 `CreateDebtCashRecorder` port + 下沉 service 走 sqltx 原子,完成 T03 #3)。**A4 intra-module app→infra defer**(软层违 ROI 低)。渐进实施 + `.golangci.yml` depguard 锁 A1/A2/A5(不锁 A4;wire/adapter seam allow-list)。

## Not yet specified

<!-- fog:P2 backlog + 跨 ticket 取舍;随 frontier 推进逐个 ticket 化 -->
- **P2 backlog**(已识别未 ticket 化,视 P0/P1 落地后再排):功能 gap G17-G24(债务雪崩/雪球、保险、税务、OCR、桌面 widget、YoY、订阅管理、帮助中心);计算精度 F11-F14 polish;D18-D20 / S12-S14 / A10 / U13-U14 polish;**04 defer 的 D19b recovery code**(DEK + password/recovery-key 双包 + 生成/展示/保管/改密重加密 UI 流程,P2)。
- **跨 ticket 取舍**(相关 ticket 决策时一并定):
  - offline 策略(12)与多设备同步(16)的方案是否合一?
  - ~~统一 tx 抽象(03)与 DB FK/CHECK(05)是否同一批 migration 落地?~~ 已定(05 决策):03 已落无 schema migration,05 独立 ent schema 改 + regen;TimeMixin 抽取(A10)→ 10 协同。
  - ~~DDD/port 重构(09)与错误处理统一(08)的迁移顺序?~~ 已定(08 决策):handler 一次性先(独立于 09);service DomainError 渐进与 09 service 重构协同。
  - 家庭共享账本(14)的 role 模型与跨租户隔离(01)授权模型的对齐?
- **Research 已完成**(2026-07-26):[`research/multi-device-sync.md`](research/multi-device-sync.md)(支撑 16 —— 推荐 Option A:复用 server scaffolding + 自建 client,3-5 周)、[`research/financial-calc-standards.md`](research/financial-calc-standards.md)(支撑 06 —— XIRR 入口归一化 / TWR 零端值 sentinel / portfolioCAGR 切 XIRR)。结论已分别挂 16 / 06 ticket。

## Out of scope

- 公众级合规(GDPR/PIPL 完整合规、商业级安全审计)—— 私域标尺豁免。
- i18n 国际化(中文直写)—— 私域标尺豁免。
- (待用户确认)已 cancelled 的云备份 / 多设备同步是否作为新 effort 重开。
