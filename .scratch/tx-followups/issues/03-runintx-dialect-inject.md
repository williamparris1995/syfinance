# 03 · runInTx dialect 注入

Type: task
Status: open
Priority: P2
Blocked by: —

## Question

Task4-7 的 `runInTx` 硬编码 dialect `"postgres"`(`sqltx.WithTx(ctx, s.db, "postgres", nil, fn)`)。production 正确,但 SQLite 测试靠 modernc tolerates `$N` placeholder 过 —— 脆弱(未来 raw-SQL 聚合测会 placeholder mismatch)。final review 标 cross-cutting(Tasks 4-7 共有)。

## Fix

注入 dialect:`SetDialect` setter(service 持 dialect 字段)或 service 常量;production wire 传 `"postgres"`,test 传 `"sqlite"`。同 `SetDB` nil-skip pattern。

关联:03 spec 4.2(`sqltx.WithTx` dialect 参数已存在,service 层未用)。
