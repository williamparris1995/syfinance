# Code Ledger — F42 反馈双通道

> execute 记账:task/轮次/裁定,流向 review。

## Tasks

- [x] T1 server 侧 —— proto feedback/v1(buf 定向 regen,F13 补丁重套零漂移)+ internal/feedback 四层照 backup 范式 + ent 全局表(无租户列)+ 匿名放行(anonymousMethods exact-match)+ per-IP 限流(5/min 手写零依赖)+ slog + wire 手改;集成测 4 场景 RED→GREEN
- [x] T2 client 侧 —— FeedbackFormDialog(原型 v4 契约)+ FeedbackSubmitService(双通道路由+四态 outcome)+ launcher 扩展(mailto 带表单字段+>1800 截断+剪贴板)+ 三入口改唤表单;单测/widget 测 RED→GREEN
- [x] T3 契约与运维面 —— yucai-api README 变更记录(F42 条目,纯新增向后兼容)+ feedback-ops.md(SQL/限流常量/匿名豁免面)

## 评审与修复轮

- **轮 0(两轴评审)**:PASS(零 HARD);1 MEDIUM + 4 LOW/NIT。
  - N-1 [MEDIUM|MISSING] 契约变更记录缺 F42 条目(NFR-3)→ **fix-1 修**(README changelog 照 F16-F18 惯例)
  - N-2 [LOW] feedback_kind 头注失准(宣称全无环 vs 文件级 TYPE 互引)→ **fix-1 修**(注释改准确:类级无环/文件级互引限本 feature)
  - N-3 [NIT] dialog 死三元 width → **fix-1 修**
  - N-4 [LOW] 限流文案 spec/原型/实现三方不一致 → **fix-1 修**(统一短文案+旁置按钮语义,spec+design-system 同步)
  - N-5 [LOW] diagnostics 4 字段 server 侧无限长(FR-5 兜底语义缺口)→ **fix-1 修**(MaxDiagRunes=64 哨兵+集成测 RED→GREEN)
- **T2 实现期正当偏离(评审裁断成立)**:
  - SnackBar.actions 在本机 Flutter 3.44.1 已删(仅单数 action)+ modal barrier 遮挡 → 失败/限流提示改**对话框内联失败条**(neg 软底+重试/改用邮件双按钮)——评审核 SDK 源码证实,且视觉更贴原型 .fail 形态
  - AuthInterceptor 无 token 容忍(guest 直连匿名端点,GrpcClient 复用,与 GrpcOfflineSyncPort 同构)
  - make proto 在 worktree 不可用 → buf 定向模板直跑(零漂移核验前后)
  - 服务注册在 wire_gen.go(main.go 不在文件白名单;handler 无 App 字段,注释自辩)
  - e2e 未加反馈专用用例(widget 24 测已覆盖降级链;e2e 在线通道必失败+本机几何不稳,flake 面大于收益)

## 门禁记录

- T1:go test ./... **67 包全绿**(-count=1 ×2;控制器复证 tests ok)
- T2:flutter test **1935 全绿**/analyze **436**(437 基线,零新增)/client-e2e **13/14 文件绿 + full_audit 失败**
- **full_audit 因果排除(控制器双点实验)**:main 树(无 F42)复跑 **+13 全绿**;F42 worktree 复跑 **+13 全绿** → 子代理运行期为瞬态几何状态(F30 窗口状态记忆/构建期 DPI 抖动),非 F42 因果;**14/14 全绿成立**
- fix-1 后:server feedback 5 集成测全 PASS(RED→GREEN 见报告)/client core/feedback 36 全过/analyze 436 持平
- 终态门(go 全量+flutter 全量+analyze+client-e2e 全量):见 test 门记录(下补)
- **test 门终态(fix-1 后 HEAD 全量重跑,控制器执行)**:go test ./... **67 包全绿**(-count=1)/ flutter test **1935 全绿** / analyze **436 ≤ 439** / make client-e2e **14/14 套件全过**(exit 0)。需求覆盖 11/11:FR-1 表单(dialog 7 测)/FR-2 server(集成 5 测:落库/校验含 diagnostics 边界/限流跨 IP/匿名+放行面回归)/FR-3 路由(service 10 测)/FR-4 降级链(重试原样+forceMail 不触 gRPC)/FR-5 限流变体/FR-6 白名单(构造排他+行结构钉)/FR-7 本门/NFR-1 冻结/NFR-2 放行面回归测/NFR-3 契约记录+pbjson 零漂移/NFR-4 内容不丢+透明路由。**Gate: PASS**
