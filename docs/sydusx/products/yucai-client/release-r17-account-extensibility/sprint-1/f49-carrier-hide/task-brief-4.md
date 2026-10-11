# Task Brief T4 — 展示过滤 + 净资产钉死(FR-3)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。
先读 spec.md(FR-3)与 design.md(单元4/ADR-1)。T1 已落 `AccountVisibility.userVisible`(account/domain/account_visibility.dart)——本任务就是它的**全部生产接线**。

## 任务(TDD)
1. **消费点实查**:grep lib/ 全部「账户列表/账户选择器」渲染点(候选:accounts_page 列表分组、交易表单支付方式/账户下拉、转账目标、债务表单「关联账户」下拉、预算账户筛选、报表筛选、任何 DropDown/选择器吃 accounts 流处)。产出清单(文件:行),逐一判断:用户可见可选 → 经 `AccountVisibility.userVisible`;金额计算 → 不滤。
2. accounts_page:列表渲染前过滤(载体户行消失);分组小计=可见行之和(贷款组天然达标——载体隐藏后小计即剩余可见行,核对分组小计的既有计算路径确实基于被过滤后的列表;若小计来自独立全量查询,改为过滤后口径)。
3. 净资产钉死测试:构造含 isSystem=true 载体户(余额非零)的库 → 账户页/首页净资产 hero 与负债总额**逐位含载体余额**(对照不含时的数字断言不同)。

## 约束
只动接线点+测试;禁碰 account_detail_page(T6 已完)/debt_form(T2 已完)/repairs;**accounts_page 后续 T5 还要加徽标,改动保持克制**。
每步 analyze → scoped 测。

## 完成判据
消费点清单+接线说明入报告;净资产钉死测绿;载体行不可见 widget 测绿;analyze 零新增。
