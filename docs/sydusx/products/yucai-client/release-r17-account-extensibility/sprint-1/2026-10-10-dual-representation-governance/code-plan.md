# Code Plan — F51

> 源:[spec.md](spec.md) + [design.md](design.md)。全部命令在 worktree `.claude/worktrees/r17-f51` 内执行。零 proto/server 改动、不迁移不删列、不回写。

## Tasks

- [ ] **TA 派生函数垂直片**(serial 先行)
  - `debt/domain`:`DerivedLoanFields` + `derivedLoanFields(List<Debt>, Map<String, DebtNextPeriod>)`(四值;下期=paid=0 最早含逾期,全无→null;无期表债月供计 0)
  - `holding/domain`:invest 两值纯函数(Σ成本/Σ市值,收投影不依赖仓库)
  - 测试:多债聚合(spec FR-1 数字)/无期表回退/全付清 null/逾期期计入/持仓聚合
- [ ] **TB 表单降级**(与 TC 并行)
  - `account_form_page`:编辑态挂接检测(getIt 仓库一次性取;测试坑记忆:getIt 须注册)→ loan/invest 组只读+派生值+提示条;提交组字段传 null(orAbsent 保留)
  - 测试:挂接才降级/新建态不降级/只读值=派生/保存 params 组字段 null 捕获
- [ ] **TC 两页读侧**(与 TB 并行)
  - accounts_page:新增 `_holdings` 拉取(照 `_debts` 模式)+ `derivedValueFor` 闭包前置 numValue 各 category 分支(null→原逻辑);汇总头/卡片走新估值
  - account_detail_page:loan/investment hero 与卡片估值同闭包;「持仓列表」占位(523)不碰
  - 测试:挂接账户三处逐分一致(spec FR-3 Scenario:列 stale 0 → 显示 Σ债剩余)/未挂接输出逐分不变(回归)
- [ ] **TD 收口全门**
  - 跨页一致性测试收口(U5)+ 全量 `flutter test` 绿 + analyze 不超基线 + `make client-e2e`

## 执行序

TA(serial)→ TB ∥ TC(并行子任务)→ TD(收口)。每 task:RED→GREEN→重构 + 完成即单文件测试 + 两轴评审。
