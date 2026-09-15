# Sweep ledger — F27 onAccent sweep(75 处逐处判定)

> 2026-09-15。行号 = 迁移前基线(git grep 原始清单)。判定准则见 spec FR-1(①accent 面前景→onAccent / ②类目身份彩底固定白 / ③阴影·scrim·刻意深底 / ④其余语义)。
> 计数:**迁移 46 行全迁 + 1 行混合迁**(budget_list 筛选 chip accent 档迁 onAccent、negative 档保留白);**保留 28 行纯豁免 + 1 行混合保留**;共 75。剩余 grep 行 29,全部带豁免注释(FR-2 门,见收尾审计)。
> 主题口径:onAccent 暗 = #1A1408(金底深墨)/ 亮 = #FFFFFF(翡翠绿底白)。暗档白→深墨为**非等值修正**(design-v2 语义本意,spec Grill record 定案)。

## 一、迁移 → context.yucai.onAccent(FR-1① accent 面前景,46+1 处)

| # | 文件:行 | 面 | 处置 |
|---|---|---|---|
| 1 | budget/presentation/pages/budget_list_page.dart:473 | 状态筛选 chip 选中档(全部/正常 = accent 底) | `onBg = chipColor==accent ? onAccent : 白(②)` 混合行 |
| 2 | budget_list_page.dart:495 | 同上 icon | `onBg` 同上 |
| 3 | budget_list_page.dart:506 | 同上计数 | `onBg` 同上 |
| 4 | budget_list_page.dart:539 | _GoldButton icon(bg=accent) | onAccent |
| 5 | budget_list_page.dart:542 | _GoldButton label | onAccent |
| 6 | budget_list_page.dart:545 | _GoldButton foregroundColor | onAccent |
| 7 | budget_form_page.dart:693 | _GoldButton loading spinner | onAccent |
| 8 | budget_form_page.dart:694 | _GoldButton icon | onAccent |
| 9 | budget_form_page.dart:697 | _GoldButton label | onAccent |
| 10 | budget_form_page.dart:700 | _GoldButton foregroundColor | onAccent |
| 11 | budget_form_page.dart:702 | disabled 前景 Colors.white70 | `onAccent.withValues(alpha:0.7)`(白 70% 等比派生) |
| 12 | core/widgets/filter_bar.dart:89 | 共享筛选 pill 选中档(bg=accent) | onAccent(列表页统一模式,探针锚点) |
| 13 | core/widgets/debt_detail_widgets.dart:1636 | RecordPayment dialog 提交按钮(bg=accent) | onAccent |
| 14 | debt_form_page.dart:561 | mobile 提交按钮 foregroundColor | onAccent |
| 15 | debt_form_page.dart:569 | mobile 提交按钮 spinner | onAccent |
| 16 | debt_form_page.dart:647 | actions 卡「创建债务」foregroundColor | onAccent |
| 17 | debt_form_page.dart:1023 | _RadioCard 选中 icon tile(bg=accent) | onAccent |
| 18 | debt_form_page.dart:1343 | _ODFormSection 金序号块文字 | onAccent |
| 19 | receivable_form_page.dart:588 | mobile 提交按钮 foregroundColor | onAccent |
| 20 | receivable_form_page.dart:596 | mobile 提交按钮 spinner | onAccent |
| 21 | receivable_form_page.dart:681 | actions 卡「创建债权」foregroundColor | onAccent |
| 22 | receivable_form_page.dart:1026 | _RadioCard 选中 icon tile | onAccent |
| 23 | receivable_form_page.dart:1427 | _ODFormSection 金序号块文字 | onAccent |
| 24 | goal_detail_page.dart:186 | 「记一笔贡献」按钮(bg=accent) | onAccent |
| 25 | goal_form_page.dart:365 | 提交按钮 spinner | onAccent |
| 26 | goal_form_page.dart:367 | 提交按钮 check icon | onAccent |
| 27 | goal_form_page.dart:373 | 提交按钮 label | onAccent |
| 28 | goal_form_page.dart:377 | 提交按钮 foregroundColor | onAccent |
| 29 | goal_list_page.dart:371 | 类型筛选 chip 选中档(bg=accent) | onAccent |
| 30 | goal_list_page.dart:393 | 同上 icon | onAccent |
| 31 | goal_list_page.dart:404 | 同上计数 | onAccent |
| 32 | goal_list_page.dart:437 | _GoldButton icon | onAccent |
| 33 | goal_list_page.dart:440 | _GoldButton label | onAccent |
| 34 | goal_list_page.dart:443 | _GoldButton foregroundColor | onAccent |
| 35 | holding/goal_link_page.dart:954 | 「account 级」金徽标文字 | onAccent |
| 36 | holding/holdings_page.dart:823 | 模块 pill 激活档(bg=accent) | onAccent |
| 37 | holding/security_page.dart:116 | 创建 Security FAB icon(bg=accent) | onAccent |
| 38 | security_page.dart:475 | _Chip 激活档(bg=accent) | onAccent |
| 39 | security_page.dart:1198 | 创建 sheet 提交按钮 spinner | onAccent(补 foregroundColor=onAccent) |
| 40 | transaction/category_management_page.dart:350 | 主按钮文字(bg=accent;icon 已是 onAccent) | onAccent(口径统一,修既有半迁状态) |
| 41 | transaction_detail_page.dart:927 | _GoldButton 编辑 icon | onAccent |
| 42 | transaction_detail_page.dart:931 | _GoldButton 编辑文字 | onAccent |
| 43 | transactions_page.dart:587 | 「新增交易」按钮 icon | onAccent |
| 44 | transactions_page.dart:591 | 「新增交易」按钮文字 | onAccent |
| 45 | transactions_page.dart:1867 | 「应用筛选」foregroundColor | onAccent(探针锚点) |
| 46 | transaction_form_page.dart:1142 | _GoldSaveBtn 保存 icon | onAccent |
| 47 | transaction_form_page.dart:1146 | _GoldSaveBtn 保存文字 | onAccent |

