# Code Plan — F20 多设备 e2e 收官

## Tasks

- [x] **T1 双向循环+删除传播 e2e**:两场景写入 link_offline_sync_e2e_test.dart（或新文件）;fake 复用;门全绿。

## 执行方式

单实现任务 → 两轴 review → R10 收官评估。


## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 双向循环+删除传播 e2e | ✅ | 0(review 待) | fake 零改动(push 落 log/pull since 过滤天然支持);deviceCoordinator 工厂收口;墓碑链路端到端含回声不泄漏断言 |

## 存档上云事实性映射(FR-3)

R6 defer"存档上云(格式已兼容)"的实质=数据保险——**server 全量备份+恢复+自动调度+完整 client UI 已存在**(CreateBackup/RestoreBackup/ListBackups/DeleteBackup+per-tenant 调度器+备份页/自动备份设置页,早于 R10)。R6 设想的 UploadBackup 密码版/.ycb 上云+下载通道记 **backlog**(bind 统一 push 后无生产调用方)。映射完成,F20 不做重复开发。

## R10 done-criteria 核对(FR-5)

| 条目 | 状态 |
|---|---|
| 五 feature 全 done | F16 ✅ F17 ✅ F18 ✅ F19 ✅ **F20 ✅(本 feature)** |
| 双设备同步 e2e 绿 | ✅(offline_sync_e2e 6 场景+bind_merge 4 场景,13 文件 E2E_FILES) |
| 契约切片 | 条件未触发(全部向后兼容,README 四条登记) |
| R9 人工验收补记 | **待用户**(清单见 R9 release.md) |
| 单设备回归门全绿 | ✅(e2e 13+UI 12+flutter 1581+go 66 包) |

→ R10 达成 done-criteria(R9 人工验收为唯一外部待办)。
