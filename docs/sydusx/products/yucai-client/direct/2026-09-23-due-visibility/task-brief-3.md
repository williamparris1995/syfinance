# Task T3 — 首页聚合条(DueBanner)

项目:御财 Flutter 客户端 `yucai/client/`(design-v2 主题系统,语义令牌 `context.yucai`,
F4 迁移后零裸色红线)。照 `docs/sydusx/products/yucai-client/direct/2026-09-23-due-visibility/`
下 spec.md(FR-1/2/3/7)/design.md(LLD「DueBanner 布局契约」节)执行。
T1/T2 已交付可直接消费:`DueCandidateProvider.stream`(Stream<List<DueCandidateView>>,
视图含 entryKey/title/amountCents/dueDate/tier/daysLeft/target[sealed:AccountTarget(accountId)
/DebtTarget(debtId)])。

## 交付物

1. **DueBanner widget**:新文件 `lib/account/presentation/widgets/due_banner.dart`
   - **纯展示 + 回调式**(推荐):widget 注入候选列表与回调,不做导航/对话框——
     `DueBanner({required List<DueCandidateView> candidates, required void
     Function(AccountTarget) onOpenCard, required void Function(DebtTarget) onOpenDebt,
     required VoidCallback onViewAll})`(命名可微调)。数据订阅由宿主页面负责。
   - 空态(列表空)→ `SizedBox.shrink()`(不渲染不占位)。
   - 收起态:单行,callout 行范式(参考既有 callout.warn 用法与债务页 F37 着色——
     先读 `lib/debt/` 下 F37 相关实现取**同一批语义令牌**);文案:
     - 无逾期:「⏰ N 笔待还 · 最近 X 天后」(X=最小正 daysLeft)
     - 有逾期:逾期子句前置「M 笔已逾期 N 天 · 共 K 笔待还」(具体合成措辞可打磨,
       语义=逾期优先呈现;N=最大逾期天数)
     - 行背景/左侧色条按**最紧条目档**着色(F37 桶:逾期/≤7 天红、≤15 天黄)
   - 展开态(点击收起条切换):明细行列表,每行 = [色条] title · ¥金额 ·
     「X 天后到期」/「逾期 N 天」(着色同桶);行点击 → 按 target 类型回调
     (AccountTarget→onOpenCard;DebtTarget→onOpenDebt);列表尾「查看全部」文字钮
     → onViewAll。默认收起。
   - 宽窄屏自适应(账户页两态同构;参考库内 SeparatedRow/自适应范式)。
   - 金额格式化用库内既有 money 格式工具(找到现有用法照抄)。
2. **accounts_page 接线**:改 `lib/account/presentation/pages/accounts_page.dart`
   - ListView 首项(`_AccountsHeader` 之前)插 DueBanner。
   - 候选来源:先看本页现有依赖注入习惯(getIt/构造)再选最小侵入方式拿到
     `DueCandidateProvider`,订阅 stream → setState/局部状态刷新(注意 dispose 取消;
     RouteAware didPopNext 既有逻辑不动)。
   - 回调接线:onOpenCard → 按 accountId 从本页账户列表查对象,唤起
     `showCreditCardRepayDialog`(照本页 1339 行附近既有菜单还款流,含还款后
     候选自动消失验证);onOpenDebt → 跳债务详情(照库内 /debts/:id 路由用法);
     onViewAll → go('/inbox')(T4 并行在建,先按此路径写,路由 T4 交付)。
   - **不新增系统通知/不碰 core**。

## TDD(强制)

widget 测试(`test/account/presentation/widgets/due_banner_test.dart` + accounts_page
接线测试或既有页面测试扩展):空态不渲染/聚合文案(无逾期与有逾期两形)/逾期子句
前置/展开切换/明细行内容与着色/行点击回调分派/查看全部回调/收起默认态。

## 完成门

1. `flutter test test/account`(新测试+既有全绿)
2. `flutter analyze` 净增 0
3. 最终回复:文件清单、测试数字、语义令牌取自哪几处(与 F37 同源的证明)、偏离裁决。
