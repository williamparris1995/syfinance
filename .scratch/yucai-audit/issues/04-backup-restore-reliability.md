# 04 · 备份恢复可靠性(快照隔离 + 原子 restore)

Type: grilling
Status: resolved
Blocked by: 03

## Question

当前备份/恢复链路在并发写下不能作为可信灾难恢复手段(详见 `findings.md` D5/D6/D12/D13/D18/D19):

- **[D5 P0]** Backup 无 snapshot isolation:循环 Export 各 `Query().All` 默认隔离,并发写产生撕裂备份(账户 T1 状态 + 交易 T2 状态);sha256 校验只防传输损坏,不防逻辑撕裂。
- **[D6 P0]** Restore 非原子:purge 成功 + import 失败 = 永久丢失;pre-restore safety backup 本身也非快照 + 明文。
- **[D12 P1]** Restore 期间无写冻结 + 无 mutex:scheduler/用户写竞争 destructive。
- **[D13 P1]** auto/safety 备份硬编码明文(`encrypted=false`)绕过用户加密姿态。
- **[D18 P2]** Snapshot Save 撞 UNIQUE 硬错中断当日 snapshot。
- **[D19 P2]** 加密密码丢失=数据全损(无 escrow);scrypt N=2^15 低于 OWASP 2^17。

**决策点:**
1. 一致性快照:全模块共享 REPEATABLE READ tx(依赖 03 的共享 `*sql.DB`)/ `pg_export_snapshot` / 备份期间停写(maintenance mode)?
2. 原子 restore:maintenance mode + `pg_dump`/restore 一气呵成 / 跨模块 Tx(依赖 03)?
3. auto/safety 备份是否强制继承 BackupSettings encryption preference + DEK?
4. restore 写冻结:middleware 拒写 RPC + per-tenant mutex + scheduler 暂停?
5. snapshot Save 改 `OnConflictDoNothing`;scrypt 升 N=2^17;是否提供 recovery code?

注:快照隔离与原子 restore 的最优解依赖 03 的统一 tx 抽象,故 Blocked by 03。

## Answer(resolved 2026-07-26)

grilling 决策(5 点 + 排除项):

**战略路线**:建立在 **03 的统一 tx 抽象之上**(共享 `*sql.DB` + TxContext port),不走 maintenance mode 或 pg_dump。

1. **D5 backup 快照隔离**:共享 `*sql.DB` 起 `REPEATABLE READ` + `ReadOnly=true` 的单个 tx,经 TxContext 传播给各模块 `Export`。单连接天然共享快照 → 不需要 `pg_export_snapshot`;只读 backup 不需要 `Serializable` 的防写偏序开销。
2. **D6 restore 原子性**:purge + import 包进**跨模块 tx**(import 失败 → purge 自动 rollback,根因解 D6 P0)。**保留** pre-restore safety backup,但降级为「人为错误」兜底(选错备份文件 / 导入垃圾数据的回滚路径 —— tx 原子性只防事务失败,不防人为错误),并升级为**快照一致 + 加密**(加密见点 4)。三层防御(D5 导出快照 + tx 原子 + safety backup)各防不同失效模式。
3. **D12 restore 期间写冻结**:per-tenant 内存 flag 三件套(御财单 server,无需 DB 级锁):
   - ① per-tenant restore mutex 串行化同 tenant 并发 restore;
   - ② gRPC middleware 检查 per-tenant "restore in progress" flag,该 tenant 写 RPC(Create*/Update*/Delete*)返 `UNAVAILABLE` + "正在恢复数据,请稍后",读 RPC 放行(原子 restore tx 保证外部读只看到 restore 前/后一致状态,不撕裂);
   - ③ scheduler(autoRecord / snapshot / auto-backup)检查同 flag,命中即跳过该 tenant 该 tick。
4. **D13 auto·safety 加密(分层)**:
   - **safety backup**:restore 时 user 在场 → 当场提示输密码,用**用户密码加密**(关掉 D6 的 safety backup 明文);
   - **auto backup**:scheduler 建,user 不在场,server 不持密码 → 维持 **server-local 明文**,但 UI 明确标注「自动备份·未加密·仅本机」(不做虚假加密徽章)+ 强制文件权限 0600;
   - **不引入 server-held DEK**(私域单机威胁模型:备份文件就存 server 本机,能拿文件=已拿 server,DEK 边际收益≈0,不值得 KEK 基建);
   - 手动/导出备份保持密码加密(用户在场)。
5. **D18/D19 polish**:
   - **D18** snapshot Save 改 `OnConflictDoNothing`(first-wins,保留时点快照语义,重复 tick 不再硬错中断当日 snapshot)✅ 纳入;
   - **D19a** scrypt N 2^15→2^17(OWASP)+ **版本化自描述 KDF header**(v1 路径硬编码 2^15 兼容旧加密备份 / v2 header 存 N/r/p 默认 2^17;新 Encrypt 写 v2,Decrypt 按 magic 分流)✅ 纳入;
   - **D19b** recovery code → **defer**(需 DEK 重构 + password/recovery-key 双包 + 生成/展示/保管/改密重加密 UI 流程,超 P2 polish 合理范围);本轮仅做「加密时强警告 + 用户确认已保管密码」。D19b 进 map P2 backlog。

**明确排除(out of frame,非路线)**:
- `pg_dump`/restore —— 整库导出,不 fit 御财单库多租户的 per-tenant restore;只适合整库灾难恢复,不在本 ticket 范围。
- 全局 maintenance mode —— 一个 tenant restore 冻结所有 tenant,误伤。
- server-held DEK —— 见点 4,私域单机边际收益≈0。

**依赖与排序**:D5/D6/D12 全部依赖 **03 阶段 A**(共享 `*sql.DB` + TxContext port 基础设施)先行落地;Export/Purge/Import port 需接受 TxContext 传播的 tx。04 实施在 03 阶段 A 之后(作 03 专项 plan 的后续阶段或独立 plan)。

**实施规模:中**(建立在 03 基础设施之上),分点:backup 起 REPEATABLE READ 只读 tx + TxContext 传播 Export 循环;restore purge+import 包跨模块 tx + safety backup 加密 + ReadOnly;写冻结 per-tenant flag + middleware interceptor + scheduler 检查;polish snapshot OnConflict + crypto 版本化 header N=2^17 + 加密强警告 UI。

unblocks 无下游(04 是叶子)。**实施留专项 plan/session**(本 session 仅 resolve 锁方向,同 03)。
