# Design — F42 反馈双通道:统一表单+在线 server 上传/离线邮件

> R15 sprint-2 · 2026-09-21 · design 产出。spec 见 [spec.md](spec.md)(grill 四决策+三事实核验);跨产品票(server+client)照 F36 先例。

prototype: v4(用户确认 2026-09-21;feedback-form.html 双主题四通道状态演示;类型 radio 卡沿 v3 定稿形态,零新令牌)

## Context

F41 mailto 直跳已上线;本票加 server 匿名直传通道与统一表单,提交时按 ConnectivityGateway 在线判定路由;离线/失败走 mailto(表单内容并入正文)。

## Goals / NonGoals

**Goals**:FR-1~FR-7(spec)。**NonGoals**:scope boundary 6 排除项(spec 既定)。

## Decisions(ADRs)

- **ADR-1 server 模块 = `internal/feedback` 照 backup 范式**:hexagonal(adapter/driven/repository + adapter/driving/grpc + application + domain + ent/schema);ent `Feedback` 表**全局无租户列**(匿名端点语义):type/body/contact/app_version/platform/account_mode/theme_mode/created_at,diagnostics 拆 4 列(SQL 查询友好);落库后 `slog.Info("feedback submitted","id",...,"type",...)`(English);wire_gen.go 手改接线(房约,不跑 CLI)。*挑战:diagnostics 存 JSON 列?拆列查询/索引友好,列数 4 固定(白名单冻结)无演化负担。*
- **ADR-2 匿名放行 = auth 拦截器 method allowlist**:既有认证拦截器加豁免常量集(`/feedback.v1.FeedbackService/SubmitFeedback` 唯一成员);其余 RPC 认证零变化(NFR-2)。实现侦察既有拦截器文件后落地,机制本条锁定。
- **ADR-3 防滥用 = app 层 per-IP 限流 + 字段限长**:in-memory token bucket(优先 `golang.org/x/time/rate` 若已在依赖树,否则手写 ~30 行,零新依赖);阈值 **5 次/分钟/IP**(具名常量);body ≤1000 字符/contact ≤100(与 client 同步);超限返回 `RESOURCE_EXHAUSTED`,client 变体提示。*挑战:gRPC max recv size(默认 4MB)够不够?app 层限长才是校验语义(错误信息可读),传输层尺寸是兜底,两者并存。*
- **ADR-4 proto `feedback/v1` + 契约 bump**:`SubmitFeedbackRequest{type(enum issue|idea|other), body, contact, diagnostics{app_version, platform, account_mode, theme_mode}}` → `SubmitFeedbackResponse{id}`;yucai-api 契约新增 vN+CURRENT 移动(design 定版号,execute 落);`make gen-dart` regen(client)+ server 侧 go 生成(照 Makefile proto target);**sync.pbjson.dart F13 手工补丁 regen 后重套 + 全量 pb diff 核验**(预期仅 feedback 新文件+sync.pbjson 补丁,其余零漂移)。
- **ADR-5 client 结构 = core/feedback 扩展三件**:`FeedbackFormDialog`(AlertDialog,照 prototype v4 字段/状态)+ `FeedbackSubmitService`(提交路由:在线→gRPC stub[GrpcClient 通道,照 grpc_offline_sync_port 构造 stub 先例;guest 无 token —— 侦察 client AuthInterceptor 无 token 容忍性,不容忍则匿名通道独立构造]/离线→mailto)+ `FeedbackEntry.launch` 改唤表单(F41 三入口不动)。注入缝照 F41(emailSource/launchUrlFn/clipboardWriter + 新 grpcStub/connectivity 可注入)。*挑战:表单放 settings 模块?core/feedback 已是 F41 归属(ADR-1 复用),app/settings 两消费方同构。*
- **ADR-6 限长与截断数值**:body 1000 字符(client 计数器+server 校验双层);contact 100;**mailto 编码长度 >1800 字符即截断正文并附提示+完整内容进剪贴板**(F41 剪贴板机制复用)。
- **ADR-7 prototype: v4**(design-system.md 复用声明+Flutter 映射;用户确认)。

## HLD(单元 + 依赖方向)

