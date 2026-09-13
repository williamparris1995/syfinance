# Spec — F20 多设备 e2e 收官（最小收官）

> R10 sprint-2 · 2026-09-06 · 用户拍板最小收官。查证:"存档上云"实质(server 全量备份+恢复+自动调度+client UI)已存在于 R10 前;done-criteria 五条中三条已满足;唯一开放项=本 feature。

## Requirements

- **FR-1 双向持续循环 e2e**:A 写→push→B pull 收敛→**B 写→push→A pull 收敛**（现有只有 A→B 单向;B 改回 A 是"持续循环"证明）——断言双方终态一致（同实体两侧同版本同内容）。
- **FR-2 删除传播 e2e**:A 删除实体（墓碑上行）→B pull DELETE→B 本地硬删不复活;反向确认（B 后续 push 不含已删实体——墓碑已清）。
- **FR-3 存档上云事实性映射**:"存档上云（格式已兼容）"R6 defer 项以现存 server 备份面作映射记录——CreateBackup/RestoreBackup/ListBackups/DeleteBackup+自动调度器+client 备份页/设置页已在（早于 R10）,R6 设想的 UploadBackup 密码版+下载通道记 backlog（bind 统一 push 后无生产调用方）;映射记录写 feature.md ledger+R6 release.md 尾注。
- **FR-4 R9 人工验收清单交接**:R9 release.md 的人工验收清单补记到 progress.md 当前位置（提醒用户）,非代码。
- **FR-5 全量门**:新 e2e 进 E2E_FILES;flutter test+make client-e2e+client-e2e-ui+go test 全绿;R10 release status 评估（done-criteria 核对）。

## Scope boundary

| 排除 | 理由 |
|---|---|
| UploadBackup 密码版/.ycb 上云 | bind 统一 push 后无生产调用方;backlog |
| DownloadBackup RPC | 同上 |
| server 起源写入入 sync_log（自动记账/restore 跨设备可见） | 结构性缺口,sprint-3 候选 |
| 周期性拉取 | 触发点驱动够用 |

## Grill record

| 决策 | 定案 |
|---|---|
| F20 范围 | 用户选最小收官（双向循环+删除传播 e2e;存档上云=事实性映射+backlog） |
