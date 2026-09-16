# Sprint 2 — R13 F32 hero 验收缺陷修复

> /sydusx-brainstorming(2026-09-16)。用户真机验收 dashboard 发现;挂载位置经用户拍板(R13 sprint-2)。

## Sprint Goal

dashboard hero 两处验收缺陷清零:负净资产千分位错位 + hero 光晕 Stack 硬裁残块。

## Feature roster

- [x] **feature F32** hero-acceptance-fix — 负净资产千分位 + 两 hero 光晕裁剪 ✅ done(2026-09-16,merge `0f220db6`[ff] + 评审修复 `364669f4`[ff];两轴 review:3 Minor = 修 2[string 侧剥符号防 int64 回绕/account 暗色 clip 断言补齐 4 组合] + defer 1[见 defer];prototype v2 对照 pass[.hero overflow:hidden 卡缘裁剪语义与 Clip.none+antiAlias 一致];+4 测,worktree 门 1735 全绿+analyze 429 基线;真机 dashboard 复核待用户)

## defer

- 千分位分组全仓 ~22 处同型副本(4 处兄弟副本符号不安全,调用点均先 abs 无 live bug)——收敛到 core/ 公共 helper 另开票(review Standards/JUDGEMENT,F32 spec scope 圈外)。

## status: done(F32 `0f220db6` + 评审修复 `364669f4`,2026-09-16)
