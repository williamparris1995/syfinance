# Sprint 2 — R12 F27 onAccent sweep

> /sydusx-portfolio(2026-09-15)。来源:F15 backlog 票(onAccent sweep,Colors.* 口径 ~20+ 处)。

## Sprint Goal

accent 前景裸色(Colors.white/black 系压在金/绿 accent 面上的文字/图标)全量迁语义令牌 onAccent——design-v2 令牌面清零(令牌定义处除外)。

## Feature roster

- [x] **feature F27** onaccent-sweep — 库存清点→机械迁移(每处判定:accent 面→onAccent;非 accent 面→fg/muted/语义)+探针/既有测试守门 ✅ done(2026-09-15,merge `ff4dabf1`[fast-forward];47 迁移/29 豁免带注;1686 全绿+analyze 428;评审双轴 PASS 零错例;判定清单 sweep-ledger.md)

## defer

- 占位文案清理(下一候选)

## status: done(F27 ✅ 2026-09-15;design-v2 令牌三阶段闭环:AppColors[F15]→裸hex[F26]→Colors.*[F27];占位文案清理待排)
