# Code Ledger — F50

## Tasks

| Task | 状态 | fix-rounds | 备注 |
|---|---|---|---|
| TA debt 垂直片 | done | 0 | 独立复验 12/12;发现并修复 bound_mirror 全量重建覆写真缺陷(RED 实证) |
| TB 债表单开关 | done | 0 | 写侧 create/update/repo/bloc 全链路;284 debt 测 |
| TC 两页显示注入 | done | 0 | 平安校准 ¥38,728.30 两页渲染验证;display-only 断言(总负债/净资产/hero 逐分不变) |
| TD 校准与全量门 | done | 0 | 全量 **2528 全绿**;analyze 463==main 463 零新增;e2e **12/13**(1 失败=main 既有,双点复跑排除因果) |
| TS4 修复 runbook | 待用户 | — | 四笔补记(app 内操作)+ 35k 开关置关;交付时执行 |

## 评审记录(TA 两轴评审,2026-10-10)

- **Standards**:零 HARD;S-1 Minor(mirror_mappers 可选参数缺省回退有脆弱面,现调用方显式传值,注释已钉 proto 化移除点)parked;S-2 Minor(pending 行 mirror 跳过路径无测试钉,风险低)parked。
- **Spec**:P-1 **Important——已拍板(用户 2026-10-10 选 A 文档化)**:备份恢复(archive_importer 复用 debtRowFromEnvelope,envelope 无该键)会把开关重置 true = **已知行为**(display-only 影响,低频灾难路径);TS4 清单含「恢复后检查 35k 开关」;根治随 proto 化 backlog。P-2 由 TB 落地消解。无 WRONG/无 scope-creep。
- **附发现(不 charged)**:mirrorDebtToRow 同样抹掉 F48 本地私有列 billing_day/flat_fee_cents——同类危害实存,建议 F48 后续票。

## 环境注记

- TC 测试 harness:get_it 7.7 `reset()` 是 async,测试体内 reset+重注册会被延迟清空抹掉;先例=setUp 共享 mock+tearDown 统一 reset+`MaterialApp(key: UniqueKey())` 整树重挂。
- e2e A2「地标+更多菜单实测偏移(125%)」对本机显示缩放敏感,当前环境 main/worktree 双失败;非 F50 因果,留档观察。
