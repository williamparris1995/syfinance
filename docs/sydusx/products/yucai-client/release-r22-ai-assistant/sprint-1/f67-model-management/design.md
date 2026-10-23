# Design: F67 端侧模型管理

prototype: none —— 无 UI 单元(ModelState 状态流供 F65 卡/浮层消费)。

## Context

- spec:[spec.md](spec.md)(FR-1..4/NFR-1..3,质询两决策:官方优先回落镜像/含删除);F66 ModelStore port 与 EngineManager 已合 main(70bb5988)。
- 家法事实:pubspec 既有 `crypto ^3.0.3` 直依(sha256 流式零新依赖);dart:io HttpClient 为 F46/F66 既有惯例;四钉死清单=fetch_engine.py 先例。

## Goals / Non-Goals

- **Goals**:下载器全能力(Range 续传/进度/暂停恢复取消/校验/原子落地/源回落)+ModelState 流+版本占用删除(联动停引擎)+ModelStore 换绑。
- **Non-Goals**:照 spec Out of scope(UI/自动触发/多模型/限速)。

## Decisions(ADRs)

- **ADR-1 下载器=手写 dart:io,零新依赖** — HTTP Range 续传是无协议怪癖的标准件(对比 F64 SSE 才需要 openai_dart);F46 llm_http/F66 健康探测均手写惯例。alternatives:http 包(已为传递依赖,升直依无必要)/dio(引全家桶)。grill 承接:F64 时用户问过「有没有优秀第三方库」——本票下载器简单度不足以抵依赖面。
- **ADR-2 ModelManager 双面** — `@LazySingleton(as: ModelStore)` 同时实现 ModelStore(port 不变,F66 简版实现退役删除)+新 port `ModelManagerPort`(download/pause/resume/cancel/delete/state/diskUsage/modelInfo);DI 换绑一行。
- **ADR-3 .part 协议** — 目标路径旁 `<name>.gguf.part`;恢复时 stat 已收字节→`Range: bytes=<n>-`;完整后流式 sha256(crypto)比对→原子 rename;不匹配→删 .part?**不删**(spec 场景:.part 保留可整段重下;corrupt error 态给用户重试,重试=删 .part 从零)。
- **ADR-4 源回落=URL 模板两枚** — 官方 `https://huggingface.co/<repo>/resolve/main/<file>` 与镜像 `https://hf-mirror.com/<repo>/resolve/main/<file>`(同构,仅域名差);失败判定=连接错/404/416;回落仅一次(镜像再败→error);仓库/文件/sha256/字节数四钉死常量单点。
- **ADR-5 删除联动=await EngineManager.shutdown() → 删 .gguf 与 .part → notDownloaded** — shutdown 幂等(F66);删除时若正在下载→先 cancel。
- **ADR-6 进度节流** — 进度 ValueNotifier 更新 ~200ms 节流(防 2.5GB 流每 chunk 触发 UI 重建风暴);速度=滑动窗(design 参数,执行期可调)。
- **ADR-7 ModelState=sealed 五态+值相等** — 照 EngineState 家法(toString 全 ASCII);downloading 携带 {receivedBytes,totalBytes,bytesPerSec}。

## HLD

```
lib/assistant/
  domain/
    model_state.dart       // sealed ModelState 五态
    model_manager_port.dart// ModelManagerPort(download/pause/resume/cancel/delete/state/diskUsage/modelInfo)+钉死清单常量 ModelManifest
  data/
    model_manager_impl.dart// @LazySingleton(as: ModelStore) 双面实现;下载编排/校验/删除联动
    http_downloader.dart   // 注入缝:abstract ModelHttpClient{get(url, {rangeFrom}) → Stream<List<int>>+总长};dart:io 生产 impl
```

依赖:data→domain(+EngineManager port 删除联动);F65 消费 ModelManagerPort.state。

## LLD

- **download()**:状态守卫(ready→no-op;downloading→no-op;paused→resume)→.part stat→Range 请求(回落链)→chunk 循环:写文件 append+sha256 流式更新+进度节流→EOF:sha 比对→rename→ready;任何异常→error/paused 语义(用户暂停=paused,网络断=error 可 resume)。
- **pause/cancel**:pause=断开流保 .part→paused;cancel=断流+删 .part→notDownloaded。
- **resume**:paused→download()(自动走 Range)。
- **delete()**:downloading→cancel 先;await engineManager.shutdown();删两文件→notDownloaded。
- **isReady()/modelPath()(ModelStore 面)**:ready 态=文件在;notDownloaded/downloading→null/false——F66 引擎侧 ensureReady 的 modelMissing 前置语义无缝衔接。
- **集成测(loopback)**:假 HTTP 服务(支持 Range 的分块服务端)四场景:①中断续传(服务端记录第二次请求含 Range: bytes=n-)②暂停→.part 在→恢复完成 ③取消→.part 无 ④sha 不符(服务端故意改字节)→error(corrupt)+无落地。

## Risks / Trade-offs

- [大文件写盘断电] → .part 协议天然容断;rename 原子。
- [镜像源文件漂移] → sha256 四钉死,不匹配不落地。
- [进度风暴] → 200ms 节流(ADR-6)。
- [官方源慢(SLF 慢启动)] → 失败判定带连接超时(参数执行期定);回落一次。

## Migration Plan

F66 ModelStoreImpl 删除,DI 换绑 ModelManagerImpl;零数据迁移(模型文件路径语义不变)。回滚=恢复 F66 简版实现。

## Open Questions

- 连接超时/重试参数精确值(执行期 S1 定,回填)。
