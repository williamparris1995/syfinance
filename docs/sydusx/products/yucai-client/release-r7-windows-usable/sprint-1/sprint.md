# Sprint 1 — R7 分发基础

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-08-29)。

## Sprint Goal

**Windows 打包/安装通路就位**:从源码到可安装产物一条命令可达;全新安装的本地模式三判据复验;R6 人工验收清单执行并归档。

## Feature roster(依赖排序)

- [x] **feature A** 2026-08-29-a1-windows-packaging — Windows 打包/安装通路 ✅ done(2026-08-29;Inno Setup 免签名[grill]+中文向导+per-user;make windows-installer 一键 14.4MB;安装/卸载 round-trip 验证;review PASS+gitattributes CRLF 加固;教训录 acceptance.md[worktree 路径长度/Defender 扫描窗/MSYS 转换])
- [ ] **R6 人工验收归档**(非 feature,checklist 项):[acceptance-checklist](../../release-r6-offline/sprint-3/2026-08-20-offline-e2e-acceptance/acceptance-checklist.md) 在打包版执行 → 结果记回 R6 release.md(blocked-on-user,与 feature A 完成后一并做)

## status: in-progress(feature A ✅ done 2026-08-29;余:R6 人工验收归档[blocked-on-user,打包版执行三判据]→ sprint-1 收官)
