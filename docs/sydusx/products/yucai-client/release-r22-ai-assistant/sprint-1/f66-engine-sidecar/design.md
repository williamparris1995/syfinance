# Design: F66 llama-server 边车管理

prototype: none —— 无 UI 单元(引擎状态流供 F65 消费;动效渲染=F65)。

## Context

- spec:[spec.md](spec.md)(FR-1..4/NFR-1..5);release 纯内嵌定案(2026-10-23);F64 地基已合 main;依赖序 F66→F67→F65。
- 调研事实:llama.cpp MIT 可再分发;`--jinja` 启用 GGUF 内置 chat 模板的原生 tool calling(Qwen3 模板即工具面);DirectML 未合入,GPU=Vulkan/CUDA 自动,llama-server 自身回落 CPU。

## Goals / Non-Goals

- **Goals**:EngineManager 全生命周期(懒启动/预热/闲置回收/强杀/退避重启/健康)+F64 收窄返工+LlmStreamClient 接线+真 exe 冒烟+随包捆绑。
- **Non-Goals**:模型下载(F67)/动效渲染(F65)/GPU 参数调优/多模型/写操作。

## Decisions(ADRs)

- **ADR-1 预热时机=浮层打开即预热(用户拍板)** — EngineManager.ensureReady() 幂等公开;F65 打开浮层即调(加载动效吸收冷启);LlmStreamClient 请求前兜底调。「开了没问」由闲置 10 分钟回收兜住。alternatives:纯请求触发(首问必等)。
- **ADR-2 端口=app 侧扫描随机空闲端口** — bind 试探后传 `--port`(llama-server 无 port:0);host 恒 127.0.0.1。
- **ADR-3 进程树终结=Windows `taskkill /PID <pid> /T /F`** — dart Process.kill 不递归;正常停止先 kill(pid) 等 2s 再 taskkill 兜底;app 退出钩子必走。
- **ADR-4 健康探测=GET /health 轮询 500ms,就绪超时 30s** — 模型加载余量;超时/异常计入重启退避(1s/3s/9s,上限 3 次)。
- **ADR-5 EngineState=sealed 四态+当前态缓存** — `{Stopped/Starting/Ready/Error(reason: modelMissing|crashed|startFailed)}`;broadcast 流+同步当前值(F65 双订阅不漏转移)。
- **ADR-6 启动参数=`--host 127.0.0.1 --port N -m <model> -c 4096 -ngl 999 --jinja --no-webui`** — `--jinja`=工具面必需;`-ngl 999`=GPU 自动尽力,CPU 回落由 llama.cpp 自身处理;flag 名以随包二进制 `--help` 实测为准,冒烟测钉死。冒烟用 tiny gguf fixture:断言拉起/health ready/一次基础 completion 往返/终止;**工具调用面不在冒烟断言**(tiny fixture 无工具模板),由 sprint 真模型门验。
- **ADR-7 ModelStore port 简版** — `{Future<String?> modelPath(); Future<bool> isReady()}`;实现=固定路径存在性(`%APPDATA%/yucai/models/qwen3-4b-instruct-q4_k_m.gguf`);F67 替换为下载管理实现,port 不变。
- **ADR-8 收窄实施** — assistant_settings 字段削减至 {enabled,model}+ready 重写(enabled&&ModelStore.isReady);store keys 改两键(旧键残留无害=读取端天然忽略);F64 ready 测试组重写(~16→~6);LlmStreamClient 端点/占位键改为引擎供给(baseUrl=EngineManager 端点,apiKey='sk-noauth' 内部占位保留——llama-server 不校验,openai_dart 需非空)。
- **ADR-9 捆绑=Windows runner 资产先例** — llama-server.exe 随 windows/runner 工程进构建与安装包(照 F24 WinSparkle/auto_updater 资产先例);exe 来源=llama.cpp 官方 release Vulkan 构建,版本钉死记档。

## HLD

```
lib/assistant/
  domain/
    engine_state.dart        // sealed EngineState 四态
    engine_port.dart         // abstract EngineManager {ensureReady(); shutdown(); ValueStream<EngineState> state; Uri? endpoint;}
    model_store_port.dart    // abstract ModelStore {modelPath(); isReady()}
  data/
    engine_manager_impl.dart // 生命周期编排(ProcessLauncher/时钟/端口扫描注入缝)
    model_store_impl.dart    // 简版路径存在性
    process_launcher.dart    // abstract ProcessLauncher{start/killTree}(dart:io 生产 impl+taskkill)
    llm_stream_client_impl.dart // 改:ensureReady 兜底+端点取 EngineManager
test/assistant/integration/  // 真 exe 冒烟(tiny fixture)
yucai/client/windows/        // 捆绑工程面
```

依赖:data→domain;LlmStreamClient→EngineManager+ModelStore;F65 后续消费 EngineManager.state。

## LLD

- **EngineManagerImpl.ensureReady()**:幂等;state==Ready→即返;Starting→等待既有 Future;Stopped/Error→扫描端口→Starting→launcher.start(args)→health 轮询→Ready(endpoint 对外);任何步失败→退避重启计数(1s/3s/9s×3)→Error(startFailed/crashed)。模型缺失前置检查→Error(modelMissing) 不起进程。
- **闲置回收**:每次 ensureReady/请求 touch 重置 10min Timer;触发→graceful kill(2s)→taskkill 兜底→Stopped。请求进行中不回收(以「流关闭」为界)。
- **退出钩子**:app 生命周期(AppExitPort 既有)→shutdown()(强杀);F66 接线。
- **冒烟测试**:fixture=tiny gguf(带基础 chat 模板,选型执行期定:官方 tiny 模型或 gguf 公开 fixture);断言序列 Stopped→Starting→Ready(≤30s)→completion("ping" 非空回复)→shutdown→进程不存在。跳过条件:CI 无 exe 环境(标记 skip-by-env,本机门必跑)。

## Risks / Trade-offs

- [llama-server flag 跨版本漂移] → 执行期以随包二进制 --help 校准;冒烟钉死;版本钉死记档。
- [杀软误报(无签名 exe)] → 已知发布风险(release 决策记);不改本票。
- [端口竞态(扫描后被占)] → 启动失败走退避重启(重扫端口);健康超时兜底。
- [「开了没问」白拉起] → 闲置 10min 回收兜底(ADR-1 拍板时明知)。
- [tiny fixture 选型不确定] → Open Question 回填;若无合适带模板 fixture,冒烟降级断言 /health+models 端点。

## Migration Plan

keys 直改零迁移(F64 未发版);回滚=删 assistant/data 引擎三文件+DI 行+windows 资产;LlmStreamClient 回退直连配置端点的 F64 形态(分支历史可溯)。

## Open Questions

- tiny gguf fixture 具体选型(执行期 S4 定,回填此处)。
- llama-server Vulkan 官方构建的精确版本号与下载管线(执行期 S5 捆绑时钉死记档)。
