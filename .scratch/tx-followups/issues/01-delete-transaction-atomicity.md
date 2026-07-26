# 01 · DeleteTransaction 原子化

Type: task
Status: open
Priority: P1
Blocked by: —

## Question

`transaction.DeleteTransaction`(`transaction/application/service.go`)仍是多写非原子:ReverseBalances → SoftDelete 顺序写,balance 回滚失败即复式记账破缺。这是 03 实施时 D1 scope(creation)外的同类 P0-shape 缺陷(final review 标 P1)。

## Fix

包进 `sqltx.WithTx`(同 CreateTransaction 范式,Task 4 已建)。repo 写方法已 `clientFor` 就绪(Task 3/4),balance updater 经 accountRepo 已 tx-aware。约:service `runInTx` wrap + body rename。

关联:03 spec `docs/superpowers/specs/2026-07-26-transactional-architecture-design.md`。
