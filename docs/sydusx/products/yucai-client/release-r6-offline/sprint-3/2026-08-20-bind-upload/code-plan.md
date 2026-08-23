# Code Plan — feature G 绑定上传

- [x] T1 server:proto +UploadBackupRequest/rpc(buf+gen-dart 双侧生成)/handler(鉴权 tenant+空 data 校验)/Service.UploadExternal(safety 快照+tenant 覆盖+purge/import 复用)/单测 ×4(导入/tenant 覆盖/坏输入不 purge/失败留 safety)
- [x] T2 client:LocalSnapshotExporter(8 模块 PascalCase mapper,holding 兄弟数组/goal 聚合/嵌套 entries·schedule·items/ISO8601Z 时间)/backup_remote_ds.uploadBackup
- [x] T3 BindingBloc(状态机 7 态;guard 三面走双源 repo[登录后自动远端])/BindingPage 三步向导(单向覆盖明示)/路由 /binding/设置页登录成功+本地有数据→push
- [x] T4 测试:导出器 ×6(envelope 形状/account 47 键/嵌套/goal 聚合/holding 兄弟/幂等只读)+BindingBloc ×4(空→ready/非空→blocked/成功验证计数/失败可重试本地无损)
- [x] T5 双侧全套:go exit 0 + flutter +1078 -4(=基线,零新增);analyze 385<398

## 执行记录(2026-08-23)
- buf 配置(buf.gen.go/dart.yaml)是 untracked——从 main 拷入 worktree 生成后删除;gen-dart.sh 同。
- 勘误:测试断言 Description isNotEmpty 失败(recordExpense 默认 '')→改断言 ID;holding buy 余额校验需 seed 余额(F 后真实校验)。

## Review 修复轮(2026-08-23,首轮 reject:2 BLOCKER)

- **H1(TenantID 空串炸 Import)**:移除全部 9 处 `'TenantID': ''` 键(Go uuid.UUID 对缺键取零值 Nil UUID,server 覆盖)——根因:双侧 fake 各自吃假形状,真实 unmarshal 从未被测;教训:server 单测必须吃真实 client 导出样本。
- **H2(工具链事故)**:gen-dart.sh 移回 proto/(git mv);repo 根孤儿 server/ 树删除(git rm --cached+rm);yucai/buf.gen.*.yaml untrack+删。Makefile 的 `cd proto && bash gen-dart.sh` 恢复可用。
- **J1**:envelope 顶层键改 snake_case(version/tenant_id/created_at/modules,对齐 server json tag);模块内 PascalCase 不变(正确)。
- **J2**:guard fail-closed——任一面 Left→failed(无法证明空=阻止上传),杜绝瞬时网络错+确认=静默覆盖非空账号。
- **J3**:上传后验证真比对(计数不等→failed);**J4**:向导触发 one-shot 闸(static flag,仅 Guest→Authenticated 转变触发)。
- 测试同步:exporter 测试 6 处 key 期望更新。
- 修复后:go exit 0 + flutter +1078 -4(=基线);analyze 385。
