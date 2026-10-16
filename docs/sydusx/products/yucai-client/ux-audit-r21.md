# 御财 Flutter 客户端 UX 交互规范符合性审计报告(R21)

审计依据:`docs/sydusx/products/yucai-client/ux-interaction.md`(A 表单容器/B 组织/C 选择器/D 导航/E 反馈/F 三态)。全部结论基于 worktree `yucai/client` 实读代码，证据均为 file:line。已知拍板项未误报：F59 详情页右下悬浮簇、R19 面包屑、F52 预设卡片。

## 汇总表

| 页面 | A容器 | B组织 | C选择器 | D导航 | E反馈 | F三态 | 最重问题 |
|---|---|---|---|---|---|---|---|
| accounts_page | ✓ | ✓ | ✓ | ✓ | ANTI④可逆确认 | ✗错混空 | 重新激活(可逆)也弹确认 |
| account_detail_page | ✓ | ✓ | ✓ | ✓ | ✗toast错 | ✗无重试 | 错误态纯文案无重试 |
| account_form_page | ✓整页 | ✓ | ANTI①归属下拉 | ✓守卫 | ✓ | — | 2 值「归属」用下拉 |
| transactions_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | 导出死按钮(minor) |
| transaction_form_page | ✓ | ✓ | ✓ | **ANTI**返回链接+无守卫 | ✓行内+预览 | — | ‹ 返回残留·脏态无确认 |
| transaction_detail_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✗无重试 | 错误态无重试 |
| category_management_page | ✓按端sheet/drawer | ✓ | ? | ✓ | ✓ | ✓ | 导入模板死按钮(minor) |
| debts_page | ✓ | ✓ | ✓(排序popup minor) | ✓ | ✓ | ✗错混空 | DebtError 空列表→空态 |
| debt_form_page | ✓整页+wizard | ✓ | ✓ | ✓守卫 | **ANTI①**toast校验 | — | 提交校验全走 toast |
| debt_detail_page | ✓dialog | ✓ | ✓ | ✓ | ✗过早成功toast | ✗无重试 | dispatch 即弹成功 toast |
| receivables_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✗错混空 | 同 debts 镜像 |
| receivable_form_page | ✓ | ✓ | ✓ | ✓守卫 | **ANTI①**toast校验 | — | 同 debt_form |
| receivable_detail_page | ✓ | ✓ | ✓ | ✓ | ✗ | ✗无重试 | 同 debt_detail |
| budget_form_page | ✓ | ✓ | ✓ | ✓守卫 | ✓钮随可提交禁用 | — | — |
| budget_list_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | — |
| budget_detail_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✗无重试 | 错误态无重试 |
| goal_form_page | ✓ | ✓ | ✓类型卡 | ✓守卫 | **ANTI①**toast校验 | — | 按钮未随 _canSubmit 禁用 |
| goal_list_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | — |
| goal_detail_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✗无重试 | 错误态无重试 |
| holdings_page | ✓ | **ANTI②**tab导航 | ✓ | ✓ | ✓ | ✗空态指错+无重试 | HoldingModuleTabs 做导航 |
| holding_detail_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✗无重试 | 错误态无重试 |
| security_page | ✓sheet | **ANTI②**tab导航 | ✓7项下拉 | ✓ | **ANTI①**sheet内toast | ✓ | toast 校验+tab导航 |
| trade_sheet_page | ✓ | ✓ | ✓跨币种灰显 | ✓守卫 | **ANTI①**toast校验 | — | 余额不足不灰显提交钮 |
| performance_page | — | **ANTI②**tab导航 | ✓ | ✓ | ✓ | ✗无重试 | tab导航+无重试 |
| goal_link_page | ✓ | **ANTI②**tab导航 | ✓ | ✓ | ✓ | ✓ | tab导航 |
| report_page | — | ✓月/年分段 | ✓ | ✓ | ✓ | ✓✓ | — |
| financial_report_page | — | ✓ | ✓ | ✓ | ✓ | ✓✓ | — |
| tag_page | ✓1-2字段dialog | ✓ | ✓ | ✓ | ✗dialog内SnackBar | ✓ | 空名称→SnackBar |
| template_page | ✓dialog | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| subscription_center_page | — | ✓ | ✓ | ✓ | ✓可逆直接做 | ✓ | — |
| inbox_page | — | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| login_page | ✓ | ✓ | ✓ | ✓ | ✗SnackBar渠道 | — | 错误走底部 SnackBar |
| binding_page | ✓ | ✓状态机卡 | ✓ | ✓ | ✓失败可重试 | ✓ | — |
| conflict_panel_page | ✓ | ✓ | ✓ | ✓ | ✓ | ✓重试 | — |
| backup_page | ✓dialog | ✓ | ✓ | ✓ | ✓ | ✓空/错重试 | — |
| backup_settings_page | ✓ | ✓ | **ANTI①**4值下拉 | **ANTI**自制返回条 | ✓ | ✓重试 | ‹ 返回条残留 |
| settings_page | ✓ | ✓ | **ANTI①**4值下拉(同页不一致) | ✓ | ✗SnackBar混用 | — | 频率下拉 vs 同页全分段 |
| home_page | — | ✓ | ✓ | ✓ | ✓ | ✗面板无重试 | 错误面板“稍后重试”无钮 |

