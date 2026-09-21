# Spec — F42 反馈双通道:统一表单+在线 server 上传/离线邮件

> R15 sprint-2 · 2026-09-21 · analysis 产出。grill 四决策用户拍板(见 Grill record);三事实核验推翻原否决 server 收集的部分理由。

## 查证事实基线

- **proto 工具链就位**(原否决理由①不成立):`protoc.exe` 在 `go\bin`、WKT include `~/go/include/google/protobuf/` 齐、`protoc_plugin 25.0.0` 已装;F33 有 proto 变更先例(UpdateDebtRequest)。**注意:sync.pbjson.dart 尾部 F13 手工补丁 regen 后须重套**(AGENTS.md);`wire_gen.go` 手改不动 CLI。
- **server 模块范式**:扁平 `internal/{account,auth,backup,debt,...}`,照 holding/debt 四层范式;server 认证拦截器存在(auth),匿名端点需 per-RPC 放行机制。
- **client 设施**:ConnectivityGateway(R6 F,online 流,OfflineBadge 消费先例)做在线判定;F41 FeedbackEntry/FeedbackDiagnostics(4 字段白名单)/FEEDBACK_EMAIL 单点/剪贴板降级全部复用;三入口已就绪(F42 改唤表单)。
- **mailto URL 上限 ~2000 字符**(中文 percent-encode 后每字 ~9 字符):离线路径带表单正文必须截断守卫+完整内容剪贴板兜底。
- **跨产品票先例**:F36(client 票带 server 改动:RepaymentCashRecorder port+WithTx)。契约目录 `portfolio/contracts/yucai-api`(CURRENT 指针机制)。
- guest 语义:匿名端点(无租户归属,global 表);server 侧 English 结构化日志。

## Requirements

- **FR-1 统一反馈表单**:F41 三入口改为唤起应用内表单(对话框/页,design 定形态)——类型单选[问题|建议|其他]+正文多行(限长,server 侧上限 design 定)+可选联系方式(限长)+只读诊断头(4 字段白名单,续 F41);表单预校验(类型必选/正文非空限长);提交按钮按 FR-3 路由。
- **FR-2 server feedback 模块**:proto `feedback/v1` 新增 `SubmitFeedback`(匿名——不经 auth 拦截器;字段:type/body/contact/diagnostics{app_version,platform,account_mode,theme_mode});server 四层(domain[data 校验:body 非空限长/type 枚举/contact 限长]/data[ent feedback 表,无租户列,global]/transport/service);落库后打 English 结构化日志(`feedback submitted id=<id> type=<type>`);返回成功(含服务端 id)。
- **FR-3 提交时路由**(对用户透明):ConnectivityGateway 在线(绑定或 guest)→ gRPC `SubmitFeedback` 直传;离线 → mailto(表单四要素+诊断头并入正文;URL 编码后超 ~1800 字符即截断正文并附「完整内容已复制」提示+剪贴板写入完整内容)。
- **FR-4 失败降级链**(内容不丢):上传失败(超时/不可达/限流拒绝)→ SnackBar「上传失败」+双动作「重试」(表单原样重发)/「改用邮件」(走 FR-3 离线路径);表单保留已填内容直至成功或用户主动关闭。
- **FR-5 防滥用**(最轻机制):server per-IP 内存限流(token bucket,阈值/窗口 design 定)+请求体尺寸上限(超限拒绝);限流触发返回明确错误,client 提示「提交过于频繁,请稍后再试」(fix round 1:与原型/实现的短文案一致;「改用邮件」为旁置动作按钮,不在文案内)。
- **FR-6 隐私红线**:上行 payload(client→server)与 mailto 正文仅含 表单四要素+诊断头白名单,**零财务数据**;测试断言 payload 字段集恰为白名单。
- **FR-7 测试与门**:server 集成测(提交落库/校验拒绝/限流触发/匿名可达[无凭证])/client 单测(路由判定在线/离线/表单校验/失败降级不丢内容)+widget 测(表单渲染/类型选择/提交回调);门:`go test ./...` 全绿+`flutter test` 全绿+analyze 基线+`make client-e2e`(proto 变更过 server 门)。

## NFR

- **NFR-1 隐私**:FR-6 白名单双向(上行+落库字段同集);诊断头不扩字段(4 字段冻结,扩字段走新票)。
- **NFR-2 匿名安全面最小**:仅 `SubmitFeedback` 一 RPC 免认证,其余 RPC 认证语义零变化;限流+尺寸上限为该端点专属。
- **NFR-3 契约与工具链**:yucai-api bump 新版+CURRENT 移动(design 记版本);regen 后 sync.pbjson.dart F13 手工补丁重套并核验(diff 确认);wire_gen.go 手改照房约。
- **NFR-4 体验**:路由对用户透明(提交时自动判定);任何失败路径已填内容不丢;成功路径明确反馈(「已提交,感谢反馈」)。

## Scope boundary

| 排除 | 理由(grill 辩护 2026-09-21) |
|---|---|
| ListFeedback 管理端/RPC | 查看走 SQL(部署文档给出现成查询),反馈低频;backlog 不丢 |
| SMTP 转发邮箱 | server 新增 SMTP 配置/凭证/失败链,为低频反馈引入重运维件(用户否决) |
| 后台队列自动重传 | 个人应用低频,同步「重试+改用邮件」够;异步提交语义反而模糊 |
| 附件/截图 | F41 排除延续(隐私红线+mailto 天花板;server 线未来可议) |
| 反馈历史/回执(client 侧) | server 有落库但 client 不做「我的反馈」列表(F41 排除延续) |
| 绑定用户独立认证端点/租户归属 | 单一匿名端点最简;归属信息经 diagnostics.account_mode+可选联系方式表达 |

## Grill record

| 决策 | 挑战 | 定案 |
|---|---|---|
| 立项归属 | 新 release vs 追加 | R15 sprint-2/F42,跨产品票照 F36 先例(用户) |
| guest 语义 | 「在线」对 guest 意味着什么;匿名端点要付防滥用+无归属代价 | **匿名端点**——guest 在线也直传,反馈零门槛优先(用户,推翻推荐) |
| 表单形态 | server 通道必须有 app 内输入,触碰 F41「直跳」裁决 | **统一表单+提交时路由**——入口行为一致,离线 mailto 带正文(体验反超 F41 直跳);mailto URL 上限→限长+截断+剪贴板兜底(用户) |
| 上传失败降级 | 网关「在线」≠ server 可达;失败不能丢内容 | **重试+改用邮件**双动作,表单内容不丢(用户) |
| 反馈查看 | 「收了没人看」(原否决理由③) | **落库+English 日志+SQL 查看**;ListFeedback backlog(用户) |
| (事实)proto 工具链 | 原否决理由① | protoc/WKT/protoc_plugin 全就位+F33 先例——风险消解(核验) |
| (事实)F41「直跳」裁决 | 裁决输入已变(server 通道必须写) | 表单回归不构成矛盾——F41 依据是「当时无 app 内写诉求」(核验) |

## Feasibility

- technical ✓ —— 工具链就绪;server 模块照 holding/debt 范式可复制;ConnectivityGateway/FeedbackEntry/白名单全部复用;匿名放行需动 auth 拦截器(小面);sync.pbjson 补丁重套有 AGENTS.md 明示流程。
- economic ✓ —— 体量约 2-3×F41(server 模块+ent+集成测为主);无新外部依赖。
- operational ✓ —— 部署面=server 升级+DB 迁移(ent 自动);查看 SQL 文档化;回滚=还原提交(表新增无破坏)。
