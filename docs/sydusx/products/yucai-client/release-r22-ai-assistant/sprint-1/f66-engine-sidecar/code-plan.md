# F66 code-plan

> /sydusx-execute 2026-10-23。批次:[T1] → [T2∥T3] → [T4] → [T5];SDD(子代理+两轴评审,照 F64 模式)。

- [ ] T1 domain 三契约(engine_state/engine_port/model_store_port)+F64 收窄返工(config 两字段/store 两键/ready 新语义/测试面重写)
- [ ] T2 EngineManagerImpl — 幂等 ensureReady(端口扫描→start→health 轮询 30s)/闲置 10min 回收/退避重启 1s·3s·9s×3/taskkill /T 树杀/ValueListenable 状态流;ProcessLauncher+时钟+端口扫描注入缝;fake 单测全转移覆盖
- [ ] T3 接线改造 — LlmStreamClient 端点取 EngineManager+ensureReady 兜底+未就绪中文错误;ModelStoreImpl 简版(路径存在性);AppExitPort 退出钩子→shutdown;DI 接线
- [ ] T4 真引擎冒烟 — tiny gguf fixture 选型(回填 design OQ)+拉起/health ready/基础 completion 往返/终止集成测;exe 本地获取不入 git(获取脚本属 T5);skip-by-env 标记
- [ ] T5 捆绑工程+全门 — llama-server.exe 获取脚本(版本钉死记档回填 OQ)+windows runner 资产接入安装包;全量门(test 全绿/analyze 459/server 零 diff)+需求覆盖表
