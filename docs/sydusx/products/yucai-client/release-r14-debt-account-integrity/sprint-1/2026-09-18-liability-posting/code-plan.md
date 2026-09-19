# Code Plan — F36 负债记账治本·方案 A

> 依据:[spec.md](./spec.md)(用户拍板 3 决策点) + [design.md](./design.md)(ADR-1~7)。复杂度 **cross-module**(client DS+迁移/server 事务)→ SDD;T1/T3/T4 串行(共享 settlement 助手),T2 与 T1 并行(不同栈)。

## Tasks

- [ ] **T1 client 分录补齐(dispatch)** — debt_local_ds:①创建无到账(borrowedIn+source 空)→ 借权益+P/贷负债+P;②update ΔP≠0 → 调整分录(负债±Δ/权益∓Δ,同事务);③delete remaining>0 → 清账分录(借负债−剩余/贷权益)。TDD:不变式序列测试(真实 drift:每步 balance==−Σremaining)。验收:test/debt/ 全绿。
- [ ] **T2 server 入账(dispatch,与 T1 并行)** — service.go/事务管道:创建(有 source→借资产+P/贷负债+P;无→借权益+P/贷负债+P,权益科目解析照既有 AccountLookup 惯例)+update ΔP 调整+delete 清账。TDD:tests/debt_integration_test.go 扩展不变式断言。验收:go test 全绿。
- [ ] **T3 存量迁移(inline,依赖 T1)** — repairs.dart:f36Repair(逐负债账户 delta 调整,app_meta `f36_liability_balance_repair_v1` 幂等,启动管道挂载)+单测(漂移库→repair→收敛;重跑不重复)。
- [ ] **T4 不变式矩阵 + 全量门(inline)** — 混合序列不变式测试;go build/test+flutter 全量+analyze+client-e2e;dev 库修复执行与取证(5 户 balance==−Σremaining)。

## 全局约定

English 注释与日志;复式分录走既有 `_txns.recordTransaction`/server 事务管道,零直接 UPDATE 余额;权益户「历史还款结转」唯一(幂等复用);调整分录描述固定前缀「F36 余额修复」。

## Ledger

(→ code-ledger.md)
