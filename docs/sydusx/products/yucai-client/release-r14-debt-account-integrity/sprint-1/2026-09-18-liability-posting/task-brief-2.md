# Task Brief T2 — server 负债入账补齐(不变式 TDD)

## 不变式(server 侧同构)
对每笔 borrowedIn 债:其挂账负债账户的 balance 贡献 == −(totalPrincipal − ΣpaidCents)。server 侧经既有事务管道入账(transaction application service,AccountLookup port,WithTx 与债务持久化同事务——service.go 既有还款入账照此)。

## 任务(yucai/server/internal/debt/application/service.go 等,三处)
先侦察 service.go 既有还款入账实现(:56-65 事务端口注释、还款路径)——**完全照该模式**扩展:
1. **创建**:borrowedIn 且 source_account_id 非空 → 借 source 资产 +P / 贷 负债 +P;source 空 → 借 权益科目 +P / 贷 负债 +P。权益科目解析:照既有 AccountLookup 惯例(若 lookup 支持 byName/系统户则用之;若无先例,按 lookup 接口最小扩展并在报告说明,**不要自创表结构**)。borrowedOut 创建已有 buildCreateEntries 类入账则不动。
2. **update**:totalPrincipal 变化 Δ≠0 → 负债 ±Δ / 权益 ∓Δ 调整分录(同 WithTx)。
3. **delete**:剩余>0 → 借 负债 −剩余 / 贷 权益(剩余=total−ΣpaidCents,同客户端口径)。
 borrowedOut 路径全部维持现状。

## TDD(tests/debt_integration_test.go 扩展,RED 先行)
- 不变式断言助手:操作后查 balance(经 lookup 的账户余额持久化值)== −Σremaining。
- 序列:创建(source 空)→ 不变式;创建(source)→ update 改 P → 不变式;创建→delete → 不变式。
- 回归:`go build ./...` + `go test ./...` 全绿。

## 约束
English 注释与日志;DDD 分层;勿动还款既有入账;勿提交 git。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f36`
完成后报告:侦察结论(既有入账模式)、改动文件、RED→GREEN 证据、回归结果;若 AccountLookup 无法表达权益科目(接口缺能力),BLOCKED 报告方案选项,勿硬改接口。
