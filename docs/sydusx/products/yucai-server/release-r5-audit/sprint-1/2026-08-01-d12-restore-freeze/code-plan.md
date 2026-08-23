# Code Plan — D12 restore 期间写冻结(三件套)

- [x] T1 RestoreFreeze 组件 + 单测 ×3(生命周期/同租户串行/跨租户并行)
- [x] T2 RestoreFreezeInterceptor + 分类器 + 单测 ×5(写拒/读放/未知放/未冻结放/无 tenant 放)
- [x] T3 Service Acquire 包裹(RestoreBackup/UploadExternal 全程冻结窗口)
- [x] T4 三 scheduler 插桩(backup/goal/debt per-tenant tick 头部跳过;holding snapshot+template 记 ledger——跨租户 bulk/按行迭代类,超 D12 per-tenant scope)
- [x] T5 wire 接线(interceptor 链 4 层/singleton/三 scheduler 传参;wire_gen 手改按 CLAUDE.md 政策)+ go test 61 包全绿

## 执行记录(2026-08-23)

- ctor return struct literal 初版漏 freeze 字段致 nil panic(单测抓);freeze 串行测试初版 channel 环死锁(重写为主线程持有+goroutine 观察者)。
- middleware 经 SetRestoreFreezeChecker 全局注入(TokenService 模式);nil-safe(启动窗口/测试)。

## Review 修复轮(2026-08-23,首轮 reject:2 HIGH + MEDIUM)

- **H1 debt scheduler 未插桩+wire 传参被 provider 丢弃** → 循环头部补 IsFrozen 检查+ctor 收 freeze+provider 真传参。
- **H2 goal scheduler 检查为死代码(ctor 不收参,字段恒 nil)** → ctor+struct literal 补 freeze;provider 传参。
- **H3 黑名单漏 8 个现存写 RPC**(Simple*快捷记账/Push*/Resolve*/Reorder*/Compute*) → 加 5 前缀(Simple/Push/Resolve/Reorder/Compute);测试的 PushChanges 改真未知名 QueryStatus。
- **M4 template 未插桩(ledger 理由不成立——t.TenantID 按行可得)** → per-row IsFrozen(t.TenantID) 检查。
- gofmt 顺手(去双空行等);附带修复 providers.go 一处误改(Schema.Create 被注入 freeze 参数)。
- 修复后:go test 61 包全绿。

## Review + Test(2026-08-23,pass — 两轮)

- 首轮 reject(2 HIGH:debt 断链/goal 死代码——**wire 传了参但 provider 静默丢弃+ctor 不收参,全绿测试完全掩盖**;H3 黑名单漏 8 写 RPC;M4 template)→ 修复 → 复审 **pass**(四项证据齐全,interceptor 16 proto 全 RPC 审计残余仅设计 R1 fallback 类)。
- Test 裁定:pass——61 包全绿;freeze ×3/interceptor ×5;requirement coverage:FR-1 串行+跨租户 ✓/FR-2 写拒读放+5 新前缀 ✓/FR-3 四 scheduler(goal/debt/template 补齐+backup)✓/FR-4 全程窗口+defer ✓/NFR ✓。
- **教训**:接线类改动的"看似接线实未接线"(provider 收参丢弃/ctor 不收)编译器和 vet 都不报——**注入类改动必须从消费点反查到注入点全程链路验证**(此处 review 抓到,单测没抓)。
