# 10 · wire 与 schema 工程债(wire 校验 + migrate + TimeMixin + slog)

Type: grilling
Status: open
Blocked by: —

## Question

长期可维护性定时炸弹(详见 `findings.md` A6/A7/A8/A10/D14):

- **[A6 P1]** `wire.go` 落后 `wire_gen.go` ~30 provider(providePresetSeeder/TransactionDB/LotRepo/SnapshotRepo/各 Scheduler/NetWorth 等),无校验测试;误跑 `go generate` 静默丢依赖。
- **[D14 P1]** ent auto-migrate 每次启动跑(`providers.go` 各 `client.Schema.Create`),无版本化/无 review gate/无回滚(ent migrate 不生成 downward SQL)。
- **[A10 P2]** 无 TimeMixin/AuditMixin,14+ schema 内联时间戳已漂移;Holding 无软删。
- **[A7 P1]** slog `"op"` key 强制规则零执行(全 server 0 匹配,实际把 op 塞 message);`CurvePoint.value` double 语义模糊(`proto/holding/v1/holding.proto:171-174`)。
- **[A8 P1]** Sync 破坏 pagination 约定(version-cursor vs common PageRequest);AccountService 混 Account + Category 两 context。

**决策点:**
1. wire:加 composition 测试(解析 `providers.go` 的 `provide*` 声明 vs `wire_gen.go` 调用,断言集合相等)/ 删 `wire.go` 并注释"CLI 永久退役,手维护 wire_gen.go"?
2. 迁移:脱离运行时 auto-migrate,改 atlas / ent-versioned-migrate 显式流程(带 downward + 回滚演练)?
3. 抽 `TimeMixin{created_at,updated_at,deleted_at,version}` 统一应用?Holding 软删决策?
4. slog:全量加 `'op'` key / 更新 CLAUDE.md 与现状对齐?`CurvePoint.value` 改名/注释(ratio vs price)?
5. Sync pagination 统一 PageRequest 或文档说明 version-cursor 必要性?拆 `CategoryService` 出 `AccountService`?