## 二、保留 + 豁免注释(FR-1②③ / F15 承接,28+1 处)

### ② 类目/状态身份彩底固定白(15 处)

| # | 文件:行 | 面 | 豁免依据 |
|---|---|---|---|
| 1 | account_detail_page.dart:1901 | _TxnTypeIcon 品类方块(positive/negative/muted 底) | 类目身份彩底(OD .txn-cat 白 icon 惯例) |
| 2 | budget_detail_page.dart:563 | _StatusPill solid 档 icon | 状态身份彩底;当前调用均 soft,solid 分支备用 |
| 3 | budget_detail_page.dart:569 | _StatusPill solid 档文字 | 同上 |
| 4 | core/widgets/app_toast.dart:113 | toast icon(positive/negative/warn 底) | 类型身份彩底(既有注释,F27 补类目名) |
| 5 | app_toast.dart:119 | toast 文字 | 同上 |
| 6 | debt_detail_widgets.dart:1186 | 逾期行内确认 icon(negative 底) | 状态身份彩底 |
| 7 | debt_detail_widgets.dart:1191 | 逾期行内确认前景 | 同上 |
| 8 | goal_detail_page.dart:200 | 「标记完成」按钮(positive 底) | 状态身份彩底(非 accent 面) |
| 9 | settings/settings_page.dart:787 | 危险按钮(negative 底) | 状态身份彩底(R8 既有口径) |
| 10 | tag_color_picker.dart:47 | 色板选中 check | 预置中饱和身份色板(既有豁免注释) |
| 11 | category_management_page.dart:1828 | 色板选中 check | 同上 |
| 12 | transaction/category_chip.dart:71 | 选中 chip 前景 | 分类类目身份彩底 |
| 13 | transaction_form_page.dart:1491 | tag chip 选中 ✓ | tag 类目身份彩底(用户 hex) |
| 14 | transaction_form_page.dart:1498 | tag chip 选中文字 | 同上 |
| 15 | transaction_form_page.dart:1655 | 借贷平衡指示 icon(positive/negative 圆底) | 状态身份彩底 |

### ③ 阴影 / scrim / 刻意深底(5 处)

| # | 文件:行 | 面 | 豁免依据 |
|---|---|---|---|
| 1 | core/widgets/amortization_preview.dart:163 | 深色预览卡标题 | F4-P2/F15 固定深渐变面(#1F2228/#262A31),LIVE 面 |
| 2 | amortization_preview.dart:179 | 深色预览卡大数字 | 同上 |
| 3 | amortization_preview.dart:297 | 深色预览卡行本金 | 同上 |
| 4 | holding_detail_page.dart:1124 | 底部操作条黑投影 4% | 黑阴影豁免(暗底不可见 = v2 暗色无阴影) |
| 5 | settings/first_close_dialog.dart:26 | barrier scrim black@55% | 恒定暗遮罩(原型 --scrim;既有注释,F27 补类目名) |

### F15 深金卡内部白系(6 处,不碰,补行内标记)

| # | 文件:行 | 面 | 豁免依据 |
|---|---|---|---|
| 1 | debt_detail_widgets.dart:123 | 深金 hero 交易对手名 | F4-P2 文件头豁免清单(白系文本) |
| 2 | debt_detail_widgets.dart:169 | hero 剩余大数字 | 同上 |
| 3 | debt_detail_widgets.dart:193 | hero 进度轨道白 12% | 同上 |
| 4 | debt_detail_widgets.dart:194 | hero 进度值色白(ShaderMask 染金) | 同上 |
| 5 | debt_detail_widgets.dart:389 | hero 4-tile 白 4.5% 面 | 同上 |
| 6 | debt_detail_widgets.dart:390 | hero 4-tile 白 7% 描边 | 同上 |

### 既有豁免注释(2 处,不动)

| # | 文件:行 | 面 | 豁免依据 |
|---|---|---|---|
| 1 | debt_form_page.dart:974 | step dot 完成态 check | 既有注释「豁免双板共用」(落 surface/accent 混合,历次已裁) |
| 2 | receivable_form_page.dart:975 | 同上镜像 | 同上 |

## 三、探针(FR-3)

| 探针 | 位置 | 断言 |
|---|---|---|
| 1 | test/core/widgets/filter_bar_theme_follow_test.dart | 共享 FilterBar 选中 pill:暗 #1A1408 / 亮 #FFFFFF;未选中锚 muted(暗 #8B93A3 / 亮 #64748B) |
| 2 | test/transaction/presentation/widgets/list_query_widgets_test.dart(F27 探针组) | MobileFilterSheet「应用筛选」ElevatedButton foregroundColor:暗 #1A1408 / 亮 #FFFFFF |

既有色彩断言盘点:全 test/ 无对本次迁移面的白底断言(design_tokens_v2 锚令牌源值、first_close_dialog_test:141 锚 scrim 保留值 —— 均不需适配,未削)。

## 四、收尾审计

- `git grep -E 'Colors.(white|black)' -- lib/`(除 app_design/app_theme)= 29 行,逐行核验行内或邻近 ≤9 行含「豁免」注释 —— AUDIT OK。
- flutter analyze:428 issues(基线 429,-1;无新增)。
- 全量 flutter test:绿(基线 1683 + 探针 3 = 1686)。
