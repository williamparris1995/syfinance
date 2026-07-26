# 08 · 错误处理统一(err.Error() 透传 + DomainError 启用)

Type: grilling
Status: open
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
