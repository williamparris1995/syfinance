---
title: F39 local-snapshot
keywords: [本地快照, guest, 备份, 恢复, 定时, local-snapshot, snapshot]
---

# Feature — F39 guest 本地快照闭环(R14 sprint-3)

> 2026-09-19。既有:设置页导出存档(加密 .ycb)/导入存档(选文件→覆盖替换)已闭环(手动、文件选择器制);
> 本票补「定时自动 + 应用内选档」, guest 模式不再依赖 server。

## Description

现状:guest 模式备份=手动导出加密文件+手动导入,无定时、无应用内备份列表。目标:①启动时(每自然日一次,app_meta 标记)自动写本地快照(envelope JSON,明文,与本地库同等保护级)至 `<appSupport>/local_backups/`,保留最近 7 份;②设置页新增「本地快照」区:列表(文件名/日期/大小)+ 恢复(确认覆盖→importAll→DataRefreshNotifier.bump)/删除/立即快照。

## Stories

- [ ] S1: 快照服务(LocalSnapshotService:runDailyIfDue/列表/删除/恢复,复用 exportAll+importAll)
- [ ] S2: 设置页「本地快照」区 UI+接线
- [ ] S3: 测试(每日触发/保留 7 份滚动/恢复替换数据)

## Keywords

`本地快照` `local-snapshot` `guest` `备份` `恢复` `定时`
