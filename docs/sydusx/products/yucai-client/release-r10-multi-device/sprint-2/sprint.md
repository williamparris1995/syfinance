# Sprint 2 — R10 冲突与合并

> `/sydusx-portfolio`(2026-09-06,sprint-1 收官后启动)。

## Sprint Goal

多设备的冲突显式化与收尾:冲突解决 UI(F18)+ 非空账号绑定合并(F19)+ 存档上云与多设备 e2e 收官(F20)。

## Feature roster(依赖排序)

- [x] **feature F18** conflict-resolution — 冲突解决 ✅ done(2026-09-06,merge `001c7b07`;检测统一[canonical 规范形短路,阻断修复]+确认语义+解决落库[client/merged Upsert+log]+applier 版本感知+冲突面板[badge amber/双栏对照/二选一]+双设备冲突 e2e;TDD ~80 新测;三门 GREEN)
- [ ] **feature F19** bind-merge — 非空账号绑定合并
- [ ] **feature F20** cloud-archive-e2e — 存档上云+多设备 e2e 收官

## defer

- F16/F17 review 遗留观察项(毒丸游标复议等→F18 吸收)

## status: pending(F18 ✅;F19/F20 待做)
