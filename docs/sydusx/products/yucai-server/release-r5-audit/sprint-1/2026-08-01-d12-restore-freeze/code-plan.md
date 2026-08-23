# Code Plan — D12 restore 期间写冻结(三件套)

- [x] T1 RestoreFreeze 组件 + 单测 ×3(生命周期/同租户串行/跨租户并行)
- [x] T2 RestoreFreezeInterceptor + 分类器 + 单测 ×5(写拒/读放/未知放/未冻结放/无 tenant 放)
- [x] T3 Service Acquire 包裹(RestoreBackup/UploadExternal 全程冻结窗口)
- [x] T4 三 scheduler 插桩(backup/goal/debt per-tenant tick 头部跳过;holding snapshot+template 记 ledger——跨租户 bulk/按行迭代类,超 D12 per-tenant scope)
- [x] T5 wire 接线(interceptor 链 4 层/singleton/三 scheduler 传参;wire_gen 手改按 CLAUDE.md 政策)+ go test 61 包全绿

## 执行记录(2026-08-23)

- ctor return struct literal 初版漏 freeze 字段致 nil panic(单测抓);freeze 串行测试初版 channel 环死锁(重写为主线程持有+goroutine 观察者)。
- middleware 经 SetRestoreFreezeChecker 全局注入(TokenService 模式);nil-safe(启动窗口/测试)。
