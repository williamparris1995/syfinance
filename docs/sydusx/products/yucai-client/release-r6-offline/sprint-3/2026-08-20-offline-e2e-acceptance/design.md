---
feature: 2026-08-20-offline-e2e-acceptance
status: confirmed
---

# Design — 三判据 e2e 验收

> 消费 [spec.md](spec.md)(confirmed)。轻量 feature:无生产代码,design 极简(脚手架结构+复用组件清单)。

## 结构

- `test/e2e/r6_acceptance_test.dart`:4 组判据集成测试(单文件,组名=判据名)。
  - 复用:各 local ds(D/E/F)+exporter/bloc(G)+BoundMirror(H)——全部已测组件,本文件只做**串联编排**与**断言**。
  - 临时文件库(`Directory.systemTemp`)真实关开;远端侧 repo/DS/BackupRemote 接口 mock(mocktail)。
  - e2e-② 的上传字节 capture:`_MockBackupRemote.uploadBackup` 的 `captureAny()` 取 envelope 解码断言。
  - e2e-④:mock AuthBloc 不可行(bloc 有依赖)——直接操作 `SessionModeTracker`(isGuest 翻转)+ BindingBloc 的 mirror 集成已单测,本组聚焦「guest 旧数据+镜像数据合并可见」的读路径串联。
- `acceptance-checklist.md`:人工清单(4 场景×步骤/预期/勾选/签名栏)。

## 测试即验收

本 feature 的"实现"=测试本身;review 聚焦断言充分性(是否真验判据)与 mock 保真度。
