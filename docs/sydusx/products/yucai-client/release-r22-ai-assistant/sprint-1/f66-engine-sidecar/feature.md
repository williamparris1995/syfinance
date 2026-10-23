---
title: F66 llama-server 边车管理
keywords: 边车, llama-server, 引擎管理, 懒启动, 闲置回收, provider 收窄, 引擎状态
---

# F66 llama-server 边车管理

> /sydusx-brainstorming 2026-10-23 进入;analysis 同日 spec 落档(质询三决策)。R22 sprint-1 依赖序首票;含 F64 provider 收窄返工。

## 概述

随包 llama-server.exe 的引擎管理:懒启动+闲置 10 分钟回收+退出强杀+崩溃退避重启+/health 探测;F64 AssistantConfig 收窄为 {enabled, model}(纯内嵌,零端点零 Key);引擎状态流供 F65(含 starting 加载动效);真 exe+tiny fixture 集成冒烟;随包捆绑工程面。

## Stories

- [ ] S1: EngineManager — 生命周期(懒启动/闲置回收/强杀 taskkill /T/退避重启上限 3)+/health 就绪+EngineState 多播流。
- [ ] S2: F64 provider 收窄返工 — AssistantConfig={enabled,model}/keys 直改+旧键忽略/ready=enabled&&模型在位(ModelStore 简版)/F64 测试面更新。
- [ ] S3: 调用接线 — LlmStreamClient 端点取自 EngineManager(随机端口+模型路径启动参数);未就绪自解释错误;domain 契约零改验证。
- [ ] S4: 真引擎集成冒烟 — tiny gguf fixture 资产进仓库;拉起/健康/最小 chat 往返/终止/后端回落。
- [ ] S5: 随包捆绑工程面 — llama-server.exe 进 Windows 构建与安装包(CMake/release);全门(test/analyze/server 零 diff)。

## 非目标(Non-goals)

模型下载管理(F67);加载动效渲染与状态卡 UI(F65);GPU 参数调优(design);多模型切换(backlog);写操作(sprint-4)。
