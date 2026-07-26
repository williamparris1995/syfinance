# 06 · db.Close shutdown wiring

Type: task
Status: open
Priority: P2
Blocked by: —

## Question

`provideDB`(Task 1)的共享 `*sql.DB` 未接 shutdown path —— `App` 无 `Shutdown` 方法(pre-existing 模式,各 ent client 也不 Close)。server 退出时连接不显式 Close,依赖 OS 清理。

## Fix

加 `App.Shutdown(ctx)`(或 `Close()`),调共享 `db.Close()`。需 wire 暴露 db 到 App + main.go signal handling 调 Shutdown。

关联:03 Task 1(共享 provideDB);pre-existing 模式(openEntDriver 也不 Close)。
