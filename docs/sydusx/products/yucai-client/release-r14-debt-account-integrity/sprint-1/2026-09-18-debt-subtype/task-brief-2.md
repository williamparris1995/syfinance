# Task Brief T2 — server UpdateDebt 接线 subtype

## 任务
`UpdateDebtRequest` 已追加 `string subtype = 19;`（worktree 已 regen，`server/internal/proto/debt/v1/debt.pb.go` 已有 `GetSubtype()`）。把 subtype 接进 UpdateDebt 处理链：**空串 = 保持不变**（旧 client 不发字段必须零影响——这是 NFR-2 的硬约束），非空 = 替换。

## 文件
- `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go` — UpdateDebt handler：把 `req.GetSubtype()` 填入 application 层 update 参数（`internal/debt/application/dto.go` 的 update DTO 已有 `Subtype` 字段，核对 handler 现有映射处补一行/一处判断）。
- `yucai/server/internal/debt/adapter/driven/repository/debt_repo.go` — 更新路径 `SetSubtype` 已存在（约 :300）；核对入参链路把值送到（若 handler→usecase→repo 链上已有 Subtype 字段则只需 handler 填充 + 空串保护）。
- 测试：`yucai/server/tests/` 下 debt 集成测试文件（找现有 UpdateDebt 测试文件扩展，勿新起风格）。

## TDD 周期（sydusx-tdd）
1. RED：集成测试——创建债务(subtype=A)→UpdateDebt 带 subtype=B→读回=B；UpdateDebt 不带 subtype(空)→读回仍=A（旧 client 兼容断言，必写）。
2. GREEN：handler/params 接线。空串保护放 handler 或 usecase 入口（选其一并在注释说明"empty keeps current"）。
3. 回归：`go build ./...` + `go test ./...` 全绿（基线全绿）。

## 约束
- English 注释/日志（无 CJK log 串）；DDD 分层边界；repo 层已有 `SetSubtype` 勿重写。
- 完成后报告：改动文件清单 + 测试输出（0 failures 证据）+ go build/test exit code。
- 工作目录：`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f33`（分支 feature/r14-f33-debt-subtype，勿切分支勿动 main）。
