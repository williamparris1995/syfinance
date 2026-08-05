# 08 · 错误处理统一(err.Error() 透传 + DomainError 启用)

Type: grilling
Status: resolved
Blocked by: —

## Question

typed `DomainError` 体系建而不用,handler 改脆弱子串匹配;10+ handler 默认分支把 `err.Error()` 透传客户端(详见 `findings.md` S4/A3):

- **[S4 P0]** 10 个 handler(budget/account/transaction/tag/goal/holding/debt/currency/sync/template)的 `mapError` 默认 `status.Error(codes.Internal, err.Error())` + 30+ 处 `Unauthenticated` err.Error() → 底层 ent/Postgres 错误描述(字段名/约束名/内部路径)泄漏给客户端。
- **[A3 P1]** `shared/errors.DomainError`(Code + ErrNotFound/ErrValidation/ErrOptimisticLock sentinel)已造好,实际所有 handler 改用 `strings.Contains(msg, "invalid")` 之类;重命名 domain error 文案会静默回退 codes.Internal。

**决策点:**
1. 在 `shared/errors` 加中央 `ToGRPCStatus(err)`(`errors.As` + DomainError.Code 派发),所有 handler 调它替代各写子串表(backup_handler 已是范式)?
2. default 分支统一:回固定 "internal error" + err 走 slog?
3. gRPC status code 映射规范:InvalidArgument/NotFound/PermissionDenied/FailedPrecondition(乐观锁)/Internal?
4. 迁移范围:一次性全 handler / 渐进(先 P0 模块)?

## Answer(resolved 2026-07-26)

grilling 决策(2 点,合并决策点 1+2+3 / 4):

1. **Q1 中央映射器(S4/A3,决策点 1+2+3)**:`shared/errors` 加中央 `ToGRPCStatus(err)` —— `errors.As` 派发 `DomainError.Code` → gRPC code(`NotFound` / `InvalidArgument` / `FailedPrecondition` 乐观锁 / `PermissionDenied` / `Unauthenticated`);非 DomainError → `codes.Internal` 固定 message `"internal error"`(**不透传** `err.Error()`,消除 ent/Postgres 字段名/约束名/内部路径泄漏)+ 原始 err `slog.Error`(走日志非响应)。各 handler 删各自 `mapError`/`contains`(tag/auth/backup/transaction/currency 等各一份),统一调 `shared/errors.ToGRPCStatus(err)`(backup_handler 范式推广)。service 层抛 `DomainError`(替代 `fmt.Errorf` 子串)。解 S4 信息泄漏 + A3 子串脆弱。
2. **Q2 迁移范围(决策点 4)**:**handler 层一次性全切** `ToGRPCStatus`(一致性要求,半统一更乱)+ **service 层 DomainError 渐进**(已抛的派发,`fmt.Errorf` 的 default Internal 兜底,逐步补)。降低 service 全替换风险,handler 统一即解 S4。

**跨 ticket 取舍**:08 与 09(DDD/port)迁移顺序 —— handler 一次性先(独立于 09);service DomainError 渐进可与 09 service 重构协同(09 重构 application→domain 边界时顺手补 DomainError)。

unblocks 无下游(08 叶子)。**实施留专项 plan/session**(shared/errors ToGRPCStatus + 各 handler 切 + service DomainError 渐进 + handler 错误映射测试,中等规模)。
