# Task Brief T4 — client data：UpdateDebt 链路透传 subtype

## 任务
把 subtype 接进 client 更新链路（proto dart 生成物已 regen，`UpdateDebtRequest` 已有 subtype 字段 19，dart 侧 `..aOS(19, 'subtype')` 已存在）：

1. **params**：找 `UpdateDebtParams`（`lib/debt/domain/repositories/debt_repository.dart` 或 data 层定义处，debt_form_page.dart:939 注释指向它）——加 `final String subtype;`（或 String?，按仓内 params 风格定，注释说明空串=不修改的语义在 DS 层处理）。
2. **repo**：`lib/debt/data/debt_repository_impl.dart#update` 透传 subtype 到 DS 调用。
3. **remote DS**：`lib/debt/data/debt_remote_ds.dart#update` 组装 `UpdateDebtRequest` 时带上 subtype。
4. **local DS**：`lib/debt/data/debt_local_ds.dart#update` 更新 drift 行 `subtype` 列（Companion(Value(...))；空串语义=不修改则在 local 侧同样守卫）。
5. **镜像**：`lib/binding/data/mirror_mappers.dart` —— read 路径 `:108` 已有 `subtype: d.subtype`；核对 **update 方向 envelope** 是否需要补 subtype 字段（找到 update 镜像的编码处，缺则补）。

## TDD 周期（sydusx-tdd）
1. RED：单测三件——repo.update 透传断言（mock DS 收到 subtype）；local DS update 后行内 subtype 变更且空串不变更；mirror update envelope 含 subtype（若 update 镜像有编码测试先例则扩展，无则按 nearest 先例补）。沿用各文件现有测试风格与位置。
2. GREEN：实现（保持既有 update 签名兼容——subtype 是新增参数，调用方仅 debt_form_page 与测试，可改签名）。
3. 回归：`flutter test test/debt/ test/binding/` + `dart analyze lib/debt/ lib/binding/`（零新增 info）。

## 约束
- 先 RED 后 GREEN；勿动 `_toEntity` 派生逻辑（remaining/unpaidInterest 与本票无关）。
- 完成后报告：改动文件 + 每个测试的输出证据 + analyze 结果。
- 工作目录：`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f33`（分支 feature/r14-f33-debt-subtype，勿切分支）。
