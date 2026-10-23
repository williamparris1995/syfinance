# F67 code-ledger

> /sydusx-execute 任务台账(task done / fix-rounds / rulings)。批次:T1→T2→T3 串行;T1/T2/T3 评审待控制器安排,本表先落事实。

- **T1 模型域契约 ✅ done**(commit 1d6d4daa;model_state.dart sealed 五态+值相等+ASCII 9 测 / model_manager_port.dart ModelManagerPort+ModelManifest 四钉死 6 测,共 15;analyze 459 零新增;server diff 空)。
- **T2 模型管理实现+换绑 ✅ done**(commit 5d844f5d;http_downloader[ModelHttpClient 缝+IoModelHttpClient dart:io impl]+ model_manager_impl 双面实现 + DI 1m 换绑 + F66 ModelStoreImpl 退役删除[三态语义由承接测照搬] + F66 wiring capstone 改固定路径 fixture fake;mock 单测 19)。
- **T3 loopback 集成+全门+覆盖表 ✅ done**(commit 见 git log;`test/assistant/integration/model_download_integration_test.dart` 6 用例 = spec NFR-1 四场景 + FR-4 回落 + Range 忽略防御佐证;真 IoModelHttpClient 打真 HttpServer[HttpOverrides 域名重定向双假源,生产码零改动];全门:flutter test **3031 全绿**(+1 自跳过=F66 engine_smoke 引擎夹具不在场自跳,与本票无关;基线 3025+1 skip,本票 +6)/ flutter analyze **459 == 基线零新增** / `git diff main -- yucai/server` **0 字节**;集成测本机真跑 5 连绿)。

## T1 查证修正记档(执行期裁决,2026-10-23)

- 简报原定仓 `Qwen/Qwen3-4B-Instruct-2507-GGUF` 不存在(HTTP 404;Qwen 官方组织未发布任何 2507 系列 GGUF,经 HF API `?author=Qwen&search=GGUF` 检索证伪)→ 按简报「执行期以官方仓实名为准」采用 base_model 指向 `Qwen/Qwen3-4B-Instruct-2507` 的权威量化仓 **`unsloth/Qwen3-4B-Instruct-2507-GGUF`**(Qwen 社区默认分发点)。
- file/sha256/totalBytes 取自 HF API LFS 元数据(`Qwen3-4B-Instruct-2507-Q4_K_M.gguf`:size=2497281120,lfs.sha256=`3605…e597`)并经直链 HEAD 三证交叉验证(X-Linked-Size / CDN content-length / LFS ETag==sha256 同值)。
- 源码注 `TODO(F67-T3): 发布前首下实测复核` —— 2.5GB 真件流式 sha 复核属**发布日冒烟**(测试环境不可复现 2.5GB 下载;本 T3 集成测以 64KB 夹具+真 sha256 验证校验机制本身),TODO 保留移交发布前清单,非遗漏。钉死值另有 T1 契约测 `pins repo/file/sha256/totalBytes to the verified upstream` 漂移即红。

## T2 LLD 三偏差记档(T3 落档)

| # | 偏差 | 内容 | 测试佐证 |
| --- | --- | --- | --- |
| 1 | manifest 构造缝 | design/LLD 未列 manifest 注入;T2 构造加 `ModelManifest? manifest`(缺省 kModelManifest 直通)—— 生产 2.5GB 钉死 sha 测试不可复现,单测/集成测注入 64KB 同形小清单;生产缺省不变 | T2 mock 单测全组 + T3 全 6 用例(manifest 注入) |
| 2 | Range 防御 | LLD 只写「Range 请求续传」;T2 补:服务器忽略 Range 仍回 200 全量 → 从零重写(append 会错位 → corrupt 死循环防御) | T3 `Range 忽略防御…`(真 HTTP 佐证;T2 mock 未覆盖此分支,T3 补位) |
| 3 | 磁盘态恢复 | design LLD 未明写;T2 构造期从磁盘恢复状态(目标在 → ready;.part 在 → paused 带断点基数;首个异步口 await 铲平)—— FR-1「重启续传」的 app 重启面 | T2 `磁盘重启初始化` 两测 + T3 Range 忽略防御前置断言(残留 .part → 构造即 paused) |

## T3 集成测装具要点(记档)

- **HttpOverrides 域名重定向**:ModelManagerImpl 源 URL 模板硬编码 `huggingface.co`/`hf-mirror.com`(ADR-4 单点,无 URL 注入缝)→ 测试经 `HttpOverrides.global` 把 IoModelHttpClient 内部 `HttpClient()` 工厂创建的客户端重定向:huggingface.co → 127.0.0.1:<官方假源端口>、hf-mirror.com → <镜像假源端口>(两端口双假源);生产码零改动,真 dart:io 栈(真 socket/真 Range 头/真 Content-Range 解析/真流断错)原样真跑。注:`HttpOverrides.global` 为 setter-only(无 getter),dispose 复位 null;本仓 lib/test 无其他使用方(grep 验证)。
- **bufferOutput 坑(本机实测钉死)**:dart:io HttpServer 默认 `bufferOutput=true`,`flush()` 不下刷内部缓冲 → 门控部分写(park 在 gate)客户端收不到首块(独立 probe 复现);假源统一 `bufferOutput=false` 逐块直送。
- **门控假源(暂停/取消确定性驱动,非 sleep 竞速)**:首块 4096B flush 后挂 gate → 客户端必处于 downloading 且 .part 恰 4096 字节;**截断假源(断流)**:Content-Length 承诺全段、只写前 N 字节后 `detachSocket().destroy()` 毁连接 → 客户端真流中断错误(回落+续传基数全真)。
- 与 T2 mock 单测互补关系:T2 验管理器编排(mock 响应形状受控),T3 验真 dart:io HTTP 语义(Range 头落线/206+Content-Range 解析/流中断错误传播/连接关闭);两层各自独立可跑,合覆盖 NFR-1。

