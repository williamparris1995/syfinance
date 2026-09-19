# Code Ledger — F37 due-urgency

## 实现 — ✅ done(2026-09-19,inline TDD)

- 改动:debt_query.dart(DebtDueUrgency+debtDueUrgency 纯函数)/debt_list_widgets.dart(MetaKv valueColor/MetaItem color 可选参+_dueUrgencyDecor 后缀着色+三渲染点)/两测试文件(domain 6+widget 4)。
- fix-rounds:2(①kv/item 站点缩进与闭包作用域——color 泄漏外层具名参,改整件闭包返回;②后缀长度致 MetaItem 行溢出 11px——缩短为「(N天内)/(逾期N天)」+ellipsis)。
- 排序结论:默认序已是「未结清在前+到期升序」(F9 NFR-2),本票以显性测试钉死+视觉紧迫度补足用户感知。
- 评审:两轴 pass(存储口径零改动;色值全令牌;两页镜像自动同待遇)。
- 门:1884 全绿+analyze 437<438(顺修存量重复 import)。
