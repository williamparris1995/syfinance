---
feature: f67-model-management
status: confirmed
---

# F67 端侧模型管理 — spec

> R22 sprint-1 依赖序末位能力票(2026-10-23 从 sprint-2 拉入)。ModelStore port 已备(F66),本票替换实现;UI 卡=F65 消费。sprint-1 收官票(F67 后 F65 execute)。

## ADDED Requirements

### Requirement: FR-1 模型下载
- [ ] 系统 SHALL 提供钉死模型(Qwen3-4B-Instruct-2507 Q4_K_M GGUF,~2.5GB;仓库+文件+sha256+字节数四钉死,照 fetch_engine 家法)的下载:HTTP Range 断点续传(部分文件 `.part` 保留,重启续传)、实时进度(receivedBytes/totalBytes/bytesPerSec)、暂停/恢复/取消、完整 sha256 校验(不匹配→error,不落地)、临时文件+原子改名至 ModelStore 路径。

#### Scenario: 断点续传
- GIVEN 下载中断(暂停或 app 退出)留下部分 .part 文件
- WHEN 恢复下载
- THEN 以 HTTP Range 从已收字节续传,进度从断点继续,最终文件 sha256 校验通过落地

#### Scenario: 校验失败不落地
- GIVEN 下载完成但 sha256 不匹配
- THEN 状态 error(corrupt),目标路径无文件,.part 保留可整段重下

### Requirement: FR-2 下载状态流
- [ ] 系统 SHALL 暴露 `ValueListenable<ModelState>`(notDownloaded/downloading{receivedBytes,totalBytes,bytesPerSec}/paused/ready/error(reason)),供 F65 模型卡与浮层渲染。

#### Scenario: 状态转移可订阅
- GIVEN 任一时刻订阅
- THEN 可观察当前态与后续转移;ready 与 ModelStore.isReady() 一致

### Requirement: FR-3 存储/版本/占用/删除
- [ ] 系统 SHALL 提供版本信息(钉死清单常量派生)、磁盘占用查询、**删除模型**(释放磁盘回 notDownloaded;删除前 SHALL 自动 shutdown 引擎——联动 EngineManager,运行中不裸删)。

#### Scenario: 删除联动停引擎
- GIVEN 引擎 Running
- WHEN 请求删除模型
- THEN 先 EngineManager.shutdown() 再删文件,状态回 notDownloaded,引擎状态 Stopped

#### Scenario: 占用查询
- WHEN 查询磁盘占用
- THEN ready 时=文件实际字节数;下载中=已收字节;未下载=0

### Requirement: FR-4 下载源策略
- [ ] 下载 SHALL 官方源优先(HuggingFace Qwen 官方仓),失败/超时/404 自动回落 hf-mirror 镜像;双源同一 sha256 校验,来源切换对结果透明。

#### Scenario: 官方失败回落镜像
- GIVEN 官方源连接失败
- WHEN 触发下载
- THEN 自动改走镜像源完成下载,sha256 校验通过,状态无感切换

### Requirement: NFR-1 注入缝与集成测
- [ ] HTTP 客户端 MUST 注入缝(单测零真网络);SHALL 含 loopback 集成测覆盖 Range 续传/暂停恢复/取消/校验失败四场景。

### Requirement: NFR-2 English 日志
- [ ] 下载/删除/校验日志 English 结构化,无 CJK。

### Requirement: NFR-3 server 零改动
- [ ] git diff yucai/server MUST 为空。

## Feasibility(裁决)

- **technical 可行**:dart:io HttpClient+Range 标准件;F66 冒烟已验模型加载路径。
- **economic 可行**:零新依赖;2.5GB 下载为用户一次性成本(镜像回落保可达)。
- **operational 可行**:断点续传+sha256 防半包;删除联动防运行中裸删。

## Out of scope

- 模型管理卡 UI/浮层渲染 — owner: F65 — excluded because: 状态流消费面归 UI 票(v19 已拍板形态)。
- 自动触发下载(首次启用自动下) — owner: F65 — excluded because: 触发时机是 UX 决策(F65 卡引导按钮)。
- 多模型切换/模型清单管理 — owner: backlog — excluded because: v1 单模型(F66 拍板);版本升级=换钉死常量重下。
- sha 校验失败自动重试次数/超时参数 — owner: F67 design — excluded because: 实现参数非需求。
- 下载限速 — owner: backlog — excluded because: 无现实诉求记录。

## Grill record

- 下载源策略 — challenged: 镜像优先(国内网络现实)vs 官方优先 vs 仅镜像 — defended: 用户拍 **B=官方优先+失败/404 自动回落 hf-mirror**(尊重上游,回落保可达;sha256 钉死双源同验)。
- 删除功能 v1 取舍 — challenged: 含删除(联动停引擎细节)vs 不含(卡上死数,清磁盘靠裸删文件) — defended: 用户同意含——停引擎→删文件→回引导态;释放 2.5GB 是真实需求且实现小。
- 整 spec 一致性 — challenged: 与 F66/F65 衔接 — defended: ModelStore port 不变(F66 简版实现退役换绑)/状态流形态照 EngineState ValueListenable 家法/ready 语义与 isReady() 互证场景钉死。
