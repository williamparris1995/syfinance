# Task Brief T4 — 真引擎集成冒烟(fixture 选型+集成测)

## 工作区与铁律

- worktree `.claude/worktrees/r22-f66`(T1-T3 已合入,HEAD 137 绿)。shell 先 cd worktree 根。
- 不碰 server/F46/生产逻辑(除非集成测暴露真缺陷——如实 FAIL 报告,勿自修生产码);改动=测试文件+fixture 资产+获取脚本+文档回填。
- 完成 `git commit`(`test(assistant): F66-T4 真引擎集成冒烟`)。

## 必读

1. `design.md`(ADR-6/LLD 冒烟段/Open Questions 两条待回填)+`spec.md`(NFR-1)
2. `lib/assistant/data/engine_manager_impl.dart`(被测编排;其注入缝在本测**不用**——冒烟就是真件)+`process_launcher.dart`
3. `lib/assistant/data/model_store_impl.dart`(模型路径语义)

## 任务

### 1. 获取真引擎(不入 git)

- 写获取脚本 `yucai/client/tool/fetch_engine.py`(或 .ps1,照仓内 tool/ 惯例):从 llama.cpp 官方 GitHub release 下载 **Windows Vulkan x64** 构建的 `llama-server.exe` 到 `yucai/client/tool/engines/llama-server.exe`(**版本钉死**:选当前最新稳定 release 的 build 号写死在脚本常量,附 sha256 校验);`.gitignore` 加 `yucai/client/tool/engines/`。
- 本机执行脚本落盘;`llama-server.exe --help` 校准 flag 名(对照 ADR-6 清单:`--host/--port/-m/-c/-ngl/--jinja/--no-webui`,以实测为准记录偏差)。

### 2. tiny fixture 选型(回填 design OQ)

- 优先候选:ggml-org 公开 tiny 测试模型(如 stories15M 级,~15-20MB,q8/q4 均可);确认可下载后落 `yucai/client/test/fixtures/models/`(此件**入 git**,测试资产);选型结论+来源 URL+大小回填 design.md Open Question 第一条。
- 若带 chat 模板的 tiny instruct 模型可得且 ≤20MB,优先之(可用 /v1/chat/completions);否则 base LM 也可——冒烟改用 `/v1/completions` 或原生 `/completion` 断言(设计已预此降级),回填注明。

### 3. 集成测试(`yucai/client/test/assistant/integration/engine_smoke_test.dart`)

- 前置:exe 与 fixture 在位,否则 `skip('engine assets not present — run tool/fetch_engine')`(skip-by-env:无资产自动跳过,有资产必跑)。
- 用**生产件**组装:ProcessLauncherImpl+真 exe+fixture 作 ModelStore(注入固定路径 fake 实现指向 fixture 文件)+EngineManagerImpl(真健康探测;exePath 缝指向 tool/engines)。
- 断言序列:state 转移 Stopped→Starting→Ready(超时 60s 预算,注释=CI 慢机余量)→一次最小推理往返(输入短 prompt 断言非空输出)→shutdown()→进程不存在(轮询 tasklist 或 pid 探测)→state==Stopped。
- **不断言**:具体 GPU/CPU 后端(回落行为不断言,ADR-6)、工具调用面(tiny fixture 无模板,sprint 真模型门验——design 已记)。

### 4. 文档回填

- `design.md` Open Questions:fixture 选型一条(来源/大小/端点形态)+引擎版本一条(脚本钉死的 build 号+sha256 前缀)。

## 验证门

`flutter test test/assistant/` 全绿(含冒烟在本机真跑通过——汇报贴冒烟用例输出摘要);analyze 零新增;`git diff yucai/server` 空;`git status` 确认 engines/ 未跟踪。汇报:fixture 选型结论/exe 版本/冒烟输出摘要/commit hash。
