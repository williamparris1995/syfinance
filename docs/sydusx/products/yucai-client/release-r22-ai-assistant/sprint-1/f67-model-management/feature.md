---
title: F67 端侧模型管理
keywords: 模型下载, 断点续传, sha256, hf-mirror, 模型删除, 磁盘占用, ModelState
---

# F67 端侧模型管理

> /sydusx-brainstorming 2026-10-23 进入;analysis 同日 spec 落档(质询两决策)。R22 sprint-1 依赖序末位能力票;UI 卡=F65 消费。

## 概述

Qwen3-4B GGUF 四钉死下载(官方优先回落 hf-mirror/Range 断点续传/进度/暂停恢复取消/sha256 校验/原子落地)+ModelState 状态流+版本/占用/删除(联动停引擎);替换 F66 的 ModelStore 简版实现(port 不变)。无 UI。

## Stories

- [ ] S1: ModelManager(domain port+ModelState 五态)+下载器(dart:io Range/续传/进度/暂停恢复取消/流式 sha256/.part 原子落地+源回落)+状态流。
- [ ] S2: ModelStore 换绑(ModelManager 实现 port,F66 简版退役;DI 调整)+版本/占用查询+删除联动 EngineManager.shutdown。
- [ ] S3: loopback 集成测(Range 续传/暂停恢复/取消/校验失败四场景)+全门(test/analyze/server 零 diff)+覆盖表。

## 非目标(Non-goals)

模型卡 UI(F65)/自动触发下载(F65)/多模型切换(backlog)/下载限速(backlog)/写操作(sprint-4)。
