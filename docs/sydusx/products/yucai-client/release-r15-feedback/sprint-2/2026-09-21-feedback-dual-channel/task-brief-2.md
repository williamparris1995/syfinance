# Task Brief — F42-T2 client 侧:TDD(表单+路由+降级+入口改造)

## 既有设施(T1 已产 + 房内,复用第一)

- **pb stub(T1 已生成)**:`yucai/client/lib/proto/feedback/v1/`(pb/pbenum/pbjson/pbgrpc)——`FeedbackServiceClient.submitFeedback`,`SubmitFeedbackRequest{type[FeedbackType.ISSUE/IDEA/OTHER], body, contact, diagnostics{appVersion, platform, accountMode, themeMode}}`,`SubmitFeedbackResponse{id}`。
- **stub 构造先例**:`lib/binding/data/grpc_offline_sync_port.dart`(`grpc.SyncServiceClient(channel)` —— GrpcClient 持通道+client 侧 AuthInterceptor)。**侦察 AuthInterceptor 对无 token(guest)的容忍性**:容忍→直接用 GrpcClient;不容忍→匿名 stub 走独立 channel 构造(两路设计已备,自行判断并在报告说明)。
- **F41 设施(全复用)**:`lib/core/feedback/feedback_launcher.dart` —— FeedbackDiagnostics(4 字段白名单)/FEEDBACK_EMAIL/emailSource/launchUrlFn/clipboardWriter 静态缝/launchFailedCopied 剪贴板降级;SessionModeTracker 账户模式;三入口(app_shell 侧栏行+底栏第 8 项/settings _NavRow)现接 `FeedbackEntry.launch(context)` 直跳。
- **connectivity**:`core/connectivity/connectivity_gateway.dart`(online 流,OfflineBadge 消费先例)。
- **原型契约(视觉/交互/文案事实源)**:`docs/sydusx/products/yucai-client/prototype/v4/`(design-system.md 复用声明+Flutter 映射;ui/feedback-form.html 可交互演示)。类型 radio 卡(icon+label 选中 accent 描边/软底,照 F33 _RadioCard 形态)、正文 1000 计数、联系 100、只读诊断头、四通道状态条。
- **测试挂点**:`test/core/feedback/feedback_launcher_test.dart`(扩展)+ 新 dialog/service 测试;`test/app/widgets/app_shell_test.dart`/`test/settings/presentation/settings_page_test.dart`(F41 入口断言需随改造更新:点击→表单出现,替代直跳断言)。

## 任务

1. **`lib/core/feedback/feedback_form_dialog.dart`(新)**:`FeedbackFormDialog`(AlertDialog 照原型 v4):类型三选(radio 卡行)/正文多行(1..1000,计数器,超限禁提交)/联系方式(≤100,选填)/只读诊断头(4 行+隐私 caption,数据来自 FeedbackDiagnostics 采集[F41 SessionModeTracker+Theme.brightness+PackageInfo 超时降级先例]);状态机:idle→submitting(按钮 spinner 禁闭)→success(「已提交,感谢反馈」toast 后自关)→failed/rateLimited(**对话框不关,内容不丢**,SnackBar 双动作:重试=原数据再提交/改用邮件=走离线 mailto 路径)。文案照原型(中文)。
2. **`lib/core/feedback/feedback_submit_service.dart`(新)**:`FeedbackSubmitService.submit(FeedbackForm f, {deps 注入缝:stub 构造 fn/connectivity/mailtoFn…}) → SubmitOutcome{uploaded(id)/mailed/rateLimited/failed}`:
   - connectivity.online(读一次快照即可)→ gRPC 提交(超时 10s;ResourceExhausted→rateLimited 变体;其余→failed);
   - 离线 → mailto 路径(F41 launcher 扩展);FEEDBACK_EMAIL 缺省+离线 → 返回 emailMissing 变体(UI 提示未配置,沿 F41 文案)。
3. **`feedback_launcher.dart` 扩展**:mailto 正文组装升级 —— subject「御财反馈-<类型中文>」;body = 正文+联系(有则「联系方式:…」)+空行+诊断头 4 行;**编码后长度 >1800 字符 → 截断正文尾部+追加「(过长已截断,完整内容已复制)」+clipboardWriter 写全文**(截断计算按 percent-encoded 长度,单测钉边界)。
4. **三入口改造**:`FeedbackEntry.launch(context)` 从直跳改为 `showDialog(FeedbackFormDialog…)`(app_shell/settings 两处调用点签名不变,零布局改动)。
5. **测试**:
   - `feedback_submit_service_test.dart`(新):online→stub 被调/offline→mailto 被调/stub 抛错→failed/ResourceExhausted→rateLimited/超时→failed/重试原数据(failed 后再 submit 同一 form)。
   - `feedback_launcher_test.dart` 扩展:带表单字段的 mailto 组装(类型主题/联系行);截断边界(构造编码后 >1800 的正文 → subject+截断标记+剪贴板全文;≤1800 不截断)。
   - `feedback_form_dialog_test.dart`(新):渲染(三类型卡/计数器/诊断头 4 行)/未选类型或空正文禁提交/超长禁/提交成功自关/失败对话框仍开+内容保留。
   - F41 入口测试更新:三入口点击 → `FeedbackFormDialog` 出现(找「意见反馈」标题)。
6. **回归门**:`flutter test` 全量 + `flutter analyze`(≤439 基线;新增 feedback dart stub 的既有 warning 不计入——若基线因此超,报告实际数与构成)+ `make client-e2e`(yucai/ 下;最低要求全绿不回归;可裁量加一条反馈表单 e2e[guest 本地模式表单打开/提交走降级链 UI 断言],做不了说明原因不硬凑)。
7. **T3 收尾**:`docs/.../2026-09-21-feedback-dual-channel/feedback-ops.md`(新)—— 运维面:SQL 查询现成语句(SELECT * FROM feedbacks ORDER BY created_at DESC LIMIT 50,按 type 过滤示例)/限流常量位置与调整(feedbackRatePerMin)/匿名端点豁免说明(middleware/auth.go anonymousMethods)。

## 约束

**禁止 git stash/checkout/restore/commit**;只动:lib/core/feedback/**+app_shell.dart+settings_page.dart+test/{core/feedback,app,settings}**+docs feature 目录;English 注释(用户可见文案中文照原型);零裸色(R8 令牌);pb stub 只用不改。GOCACHE 若报 Access denied 用 `C:/Users/BuHiYo-001/AppData/Local/go-cache-r15`(T1 同款环境项,client 侧一般不涉及)。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r15-f42/yucai/client`(命令);文档在 worktree 根 docs/。
完成后报告:改动文件清单、每测试文件 RED→GREEN 证据、AuthInterceptor 容忍性侦察结论与选择、全量 flutter test/analyze/client-e2e 数字、e2e 加测裁量说明、偏离简报之处。BLOCKED 即停。
