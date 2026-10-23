---
feature: f66-engine-sidecar
status: confirmed
---

# F66 llama-server 边车管理 — spec

> R22 sprint-1 依赖序首票(2026-10-23 从 sprint-2 拉入,纯内嵌定案)。含 F64 provider 收窄返工(MODIFIES F64 spec FR-4)。

## ADDED Requirements

### Requirement: FR-1 引擎生命周期管理
- [ ] 系统 SHALL 内嵌管理 llama-server.exe:**懒启动**(助手启用后首次对话触发拉起,冷启显示 starting 态)、**闲置回收**(10 分钟无请求自动终止进程)、**app 退出强杀**(进程树终结)、**崩溃自动重启**(退避重试,单次会话上限 3 次,超限进 error 不再自试)、**健康探测**(轮询 /health 判定 ready)。

#### Scenario: 懒启动全转移
- GIVEN 助手已启用且模型就绪,引擎 stopped
- WHEN 首次对话请求到达
- THEN EngineState 依次发出 starting→ready,请求在 ready 后放行

#### Scenario: 闲置回收
- GIVEN 引擎 ready 且 10 分钟无任何请求
- THEN 进程被终止,状态回 stopped;再次对话重新走懒启动

#### Scenario: 崩溃重启与上限
- GIVEN 引擎进程异常退出
- THEN 按退避自动重启至 ready;连续 3 次失败后进 error(crashed)且不再自试,状态流可见

#### Scenario: 退出强杀
- WHEN app 关闭
- THEN llama-server 进程树被终结,无残留进程

### Requirement: FR-2 F64 provider 收窄(MODIFIES F64 spec › FR-4)
- [ ] AssistantConfig SHALL 收窄为 `{enabled, model}`:provider/baseUrl/apiKey 字段与 `assistant.provider/.base_url/.api_key` storage keys 全数退役(直改零迁移——F64 未随任何 tag 发版,已核实);ready SHALL = `enabled && 模型文件就绪`(经 ModelStore port);F46 报告 BYOK 配置不受影响。

#### Scenario: 收窄后 ready 语义
- GIVEN enabled=true 且模型文件在位
- THEN ready=true;模型缺失时 ready=false 且 EngineState 发 error(modelMissing)

#### Scenario: 旧键残留容忍
- GIVEN secure storage 存在 F64 期的遗留键
- THEN 读取忽略未知键,不抛错不迁移

### Requirement: FR-3 引擎状态 port
- [ ] 系统 SHALL 暴露引擎状态可订阅源(实装=ValueListenable<EngineState> 当前态缓存+转移通知,行为等价多播流,评审 T1-L1 订正措辞)(stopped/starting/ready/error(reason)),供 F65 消费;**starting 态 MUST 可供 F65 渲染引擎加载动效**(用户拍板 2026-10-23)。

#### Scenario: 状态可订阅
- GIVEN 任一时刻订阅状态流
- THEN 可观察到当前态与后续转移(多播不漏)

### Requirement: FR-4 调用接线
- [ ] LlmStreamClient 生产实现 SHALL 从 EngineManager 获取端点(127.0.0.1:随机空闲端口),启动参数含模型路径;agent loop 与 domain 契约零改动。

#### Scenario: 引擎未就绪错误语义
- GIVEN 引擎未 ready 时 loop 发起请求
- THEN 返回自解释中文错误(引擎未就绪)而非裸网络异常

### Requirement: NFR-1 真引擎集成冒烟
- [ ] SHALL 含一条真 llama-server.exe 集成测试(仓库内置 tiny gguf fixture):拉起→健康 ready→一次最小 chat 往返→终止;后端自动回落(Vulkan 不可用→CPU)不断言具体后端。

### Requirement: NFR-2 注入缝
- [ ] 进程启动(ProcessLauncher)与模型位置(ModelStore)MUST 为注入 port,单测零真进程零真模型。

### Requirement: NFR-3 English 日志
- [ ] 引擎管理日志 SHALL 为 English 结构化(拉起/退出/重启/健康),无 CJK。

### Requirement: NFR-4 随包捆绑
- [ ] llama-server.exe SHALL 进 Windows 构建产物与安装包(CMake/release 工程),随 app 分发。

### Requirement: NFR-5 server 零改动
- [ ] git diff yucai/server MUST 为空。

## Feasibility(裁决)

- **technical 可行**:llama.cpp 边车模式为调研定案(MIT 可再分发);进程管理 dart:io;唯一硬点=Windows 进程树终结(taskkill /T)与端口分配,均有惯例解。
- **economic 可行**:exe ~几十 MB 进安装包;tiny fixture ~几 MB 进仓库。
- **operational 可行**:懒启动+闲置回收约束内存足迹(峰值 3-3.5GB 仅对话期间)。

## Out of scope

- 模型下载/存储/版本管理 — owner: F67 — excluded because: 依赖序;本票 ModelStore port 只做「路径+在位检查」简版实现。
- 引擎加载动效渲染 — owner: F65 — excluded because: F66 只供 starting 态;动效是 UI(F65 浮层,design.md 已补备注)。
- Vulkan/GPU 参数与 ctx 大小调优 — owner: F66 design — excluded because: 实现细节非需求;冒烟测覆盖回落行为。
- 引擎状态卡/FAB UI — owner: F65 — excluded because: 消费面归 UI 票。
- 多模型切换 — owner: backlog — excluded because: v1 单模型 Qwen3-4B。

## Grill record

- 引擎内存策略 — challenged: 懒启动+闲置回收 vs 启动常驻(3-3.5GB 常驻代价) — defended: 用户按推荐 A 并加码「启动时需要显示加载动效」→ starting 态升格 FR-3 硬需求,闲置 10 分钟回收。
- 真引擎集成冒烟 — challenged: mock-only(单测干净)vs 进一条真 exe+tiny fixture 冒烟 — defended: 用户同意纳入——真实二进制兼容性(进程/健康/参数/后端回落)在 F66 钉死,不留到 F65 联调。
- F64 收窄零迁移 — challenged: storage keys 直改是否有存量用户破坏 — defended: 事实核实——F64 合 main 后未随任何 tag 发版(v1.1.1 为最后发版),直改+旧键忽略容忍即可。
- 整 spec 一致性 — challenged: 收窄与 F65 引导态衔接/loop 零改可证 — defended: FR-2 ready 语义与 F65 spec「未就绪引导态」对齐;FR-4 明文 domain 契约零改动+未就绪错误语义场景。
