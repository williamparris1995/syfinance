# Task Brief F20-T1 — 双向循环+删除传播 e2e

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f20`,客户端 `yucai/client/`。

## 先读(必读)
1. `docs/.../2026-09-06-cloud-e2e/spec.md`(FR-1/2/5)
2. `integration_test/link_offline_sync_e2e_test.dart`(F17-T2 双设备场景 :752——**本任务的直接模板**:换 clientId 模拟 B/游标归零/fake push 落 log/pull 重放);F18-T3 冲突场景 :841;F19 合并 e2e(设备模拟深化)
3. `lib/binding/data/pull_applier.dart`(DELETE 下行硬删语义)、`lib/binding/data/pending_collector.dart`

## 交付物
### 1. 场景⑤ 双向持续循环(FR-1)
写入 link_offline_sync_e2e_test.dart(编号续 F18-T3 的 ④):
- A 断网写实体 X(account)→回网 push→fake log 有 X;
- 模拟 B(换 clientId-B+DAO 清 X+游标归零)→pull→B 有 X(同版本同内容);
- **B 写实体 Y(tag 或 transaction)**→push→fake log 追加;
- **切回 A**(clientId-A+A 的游标[A 只推到 v1,B 推的是 v2——A 游标=1)→pull→**A 有 Y;
- 终态断言:两侧均有 X+Y(fake log 完整+两侧 DAO 查询同版本同内容)。
- fake 能力核对:push 已落 log(version 递增);pull 按 since 过滤——双向循环天然支持,应零 fake 改动(或最小)。

### 2. 场景⑥ 删除传播(FR-2)
- A 写实体 Z→push;B pull 得 Z;
- **A 删 Z**(DS 硬删+墓碑)→push(墓碑 DELETE)→fake log 追加墓碑;
- B pull→DELETE→B 本地 Z 硬删**不复活**;B 的墓碑表空(下行删除不写墓碑,F17 论证);
- B 后续 push(若有其他 pending)不含 Z(墓碑已清)。
- 断言:两侧 Z 均不存在;fake log 含墓碑条目。

### 3. 门
- 新场景单文件跑绿;`flutter test` 全量;`make client-e2e` 全量(13 文件);`client-e2e-ui F=ui_boot_subscription_test.dart` 抽验;`go test`(保险)。

## 约束
生产代码零改动(仅 e2e 扩展;若 fake 需微扩注释理由);中文注释;不 commit。完成后报告。
