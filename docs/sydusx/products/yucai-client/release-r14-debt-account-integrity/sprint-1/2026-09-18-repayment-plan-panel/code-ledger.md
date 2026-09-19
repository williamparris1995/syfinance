# Code Ledger — F35 repayment-plan-panel

## 实现 — ✅ done(2026-09-18,派发 TDD)

- 改动:repayment_plan_panel.dart(新组件)/account_detail_page.dart(_loadRepaymentPlans+RouteAware+didPopNext+loan 分支替换占位)/account_detail_page_test.dart(+163 行 harness+3 测)。
- fix-rounds:0(代理一次 GREEN)。
- **简报勘误 1 条**:didPopNext 并非「hotfix 已有」——F33 热修只接了 debt/receivable 详情页,account_detail_page 无;代理按最小改动补 RouteAware(accountsRouteObserver,router :177 已挂,零 router 改动)。
- 评审(sydusx-code-review 两轴):Standards——零裸 hex(0 处,context.yucai×11)、core/widgets 共享位、分层 ✓、静默降级沿页面既有模式 ✓;Spec FR-1/2/3 全过(空态隐藏/占位退役/跳转路由),投资占位未动 ✓。
- prototype: none 理由 —— 面板复用既有 DataCard 形态与令牌,无新视觉语言(报告后补记)。
- 门:1858 全绿+analyze **438≤439**(代理遗留 4 条 lint:[2×const Right/2×下划线命名]主控复核发现并修复,测试文件回到基线 12)+client-e2e 管道(见下)。

## 验收热修第二轮(合并后) — 贷款详情数据语义 ✅(2026-09-19)

- 用户截图反馈:stats 4 卡全 0 且与信息卡重合;hero「可用余额 -¥6,795.20」不可理解。
- 修复:①loan 挂债隐藏 stats 条;②已还比例挪入信息卡;③挂债 loan hero 显「剩余应还」(债务实时剩余,展示语义;余额重算治本归 F36);④_loadLinkedDebt 补 typeFilter(镜像 _loadRepaymentPlans)。
- TDD 3 新测(RED 3/3);1861 全绿+analyze 438≤439+e2e 14/14。

## backlog 转正 — otherLiability(个人待还款)同待遇 ✅(2026-09-19,用户「需要」)

- spec delta:FR-2 MODIFIED(loan 类 → loan+otherLiability 类);stats 条不隐藏裁定:otherLiability 的 4 卡=真实收支数据(非 loan 式静态 0),与新增债务行内容不重合。
- 改动:account_detail_page.dart(_isDebtDerivedLiability 助手收敛 hero/面板判定+两处 info switch case 叠加+移除两处不可达 otherLiability 标签)+3 新测。
- 门:1874 全绿+analyze 438≤439+e2e 14/14。随下个版本(v1.0.7+)发布。