```
server:
  yucai/proto/feedback/v1(新)→ 生成 pb(server go + client dart)
  internal/feedback/{domain,application,adapter/driven/repository,adapter/driving/grpc,ent/schema}(新,照 backup)
  auth 拦截器 allowlist(豁免点,1 常量 + 1 判断)
  wire_gen.go 手改接线
client:
  core/feedback/feedback_form_dialog.dart(新,UI)
  core/feedback/feedback_submit_service.dart(新,路由+降级)
  core/feedback/feedback_launcher.dart(扩展:mailto 正文组装带表单字段+截断)
  app_shell.dart / settings_page.dart(入口改唤表单,不改布局)
contract: portfolio/contracts/yucai-api/(bump vN + CURRENT)
依赖:client core/feedback → proto stub + core/connectivity(既有);server feedback → ent/sqltx(既有 port);无跨 feature 新边。
```

## LLD(关键单元)

**server internal/feedback**
- ent schema:`Feedback{id auto, type string(enum 校验 domain 层), body string, contact string(default ""), app_version/platform/account_mode/theme_mode string, created_at time}`;migrate 自动。
- domain:`SubmitFeedback(cmd)` 校验(type 枚举/body 1..1000 rune/contact ≤100)+ 返回实体。
- application:落库 + `slog.Info("feedback submitted", "id", id, "type", t)`。
- grpc handler:映射校验错误(InvalidArgument)/限流(RESOURCE_EXHAUSTED)。
- limiter:per-IP(peer addr)token bucket,5/min 具名常量;并发安全(map+mutex)。

**client core/feedback**
- `FeedbackFormDialog`:AlertDialog<FeedbackResult?>;字段与状态机照 prototype v4(类型必选/正文 1..1000 计数/联系 100);提交中禁闭;成功「已提交,感谢反馈」后自关;失败/限流 → SnackBar 双动作(重试=再次 submit 原数据;改用邮件=走离线路径),对话框不关(内容不丢)。
- `FeedbackSubmitService.submit(FeedbackForm f, deps) → SubmitOutcome{uploaded(id) | mailed | rateLimited | failed(err)}`:connectivity.online(guest 与绑定同路,匿名 stub)→ grpc;离线 → mailto。超时 10s。
- mailto 扩展:subject「御财反馈-<类型>」;body = 正文+联系方式+诊断头 4 行;编码长度 >1800 截断正文尾部加「(过长已截断,完整内容已复制)」+Clipboard 写全文。
- 三入口:`FeedbackEntry.launch(context)` 从直跳改为 `showDialog(FeedbackFormDialog)`(窄屏/宽屏/设置页同源)。

**测试**
- server 集成测(照 backup 集成测形态):提交落库(字段齐)/校验拒绝(type 非法/body 空/超长)/限流(第 6 次 RESOURCE_EXHAUSTED)/**匿名可达(无凭证 metadata 调用成功)**/auth 其余 RPC 仍要求凭证(放行面回归)。
- client 单测:路由(online→stub 被调/offline→mailto 被调)/失败→failed+重试原数据/限流变体/mailto 截断边界(构造超长正文断言截断+剪贴板全文)/表单校验(空类型禁提交/超长禁)。
- widget 测:表单渲染(类型卡/计数器/诊断头)/选择与启用逻辑/提交后状态条;三入口唤表单(改 F41 既有断言:点击→表单出现)。

## Risks

| 风险 | 缓解 |
|---|---|
| proto regen 全量跑引入生成物漂移(F13 补丁/生成器版本) | regen 后全量 pb diff:预期仅 feedback 新文件+sync.pbjson 尾部;异常漂移即停查生成器版本 |
| client AuthInterceptor 无 token 容忍性未知 | execute 先侦察;不容忍则匿名 stub 走独立 channel 构造(设计已备两条路) |
| 匿名端点滥用(公网暴露) | ADR-3 限流+限长;日志带 peer 可追溯;阈值具名常量可调 |
| mailto 截断边界(编码长度计算) | 单测钉死(中文 9x/字符近似已建模,F41 编码断言复用) |
| server 升级面(DB 迁移) | ent 自动 migrate;新增表无破坏;回滚=还原提交 |

## Migration

server:新表 ent 自动迁移,无数据迁移。client:发布随 R15 发版(server 需先于/随 client 部署 —— 匿名端点 404 时 client 走 failed 降级链,不阻塞)。

## Open Questions

无(spec+design 决策全拍板;client AuthInterceptor 容忍性为实现期侦察项,两路已备)。
