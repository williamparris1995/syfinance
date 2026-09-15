# Feature — F15 F4-P2 穿线收尾(R8 sprint-5)

> 2026-09-03 用户"继续"推进 R8 backlog。

## Description

F4 暗色迁移的 P2 回退点清零:剩余 321 处 `AppColors.*` 静态引用(暗色下 light-locked)迁移到 `context.yucai` 语义令牌;StatelessWidget 辅助方法补 context 形参穿线(debt_detail_widgets/debt_list_widgets 为主);顶层调色板常量(kHoldingTypeColors/kCategoryColors 等静态 Color 列表)context 化(取 theme 令牌或按语义映射)。F4 的"分析器驱动迁移引擎"与 theme-follow 探针测试可复用。

## Stories

- [x] S1: core/widgets 共享件迁移(T1:debt_detail/debt_list/debt_view_semantics/date_picker/conic/amortization + router)
- [x] S2: 模块页迁移(account/auth/backup/debt/holding/goal/report/tag/template/transaction + budget 调色板常量;T2 round1 48 文件 + fix1 补 5 文件(debts/receivables/receivable_detail/account_form/app_theme)= lib 53 文件,test 6 文件)
- [x] S3: 顶层调色板常量 context 化(kHoldingTypeColors/kCategoryColors 双板 accessor;语义常量令牌化,见 ledger)
- [x] S4: 回归门(theme-follow 探针 ×2(debt/transaction)+ 全量门;lib/ AppColors 代码引用 = 0,仅剩 1 注释豁免行)

## F4-P2 豁免总清单(T1+T2+fix1)

**对账口径**:lib/ `AppColors.` 代码引用清零(仅剩 1 纯注释行)+ lib/ 全部裸
`Color(0x…)` 字面量逐条对账 —— 每条必属以下三类之一(双板序列色组本身即迁移
产物,不入豁免):序列色双板常量(kRingGoldGradient/holding/category 三组)、
黑/深灰阴影、固定深色面、类目/品牌身份色。fix1 复验:清单外残留 = 0(对账
输出见任务报告;`_colorOf` 的 `0xFF000000 | v` 为用户数据 hex 解析表达式,
非静态色,不记)。

裁决标准:**暗色下可辨识且不刺眼**。分类:黑/深灰阴影(暗底天然不可见 = v2 暗色
「无阴影」设计,等效豁免)、固定深色面(OD 原型刻意深底卡,两主题一致)、类目身份色
(中饱和中间调,双板共用)。

### 黑/深灰阴影(保原值 + 行内注释)
- debt_list_widgets:卡面投影 #0A/#0D/#1A 1C1E21 系(T1,文件头清单)
- debt_detail_widgets:schedule 激活 chip 投影 #1A1C1E21(T2 补文件头条目)
- amortization_preview:卡面投影 #17000000(T2 补进文件头清单)
- home_page:摘要卡双层阴影 #0D/#05 1F2024(OD --shadow-card)
- debt_form_page / receivable_form_page:actions 卡投影 #0A1C1E21(×2/页)
- perf_curve_chart:range tab 激活投影 #0F1C1E21
- transaction_form_page:表单卡投影 #09000000(×2)+ 选中 chip #14000000
- category_management_page:选中 chip #14000000
- accounts_page:卡 hover 投影 #12000000
- app_theme:cardTheme 投影 #0D0F172A(fix1 补记;暗色 elevation=0 天然不可见)
- form_section:FormCard 投影 #0A000000(范围外文件,复用论证)
- data_card:卡投影 #14/#08 000000(范围外文件,复用论证)
- yucai_menu:菜单投影 #1F000000(×2,范围外文件,复用论证)
- app_toast:toast 投影 #33000000(范围外文件,悬浮 overlay)

### 固定深色面(OD 原型刻意深底,两主题一致;文件头/行内注释)——**已退役(F26,R12 sprint-1,2026-09-15)**:下述 home/账户详情两条深渐变面已迁 design-v2 §4 随主题形态,该两条豁免作废;其余条目(debt 深金渐变卡/LIVE 深渐变面等)仍在豁免期内。

- debt_detail_widgets:DebtDetailHero 深金渐变卡全套内景色(T1)
- amortization_preview:LIVE 预览深渐变卡全套内景色(T1+T2 补清单)
- account_detail_page:账户 hero 深渐变面 #1C1E21→#2A2D33 + 白系文本/白透描边
- home_page:净资产 hero 深渐变面(同款)+ white/white54 文本
- 报表图表 tooltip(income_expense_trend_chart/monthly_comparison_bar):
  固定墨色面 #0E1219(原 AppColors.sidebar 亮值)+ 固定浅灰字 #B8B5AD

### 类目/品牌身份色(中饱和,双板共用;行内注释)
- account_category_style:信用卡蓝 #6B8CCE / 定期橄榄 #8A8A6B / 黄金黄
  #C9A03D / 房产紫 #8C7BB5(语义位 positive/accent/negative/muted 已令牌化)
