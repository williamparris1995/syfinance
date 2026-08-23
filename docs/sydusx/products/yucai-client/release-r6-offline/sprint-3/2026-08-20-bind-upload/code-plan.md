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

## 复审修复(二轮 reject:H1 残留 3 处 + H2 buf 未 untrack)

- **H1 残留**:debt/budget/goal 三处 TenantID 空串漏删(修复脚本 replace 匹配带尾换行变体不全)→ 全清(grep 零残留)。**复审者实证**:server uuid v1.6.0 对空串报 invalid UUID length: 0;缺键→零值无错。教训:修复轮必须 grep 验证清零,不能信脚本返回值。
- **H2 补齐**:yucai/buf.gen.*.yaml git rm --cached + 删盘(它们是 main 的 yucai/proto/ 下 untracked 文件,feature 提交误挪误 track);gen-dart.sh 已回位。
- 小清:bloc 死代码 fold/失败文案取真实面错误;测试 unused import ×2。
- 二轮修复后:exporter+binding +26 全绿;analyze 383;backup go 7 包 ok。

## Review + Test(2026-08-23,pass — 三轮)

- 首轮 reject(H1 TenantID 空串炸全模块 Import/H2 工具链事故 2.1 万行孤儿树)→ 修复 → 二轮 reject(H1 残留 3 处/H2 buf 未 untrack——修复脚本匹配不全+未 grep 验证)→ 二轮修复(清零+untrack)→ 三审 **pass**(grep 零残留/4 验收点过/gen-dart 链路自包含)。
- Test 裁决:**pass** — go test ./... exit 0 + flutter +1078 -4(=基线);analyze 383;requirement coverage:FR-1 导出器 6 测(形状/嵌套/聚合/兄弟数组/幂等)/FR-2 guard 三面(fail-closed after J2)/FR-3 状态机 4 测(含失败本地无损+验证比对)/FR-4 one-shot 触发/NFR-2 server 仅 backup 模块。
- **教训(→harness 候选)**:①修复轮必须 grep 验证清零,不信脚本返回值(二轮 reject 根因);②跨语言 wire 契约的测试双侧必须吃**真实对端样本**(双侧 fake 各自假形状放走 H1);③生成工具链配置(untracked buf yaml)禁止挪动/track。
