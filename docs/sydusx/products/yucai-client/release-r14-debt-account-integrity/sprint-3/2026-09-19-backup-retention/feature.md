---
title: F40 backup-retention
keywords: [自动备份, 保留策略, 清理, backup-retention, server]
---

# Feature — F40 自动备份保留策略(R14 sprint-3)

> 2026-09-19。自动备份列表无限增长问题:调度 pass 每租户保留最近 30 份自动备份。

## Description

server BackupScheduler 每小时 pass 创建 auto 备份但从不清理。目标:auto 备份创建后,同 pass 内按 provider=auto 过滤,删除最旧的超出部分(保留最近 30 份);手动备份(provider=manual)不清理。

## Stories

- [ ] S1: 调度 pass 内 retention 清理(照既有 ListBackups/Delete 管道)
- [ ] S2: 集成测试(35 份 auto → pass → 30 份保留最新;manual 不动)

## Keywords

`自动备份` `保留策略` `retention` `清理` `backup`
