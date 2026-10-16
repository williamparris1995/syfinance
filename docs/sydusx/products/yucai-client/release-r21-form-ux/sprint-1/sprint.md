# Sprint 1 — 债务表单重做 + UX 整改扫票

> /sydusx-portfolio 2026-10-15 立项(两票串行,F63 依赖 F62 范式)。

## Sprint Goal

债务表单按 OD 拍板方案重做(About Face 对齐,账户表单同范式顺带);审计 ANTI 全量整改收口。

## Features

- [x] **F62 债务表单重做** — 场景卡推导分类/灰显过滤/载体隐形/渐进披露/期供预览;警示条 UI 退役。 ✅ done 2026-10-16 合并 12a326c6/ff(inline 实现轮+评审 PASS-with-fixlist I-1/2/3+M/N 全修;门:2829 绿+analyze 458<461+e2e 双点排除留档=stash HEAD 同红 errno32 测试库锁竞态环境性)
- [ ] **F63 UX 整改扫票** — 审计 ANTI 全量整改:ErrorRetryView 9 页/行内校验 5 表单(transaction_form 返回条+脏守卫急件)/2-4 值下拉改分段 3 处/可逆确认改直做/死按钮清理/SnackBar 统一 AppToast;账户表单同范式并 F62 顺带。(依赖 F62 范式;审计清单=ux-audit-r21.md)

## status: pending
