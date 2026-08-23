# Code Plan — feature H 绑定后镜像 + 登出回本地

- [ ] T1 DAO deleteAll 系列 ×8 模块(drift 一行式)
- [ ] T2 MirrorMappers(8 实体→行纯函数)+ BoundMarker
- [ ] T3 BoundMirror(refreshModule/refreshAll,inFlight 去抖)
- [ ] T4 触发接线:7 repo 写钩子(_mirrored helper)/AuthBloc 登入+登出终刷/BindingBloc markBound/设置页 isBound
- [ ] T5 测试六件 + 双侧全套基线 + 提交

## 执行记录(2026-08-23)

- 全套 +1085 -4(=基线,零新增);analyze 399 < main 405;go exit 0。
- 修复轮:首个钩子脚本行级括号平衡错误(40 编译错)→ 回退 8 repo,改用 D 轮验证过的字符级平衡括号重写器(hook2)重做,38 写方法全部挂钩;tag 两个多行方法手工补;AuthBloc 触发接线(unawaited/microtask 时序注意)。
- 测试 +7:BoundMirror 替换/失败静默/repo 钩子(远端触发·guest 不触发)/BoundMarker 往返/未标记。

## Review 修复轮(2026-08-23,首轮 reject:2 DI BLOCKER + 数据丢失 + 漏钩)

- **H1(BoundMarker 双注册启动崩)**:删 injection.dart 手动注册(@LazySingleton 生成器版注入共享 secure storage,保留)。
- **H2(mirror↔repo 构造环栈溢出)**:BoundMirror 改单参(AppDatabase),8 repo 经 getIt **getter 惰性解析**——环断在消费点。
- **W4(登入刷清空未绑定本地数据=不可恢复丢失)**:登入 refreshAll 加 **isBound 守卫**(首绑流程由 BindingBloc 上传成功后自行 refreshAll,再 markBound)。
- **W3(template create/update 漏钩,G 轮 H1 同类复发)**:脚本又跳多行方法,手工平衡括号包裹补齐——41/41。
- **J5**:tag 镜像清 junction(与 backup 契约一致,登出后标签关联消失=契约缺口既有);**J6**:TokenRefreshFailed 补终刷。
- 测试改 getIt 注册 repo(mirror 惰性解析);清理未用 mock。
- 修复后:全套 +1085 -4(=基线);analyze 401;零 server。
- **教训强化**:脚本重写器跳多行方法已两次(H1 复发)——修复后必须 grep 数钩子数(41)核对清单,记 harness 候选。