- tag_color_picker:预置 7 色板(固定品牌色)+ 选中白 check
- debt/receivable form 步骤条 done check 白字(亮板沿原样,暗板墨面可辨识)
- app_toast:白字白 icon(类型色底 toast 惯例,与 success/error 一致)

## 调色板常量裁决(T2)

- **kHoldingTypeColors**(holding_pie_chart):数据可视化序列色 → 双板
  (kRingGoldGradient/ringGoldGradientOf 同款)。亮板保 v1 原值;暗板
  _kHoldingTypeColorsDark 整组提亮一档(深金 #8A6D3B 在墨黑底 ≈3.5:1 不足)。
  取用走 **holdingTypeColorOf(context, type)**;落点选常量旁 accessor 而非
  YucaiTheme 扩展:序列色组随 holding 模块走(核心 theme 不 import 业务
  domain)。消费方:pie/detail/goal_link/performance/trade_sheet(split 复用
  bond 灰蓝槽,原 _kSplitColor/_kSplitSoft 局部常量删除)+ holding_detail
  trades tag/拆分按钮(fix1 收编最后 2 处裸 #6B7A8F)。
- **kCategoryColors**(category_breakdown_pie):同款双板 + **categoryColorsOf
  (context)**;暗板 _kCategoryColorsDark 与亮板顺序一一对应。
- **categoryColor(AccountCategory)**:签名 +context;语义位令牌化,身份色豁免(见上)。
- **tagColor(hex)**(tag/domain):fallback 改为必填参数,由 presentation 注入
  context.yucai.accent(domain 拿不到 context)。消费点:tag_card /
  tag_color_picker / transaction_detail_page / transaction_form_page / txn_row
  (5 处全穿线);category_management _colorOf 同款回退注入。
- **home _kIncomeColor/_kExpenseColor**:删除,语义令牌化 positive/negative
  (OD 亮板暖色退役,亮色即刻对齐 v2);_kCardShadow 黑阴影豁免。
- **budget _overBudgetRed/_kOverBudgetRed**:删除,令牌化 negative
  (brief 色 #C0392B 退役 —— 退役 F3 有意保留项,见 release.md:41「有意保留:
  超预算深红 #C0392B(文档化区分色)」,F4-P2 全局语义色统一时点退役;
  2 处测试断言改令牌断言)。
- **ringGoldGradientOf/_kRingGoldGradientDark**:前瞻 API 零消费方,保留勿删
  (T1 review 决议,T2 补注释)。

## fix round 1 补记(review 3 FAIL)

- P1:holding_pie_chart `_LegendRow` 恢复 dim 三元语义(dim 行 label/数值同取
  muted 置灰,常规行同取 fg;round1 误"合并取值"致 dim 数值亮/常规标签灰)。
- P2 补迁 6 处:debts_page 车贷 badge 底 #EEF0F2 → muted 10% 派生 + 信用卡/
  亲友借款透底 #1AC4544D/#1A2D8A6E → 令牌 10% 派生;receivables_page 商业借款
  #3A6695/#EAF0F6 → info 令牌 + 10% 派生 + avatar;receivable_detail_page
  avatar #3A6695 → info;account_form_page 示例正文 #7A6433 → muted。
- 缩进错位 2 处平掉(debt/receivable form `_dot` check 注释块)。

## 约束外裁决补记(T2 round1,超出简报字面范围、方向一致的顺手项)

- **form_section.dart FormActions spinner**:`Colors.white` → `context.yucai.onAccent`
  (FilledButton 底 = accent,暗色鎏金底上白字对比不足;该文件本因黑阴影豁免被
  触及,spinner 同点顺手修正)。
- **app_toast.dart 警示金 #CF9B3A** → `context.yucai.warn` 令牌(简报二选一裁
  决中取"映射"支:#CF9B3A 非 v2 accentDeep 亮值,亦非固定深面,而是警示语义 →
  warn 令牌同语义,亮 #D97706 琥珀 / 暗 #FBBF24 自动提亮)。
  同款顺手项:trade_sheet_page 提交 spinner 白 → onAccent(见任务报告)。

## title

F15 F4-P2 穿线收尾(light-locked 清零)

## keywords

f4p2, theme-threading, context-yucai, light-locked, dark-mode, palette-constants, F15


## holistic review(2026-09-03)PASS 记录

两轴 PASS,fix list 空。follow-up 记账:
- **onAccent sweep backlog 票(P2)**:Colors.white(Material 常量,不在 AppColors/裸色对账口径)落在 accent/positive/negative 跟随底上,暗色对比 ≈2:1——~20+ 处/14 文件(v1 存量;含 filter_bar 选中 pill/全部表单主 CTA/debt 逾期 chip;首刀切 category_management_page:350 同行 icon 已 onAccent 而 Text 未迁的不一致);binding_page Colors.green/red 令牌化同票。
- sprint/release 目标表述口径修正:「light-locked(AppColors/裸色)清零」而非「无残留亮色点」——Colors.* 口径遗留由上票承接。
- 陈旧头注释 3 处(budget_form/budget_list/goal_list「复用 AppColors」)**已修**。
