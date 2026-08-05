# 09 · DDD/port 边界(ent 泄漏 + 跨模块 import)

Type: grilling
Status: resolved
Blocked by: —

## Question

DDD 四层 + 跨模块 port 范式选点精准,但执行有缝:port 规则只覆盖显式范例,intra-module 与 driving-side 是盲区(详见 `findings.md` A1/A2/A4/A5):

- **[A1 P0]** ent 类型/错误泄漏进 auth application 层(`auth/application/command/oidc_exchange.go:9` import `auth/ent` + `:74` `ent.IsNotFound`)。
- **[A2 P0]** 跨模块直 import producer domain:transaction/debt/application ← `account/domain.Account`(违反 CLAUDE.md port 规则)。正确范式:networth 返回 `map[string]int64`、goal `AccountMarketValueSource` 返 `int64`、budget `entryFunc` 闭包。
- **[A4 P1]** intra-module application 直 import infrastructure(auth/currency/holding 无 domain port:JWTService/OIDCRegistry/RateFetcher/PriceRouter)。
- **[A5 P1]** driving handler 跨模块 import producer application(debt/holding ← `transaction/application`);应走 `debt/domain.TransactionRecorder` port。

**决策点:**
1. transaction/debt 的 account port 搬到各自 `domain/` + 返回 primitive DTO(`AccountSnapshot{Type,Currency,BalanceCents}`)?
2. auth/currency/holding 定义 domain port,application 只依赖 port?
3. `debt/domain.TransactionRecorder` port(由 `transaction/application.Service` 实现),删 driving handler 直 import?
4. 迁移节奏:一次性 / 按模块渐进?是否补 architecture lint / ArchTest 防回归?

## Answer

**Scope**:修 **A1**(ent 泄漏)+ **A2**(跨模块 domain import)+ **A5**(driving 跨模块 app import)。**A4**(intra-module app→infra:JWTService/OIDCRegistry/RateFetcher/PriceRouter)**defer 为文档化 tech-debt**(软层违、4 个 infra port 化 ROI 低;若将来引 ArchTest 全覆盖再议)。ArchTest 锁 A1/A2/A5,不锁 A4。

**A2**(transaction/debt/template ← account/domain):各 consumer 的 `domain/` 定义读端口 + **per-consumer 最小 primitive snapshot** —— debt `{CurrencyCode}`、transaction/template `{CurrencyCode, CurrentBalanceCents}`;adapter 调 account 映射 Account→snapshot。**写路径 `BalanceUpdater`(adapter/driven)已干净,不动**。AccountType 不入读 snapshot(类型逻辑在 balance updater adapter,正当 seam)。port 从 application 移到 consumer `domain/`。

**A1**(auth/application ← auth/ent):repo(infra)包 `ent.NotFound` → `domain.ErrUserNotFound` sentinel;application 改 `errors.Is(err, domain.ErrUserNotFound)`、删 `auth/ent` import。对齐 T08 DomainError 方向。单点修复(1 repo 方法 + 1 call site)。

**A5**(debt/holding driving ← transaction/application):
- **holding** 的泄漏(`txnApp.AccountLookup` 类型 + `accountdomain` 校验)**被 A2 覆盖**(改用 holding/domain 校验端口返回 snapshot);现金记录已 `TradeCashRecorder`(T03)→ holding 无额外工作。
- **debt CreateDebt 双写**:目前 handler 直调 `transactionSvc.RecordTransaction`(L219,best-effort)。加 `debt/domain.CreateDebtCashRecorder` port(镜像 T03 `RepaymentCashRecorder`)+ 把双写下沉 debt/service(走 T03 sqltx 原子)→ 修 A5 debt import 泄漏(adapter 包 transaction/application)+ **完成 T03 follow-up #3**(CreateDebt best-effort → 原子)。debt 的 AccountLookup/accountdomain 校验泄漏同样被 A2 覆盖。

**节奏 + ArchTest**:**渐进**(A1 / A2 / A5-CreateDebt 各自一子努力,独立 review/落地)。加 `.golangci.yml` **depguard** 规则 deny:application→`*/ent`、application/domain→他模块 application/domain(锁 A1/A2/A5;wire + adapter/driven seam 须 allow-list 精确配置;A4 不纳入)。

**实施**:本 ticket 是决策;落地是 map 之后的渐进执行(各自 plan/session,subagent-driven TDD),非本 ticket 范围。