共享组件：command_palette ✓✓ / form_leave_guard ✓✓ / debt_list_widgets ✓(排序 4 态 popup 轻微)/ debt_detail_widgets ✓(「登记一笔」redirect toast ✗ minor)/ credit_card_statement_panel ✓✓(降级“去设置”CTA)。

## ANTI-pattern 详单

**1. D ANTI:「‹ 返回」链接残留 + 脏表单无离开确认 — transaction_form_page(最高频表单)**
- 证据:`transaction_form_page.dart:1381-1398`(_PageHead 渲染 chevronLeft+「返回」 InkWell);全文件无 FormLeaveGuard(grep 全库仅 debt/receivable/account/budget/goal/trade_sheet 表单有，见 `form_leave_guard.dart` 引用清单)。
- 现象：规范 D 明令「『‹ 返回』链接禁用；脏表单任何离开路径先确认」。记一笔是全应用使用频率最高的表单，却是六表单族中唯一自带返回条、且唯一无脏态守卫的——填了一半点「返回/取消」直接丢弃，零确认。注释自述“OD page-head:返回链接”是原型遗留。
- 建议：删 _PageHead 的返回 InkWell(面包屑/系统返回已有)；补 FormLeaveGuard + _dirty 追踪(照 debt_form_page.dart:1041 接法，十余行)。

**2. D ANTI:自制返回条残留 — backup_settings_page**
- 证据:`backup_settings_page.dart:99-103`(IconButton tooltip「返回」+ chevronLeft + context.pop),文件头注释(19 行)仍写“topbar(返回 + 标题)”。其余设置子页(tag/template/backup)均已按 F59 退役。
- 现象：与同目录 backup_page.dart:255「返回箭头退役」不一致，同类页面一处有一处无(A② 同款不一致)。
- 建议：删 _topbar 的返回钮，回退交顶栏面包屑。

**3. B ANTI②:tab 做导航 — holding 模块 4 页**
- 证据:`holding_module_tabs.dart:11-15,40`(4 个 _Tab 持路由，onTap `context.go(t.route)`);挂载于 `holdings_page.dart:123`、`security_page.dart`、`performance_page.dart:131`、`goal_link_page.dart:99`。头注自述“页内 tab 导航(替代二级侧栏)”。
- 现象：规范 B2「tab 不做导航(导航归面包屑/侧栏)」。这是刻意设计决策(替代二级侧栏)，但按现行规范属命中项——需产品拍板：要么规范补“模块内 tab”豁免条款，要么改面包屑/侧栏承载。
- 建议：若保留，在 ux-interaction.md B2 增加模块内多页签例外；若不保留，收编入侧栏分组。

**4. E ANTI①:提交后集中报错(toast 承载字段校验)— 5 个表单**
- 证据：
  - `debt_form_page.dart:806-874`(_submit 8 个 `AppToast.show(...'请填写债权方'...)` 顺序报错)；
  - `receivable_form_page.dart:449-489`(同款 7 个)；
  - `goal_form_page.dart:286-301`(toast)+ `:406`(提交钮 `onPressed: submitting ? null : _submit`,未随 `_canSubmit` 禁用——对比 budget_form_page.dart:447 `disabled: submitting || !canSubmit` 是正确做法)；
  - `trade_sheet_page.dart:285-374`(注释自认“对齐 receivable_form._submit toast 模式”)；
  - `security_page.dart:999-1006`(CreateSecuritySheet 内 symbol/名称 toast)。
