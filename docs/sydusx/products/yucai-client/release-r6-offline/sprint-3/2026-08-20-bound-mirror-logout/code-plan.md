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
