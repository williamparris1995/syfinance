# Copy Ledger — F28 占位文案迁移清单

> 2026-09-15 实施记录。规范见同目录 spec.md「文案规范」表(FR-1~3)。
> 纯字符串迁移,零逻辑改动;路径相对 `yucai/client/`。

## 一、示例前缀 → 「例如：」(全角冒号) — 14 处

| # | 文件:行(迁移前) | 旧 | 新 |
|---|---|---|---|
| 1 | lib/account/presentation/widgets/category_fields.dart:251 | `如 华泰证券` | `例如：华泰证券` |
| 2 | lib/account/presentation/widgets/category_fields.dart:305 | `如 实物黄金 / 美元 USD` | `例如：实物黄金 / 美元 USD` |
| 3 | lib/account/presentation/pages/account_form_page.dart:491 | `补充说明,如账户用途、关联卡片、还款提醒等(可选)` | `补充说明，例如：账户用途、关联卡片、还款提醒等(可选)`(逗号同步全角) |
| 4 | lib/budget/presentation/pages/budget_form_page.dart:425 | `如:日常开销预算` | `例如：日常开销预算` |
| 5 | lib/goal/presentation/pages/goal_form_page.dart:550 | `如 紧急备用金` | `例如：紧急备用金` |
| 6 | lib/tag/presentation/pages/tag_page.dart:52 | `如:日常` | `例如：日常` |
| 7 | lib/template/presentation/widgets/template_form.dart:326 | `如 30` | `例如：30` |
| 8 | lib/template/presentation/widgets/template_form.dart:398 | `如:房租 / 工资` | `例如：房租 / 工资` |
| 9 | lib/debt/presentation/pages/debt_form_page.dart:676 | `如 招商银行 / 张三` | `例如：招商银行 / 张三` |
| 10 | lib/transaction/presentation/pages/transaction_form_page.dart:710 | `如招商银行、现金` | `例如：招商银行、现金` |
| 11 | 同上:713 | `如餐饮、交通` | `例如：餐饮、交通` |
| 12 | 同上:720 | `如招商银行、现金` | `例如：招商银行、现金` |
| 13 | 同上:723 | `如工资、理财收益` | `例如：工资、理财收益` |
| 14 | 同上:931 | `补充说明，例如聚餐人数、报销事由…` | `补充说明，例如：聚餐人数、报销事由…`(补全角冒号统一前缀) |

## 二、必填输入 → 「请输入X」 — 8 处

| # | 文件:行(迁移前) | 旧 | 新 |
|---|---|---|---|
| 1 | lib/backup/presentation/pages/backup_page.dart:72 | `密码` | `请输入密码` |
| 2 | lib/backup/presentation/pages/backup_page.dart:139 | `密码` | `请输入密码` |
| 3 | lib/settings/presentation/settings_page.dart:571 | `密码` | `请输入密码` |
| 4 | 同上:577 | `再次输入密码` | `请再次输入密码` |
| 5 | 同上:750 | `密码` | `请输入密码` |
| 6 | 同上:755 | `再次输入密码` | `请再次输入密码` |
| 7 | lib/debt/presentation/pages/receivable_form_page.dart:715 | `姓名 / 企业名称`(必填裸名词) | `请输入姓名 / 企业名称` |
| 8 | lib/transaction/presentation/pages/category_management_page.dart:1465 | `输入分类名称`(「输入X」混用式样) | `请输入分类名称` |

## 三、可选项括号全角→半角(仓内惯例) — 2 处

| # | 文件:行(迁移前) | 旧 | 新 |
|---|---|---|---|
| 1 | lib/debt/presentation/pages/receivable_form_page.dart:795 | `电话 / 邮箱（可选）` | `电话 / 邮箱(可选)` |
| 2 | 同上:803 | `借条编号 / 合同号（可选）` | `借条编号 / 合同号(可选)` |

## 四、空态散兵(标点修正,两族语义不动) — 2 处

| # | 文件:行 | 旧 | 新 |
|---|---|---|---|
| 1 | lib/budget/presentation/pages/budget_form_page.dart:513 | `暂无条目,点击下方「添加条目」开始` | `暂无条目，点击下方「添加条目」开始` |
| 2 | lib/holding/presentation/pages/performance_page.dart:515 | `已实现收益加载中或暂无数据,请稍后重试` | `已实现收益加载中或暂无数据，请稍后重试` |

空态「暂无X」(曾有/视图无数据)与「还没有X」(从未创建)两族共 ~50 处全数审查,除上述 2 处半角逗号外均合规,未动。

## 五、测试断言适配 — 3 文件 12 行(语义不削,只跟新文案)

| 文件:行 | 断言旧值 | 断言新值 |
|---|---|---|
| test/app/router_test.dart:1060,1219 | `如招商银行、现金` | `例如：招商银行、现金` |
| test/app/router_test.dart:1061,1220 | `如餐饮、交通` | `例如：餐饮、交通` |
| test/transaction/presentation/pages/transaction_form_page_test.dart:326,327 | 同上两条 | 同上两条 |
| integration_test/ui_record_form_test.dart:105,147 | `如招商银行、现金` | `例如：招商银行、现金` |
| integration_test/ui_record_form_test.dart:111 | `如餐饮、交通` | `例如：餐饮、交通` |
| integration_test/ui_record_form_test.dart:153,155 | `如工资、理财收益` | `例如：工资、理财收益` |

## 六、审查后保留(对规范表合规,不改)

- 搜索族「搜索X…」:搜索账户名…/搜索交易、账户…/搜索对手方…/搜索 symbol / 名称…(x2)/搜索描述…(默认);FilterBar 兜底 `搜索` 与 SearchField 默认 `搜索…`。
- 数值/格式裸值:`0.00`(多处,含 AmountInput 默认)、`0.0`、`2000`、`200000`/`60000`、`AAPL`、`Apple Inc.`、`NASDAQ / SH / HK`、`账单日 1-31`、`还款日 1-31`、`信用额度 0.00`、`年费 0.00`。
- 选择器式样「选择X」:选择账户/转入账户/支出分类/应收账户/来源账户/回款账户/信用卡账户/Loan 账户/(可多选) 两条/加载中…。
- 语义提示:选择债务后自动填充、钱从哪来/钱到哪去、无可用账户/无可用债务、补充说明(可选)、选择资产账户(不选则不自动入账)、暂无支出分类账户(需先创建 expense 账户)(半角括号按仓内惯例)。

## 七、偏差与边界记录

1. **helperText 2 处旧式前缀未迁**:`security_page.dart:1116 '如 AAPL'`、`trade_sheet_page.dart:614 '如 2 = 1 股拆为 2 股…'` — spec 盘点范围为 hintText+空态,helperText 属 labelText/errorText 邻域(scope boundary 排除),建议后续票处理。
2. **_ODField/_Field 标签旁 hint 描述**(如「向谁借的钱」「由顶部标签页决定」)为字段说明文本非输入占位,未动。
3. `settings_page.dart:719` dialog 正文「如需找回:设置 → …」含半角冒号 — 非 hintText/空态,超范围未动。
4. 空态两族按 grill 定案语义保留,未做统一化(防语义削损)。

## 自检门(FR-2)

- `grep "hintText" lib/ | grep '如:'` → 0 命中;`'例如:'`(半角) → 0 命中。
- `hintText: '密码'` / `hintText: '再次输入密码'`(lib+test) → 0 命中。
- lib 内 `'如 `/`'如:`/`如招商`/`，如` 旧式前缀 → 0 命中(仅剩注释与上述 helperText 边界 2 处)。
