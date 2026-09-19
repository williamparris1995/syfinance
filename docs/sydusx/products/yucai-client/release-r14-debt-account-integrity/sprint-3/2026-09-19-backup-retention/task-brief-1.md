# Task Brief — F40 自动备份保留策略(TDD)

## 任务
server 自动备份调度 pass 内新增保留清理:每租户 provider=auto 的备份**保留最近 30 份**,超出部分删除最旧;provider=manual 的备份不清理。

## 侦察与实现
- 调度器:`internal/backup/scheduler/scheduler.go`(每小时 pass,per-tenant 经 BackupCreator 创建 auto 备份)——在创建逻辑后追加 retention 清理(或调 service 层方法,照架构分层判断并说明)。
- 列表/删除:service.go 既有 ListBackups/DeleteBackup 管道照用(provider 过滤 + 时间倒序)。
- 常量:保留份数 30,定义为具名常量 + 注释(未来可配置化)。
- 注意 RestoreFreeze:清理也须尊重恢复冻结语义(照 pass 内既有做法)。

## TDD
测试:照既有 backup 集成测试风格(tests/ 或 internal/backup/application 测试文件)——
1. 种 35 份 auto 备份(不同 created_at)→ 跑调度 pass(或直接调 retention 方法)→ auto 备份剩 30 份且为最新 30 份。
2. 种 10 份 auto + 5 份 manual → pass → auto 10 份全保留,manual 5 份不动。
3. 少于 30 份 → 全保留。
回归:`go build ./...` + `go test ./...` 全绿。

## 约束
English 注释与日志;勿提交 git;**禁止 git stash/checkout/restore**。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f40`
完成后报告:改动文件、放置层裁定、RED→GREEN 证据、go build/test 结果;BLOCKED 即停。