- 现象：规范 E1「行内即时校验(失焦即验+原因)」。这些表单的字段级错误不在字段旁显示，而是提交时逐条弹右上角 toast,用户需自己找字段。transaction_form_page(dropdown validator 请选择X、金额 validator)证明同库行内校验链路成熟。
- 建议：给必填字段补 validator + autovalidateMode.onUserInteraction,提交钮照 budget_form 随 _canSubmit 禁用；toast 仅保留服务端错误。

**5. E ANTI④:确认弹窗用于可逆操作 — 账户关闭/重新激活**
- 证据:`accounts_page.dart:514-553`(_confirmClose)、`:556-592`(_reactivate);`account_detail_page.dart:2777-2821`、`:2825-2867` 同款。
- 现象：关闭=归档，重新激活与其互为逆操作，两者都有确认弹窗。规范 E3「可逆 → 直接做+可撤销提示」。删除账户(不可逆)的确认弹窗(:414-434)是正确保留。
- 建议：激活直接执行+toast「已重新激活」；关闭可保留确认(影响统计口径)但文案列后果，或同样直做+「已归档，可随时重新激活」toast。

**6. C ANTI①:2-4 选项用下拉 — 3 处**
- 证据：
  - `account_form_page.dart:792-805` 归属下拉，`value_objects.dart:63` `enum Ownership { personal, joint }` 仅 2 值(该页同屏的账户类型 10 值用 TypeTabs 卡片、币种 8 值下拉均正确)；
  - `settings_page.dart:1202-1236` 汇率同步频率下拉(1h/8h/12h/24h 4 值)——**同页**主题模式(3 值)、关闭行为(2 值)、扫描间隔(3 值)、提前天数(4 值)、重复间隔(4 值)全部用 SegmentedButton(:179/:295/:319/:347/:369),同页两种形态表达同一控件维度；
  - `backup_settings_page.dart:328-381` 备份频率下拉(12h/24h/48h/7天 4 值)。
- 建议：归属改 2 段 SegmentedButton;两个频率下拉改 4 段 SegmentedButton(照同页托盘提醒间隔写法)。

**7. C ANTI②(半)：联动约束部分靠报错 — trade_sheet 资金账户余额**
- 证据：跨币种账户已正确灰显(`trade_sheet_page.dart:550` enabled:false + helperText「币种一致 · 跨币种 disabled」✓);但余额不足仅提交时 toast(:312-314),提交钮(:831)不随 `_balanceInsufficient`(:274)禁用——尽管已有实时红色预览行(:776-826)。
- 建议:`onPressed: (submitting || _balanceInsufficient) ? null : _submit`,预览行红警已提供原因句，正好构成「灰显+原因」范式。

**8. F:错误态无重试按钮(系统性，9 页同款)+ 错误态伪装空态(3 页)**
- 证据(纯文案错误，无重试动作)：
  - `account_detail_page.dart:419-421`;`budget_detail_page.dart:95-104`;`goal_detail_page.dart:148-156`;`debt_detail_page.dart:203-205`;`receivable_detail_page.dart:185`;`holding_detail_page.dart:163-172`;`performance_page.dart:145-154`;`holdings_page.dart:203-231`(_errorState 无钮，对比 security_page.dart:316 有重试)；`home_page.dart:1356`(面板「加载失败/稍后重试」纯文案)。
  - 错误混同空态:`accounts_page.dart:608-618`(AccountError 且 accounts 为空 → 渲染「还没有账户」空态)、`debts_page.dart:131-141`、`receivables_page.dart:130`(_debtsOf 对 DebtError 返 state.last,为空即空态)。
- 现象：规范 F「错误(重试+不崩布局)」。库内已有标准答案：transactions_page `_ErrorView`(200-208, 重试+创建双钮)、budget_list/goal_list/security/report `_errorState`。详情页错误一般是网络问题，仅文字无法恢复。
- 建议：抽 core 共享 `ErrorRetryView(message, onRetry)`,9 处替换；列表页 bloc Error 且无 last 数据时走错误态而非空态。