## 需求覆盖对照表(T3 汇总;spec FR/NFR ↔ 测试)

测试根 `yucai/client/test/assistant/`(T1=domain 契约测,T2=data/model_manager_impl_test,T3=integration/model_download_integration_test)。

| 需求 | 场景 | 测试文件 | 用例名 |
| --- | --- | --- | --- |
| FR-1 模型下载 | 断点续传(Range 续传/进度从断点/落地) | `integration/model_download_integration_test.dart`(T3)+ `data/model_manager_impl_test.dart`(T2) | T3 `断点续传:官方中途截断+镜像 500 → error(network)+.part 保留;再 download() 官方收到 Range: bytes=<n>- → ready+文件 sha 对`(另断言镜像回落请求已带新基数)/ T2 `续传:.part 预置 100 字节 → 请求带 rangeFrom=100 且拼接正确` / T2 `磁盘重启初始化:.part 在 → 构造即 paused(断点续传基数)` |
| FR-1 模型下载 | 实时进度三元组+节流 | `data/model_manager_impl_test.dart` | `进度节流:节流缝=0 时每块更新 downloading(含首块强制)` / `进度节流:默认 200ms 时快速块被合并` |
| FR-1 模型下载 | 暂停/恢复/取消 | T3 + T2 | T3 `暂停恢复:门控假源首块后挂起 → pause()=paused+.part 在;download()=Range 续传 → ready(全程状态流转移序列)` / T3 `取消:downloading 中 cancel() → notDownloaded + .part 无`(真 socket 断流)/ T2 `暂停:pause 后状态 paused(received/total)+ .part 在;恢复走 Range 完成` / T2 `取消:cancel → notDownloaded + .part 无` |
| FR-1 模型下载 | 完整 sha256 校验,不匹配不落地+原子落地 | T3 + T2 | T3 `校验失败:同长度异内容 → ModelError(corrupt) + 无落地 + .part 留` / T2 `sha 不符:corrupt + 无落地 + .part 留` / T2 `corrupt 后重试:删 .part 从零整段重下(ADR-3)` / T2 `首下全流程:200 全量流 → ready + 文件内容正确 + ModelStore 面一致`(.part 消失=rename 落地)/ T3 断点续传用例同断言落地文件 sha == 钉死清单 |
| FR-2 下载状态流 | 状态转移可订阅/ready 与 isReady 一致 | T3 + T2 + `domain/model_state_test.dart` | T3 暂停恢复用例(全程状态序列:NotDownloaded→Downloading→Paused→Downloading→Ready,零 Error)/ T2 `状态守卫:downloading 中再 download() 不发起新请求` / T2 首下+删除用例(modelPath/isReady 随状态翻转)/ `model_state_test` `state carries current value; transitions reach subscribers` / `equal state re-set does not notify (value semantics dedupe)` |
| FR-3 存储/版本/占用/删除 | 删除联动停引擎(三态) | `data/model_manager_impl_test.dart` | `删除三态之一 notDownloaded:直过…` / `删除三态之二 downloading:先 cancel(断流删 .part)+ shutdown 联动` / `删除三态之三 ready:shutdown 被调 + .gguf 删除 + 回 notDownloaded(F65 消费)` |
| FR-3 存储/版本/占用/删除 | 占用查询四口径/版本清单派生 | `data/model_manager_impl_test.dart` + `domain/model_manager_port_test.dart` | `diskUsage 四口径:notDownloaded=0 / downloading=.part / paused=.part / ready=文件长` / `manifest getter 直通构造清单(生产缺省 = kModelManifest)` / port 测 `diskUsageBytes/manifest contract roundtrips` |
| FR-4 下载源策略 | 官方失败回落镜像,双源同验,无感切换 | T3 + T2 | T3 `官方源 500 → 回落镜像:双假源 URL 序 official→mirror,无感 ready(FR-4)`(两端口双假源 URL 序+同构路径+零 Range 首下+状态零 Error+内容对)/ T2 `官方失败回落镜像:第一源抛 → 第二源成功,两次请求,状态无感 ready` / T2 `双源皆败:ModelError(network)(.part 留可续传)` / T3 断点续传用例(截断流错 → 回落镜像带新基数,真流中断回落) |
| NFR-1 注入缝与集成测 | 单测零真网络 + loopback 四场景 | T2(mock)+ T3(真件) | T2 全 19 用例(_MockHttpClient 零真网络)+ T3 全 6 用例(真 HttpServer+真 IoModelHttpClient 四场景+回落+Range 忽略防御) |
| NFR-2 English 日志 | 结构化 ASCII 无 CJK | T2 + T3 + `domain/model_state_test.dart` | T2 `日志全 English 结构化(ASCII 门禁)` / T3 断点续传用例(`model download source failed` 等真路径日志逐行 ASCII)/ `model_state_test` `all states render ASCII-only, no CJK` |
| NFR-3 server 零改动 | 合并前验证(非测试:全门) | — | `git diff main -- yucai/server` 0 字节 + server 子目录 status 干净(T3 实测;每票全门复跑) |

> 漏项检查:spec ADDED 7 条需求(FR-1..4 + NFR-1..3)全部有对应测试/门,**零 BLOCKED**。FR-1「app 退出留 .part 重启续传」的构造期恢复面由偏差三承接(T2 磁盘重启两测);DI 手工换绑与 F65 消费面为组合根/下游票,按 code-plan 门以三条全门覆盖。
