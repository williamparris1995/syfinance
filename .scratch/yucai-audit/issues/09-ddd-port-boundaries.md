# 09 · DDD/port 边界(ent 泄漏 + 跨模块 import)

Type: grilling
Status: open
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