**9. E ✗:toast/SnackBar 承载关键错误 + 渠道不一致**
- 证据:`accounts_page.dart:600-606`(删除/关闭失败仅 toast,无留驻错误面);`account_detail_page.dart:406-412`、`debt_detail_page.dart:186-190`(写失败 toast);`settings_page.dart:920-923/1411-1414` 与 `login_page.dart:31`、`tag_page.dart:115`、`template_page.dart:132`、`category_management_page.dart:150` 用底部 SnackBar,而全库标准是 AppToast 右上角(`app_toast.dart:11` 自述“全局轻提示”)。
- 现象：E③ 边缘 + 一致性破坏(同一应用两种 toast 形态、两种位置)。
- 建议：统一改 AppToast;写操作失败在页面留驻错误条(或对话框)，toast 只做轻提示。

**10. 次要：死按钮/redirect 按钮**
- `transactions_page.dart:179-183` 导出→「导出功能即将上线」;`category_management_page.dart:144` 导入模板→「即将就绪」;`debt_detail_widgets.dart:1519-1534` 「登记一笔还款/收款」按钮点击只弹「请在下方还款计划逐期记账」(E4 训人式——按钮存在但不做也不跳转)。
- `holdings_page.dart:195` 空态指引「点击右下角『+』添加第一笔持仓」，但创建入口已移至全局顶栏(:117 注释)，右下角无 "+"——指引指向不存在的控件。
- 建议：未上线功能先隐藏入口；「登记一笔」改为滚动定位到还款计划或直接移除；holdings 空态文案改「点击右上角『记一笔』」。

## ✓ 优秀先例(范式参照)

1. **F 三态完全体**:transactions_page `_ErrorView`(transactions_page.dart:200-208,重试+新建双 CTA)、budget_list_page `_emptyState/_errorState`(:317-378)、goal_list_page(:273-330)、security_page(:255-316)、report_page(:185-218,197-205 无数据与失败分治)。可作为 ErrorRetryView 抽取的蓝本。
2. **D 脏表单守卫家族**:`form_leave_guard.dart`(veto+PopScope 双通道确认)+ debt/receivable/account/budget/goal/trade_sheet 六表单接入 + DetailTitleSync 面包屑注入——transaction_form 补齐即闭环。
3. **E2 实时预览双范式**:debt_form `AmortizationPreview` 深色实时期供预览 + 脚注「前 5 期预览 · 实际以放款为准」(debt_form_page.dart:1919-1929);trade_sheet `_balanceRow` 资金账户余额流向 `¥X → ¥Y` + 不足红警(trade_sheet_page.dart:776-826);transaction_form 复式分录 live 预览。
4. **C1/C3 正确形态**：settings_page 的 SegmentedButton 系列(2/3/4 值全用分段，:179-:390)——同页 interval 下拉的反面教材恰是其正例；trade_sheet 跨币种账户 disabled+helperText(:543-550)「灰显+原因句」标准实现；F52 六项新建菜单(accounts_page.dart:1185-1243,用户已拍板范式)。
5. **E3 危险分级**：settings 清空数据三步确认流(settings_page.dart:714-835,警示→密码→最终确认，fail-closed)+ debt `confirmDeleteDebt` 列后果红钮(debt_delete_confirm.dart:11-44);subscription_center 暂停/恢复直接做(subscription_center_page.dart:310)是可逆操作的 correct 形态。
6. **B3 wizard 正用**:debt_form mobile `_StepIndicator` 三步进度指示(debt_form_page.dart:1940-2014),未用 tab 冒充步骤；debt subtype 冲突「可照常保存」软提示(:461-520)符合 E4「非训人」精神(有正当例外，不阻断)。

**总体**：28/38 页无 ANTI 命中；系统性缺口集中在两处——(1) F 错误态重试(9 页同款抄写级修复，建议抽共享组件);(2) E① toast 校验(5 表单，goal_form 顺手把提交钮接到 _canSubmit 即达标)。D 维两处返回条残留(transaction_form/backup_settings)是规范明令禁项，修复成本最低、收益最高。Holding 模块 tab 导航是唯一需要产品重新拍板的规范冲突项。