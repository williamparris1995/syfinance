# Task Brief B — F50 债表单「计入挂接卡额度占用」开关

## 工作区(严格遵守)

- 一切操作在 git worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f50`(branch `feature/r17-f50`)
- 客户端代码根:`yucai/client/`;**禁止**改 proto/server、碰主仓、`git commit`
- 前置 TA 已落:`Debt.countsTowardCardLimit`(bool 默认 true)实体字段 + drift 列 + local_ds 读侧透出(**写侧 create/update 未加参数,本任务补全**)

## 需求(spec FR-2,design ADR-2/U3)

1. `debt/presentation/pages/debt_form_page.dart`:新增开关行「计入挂接卡额度占用」——**仅当** 表单当前 subtype==card_loan(信用卡分期)**且** 回款账户 collectionAccountId 非空(挂接了卡)时显示;默认开(新建/编辑既有 true 保持);helper 文案说明:银行备用金类独立额度不占卡额度的分期可置关。开关随表单保存写入。
2. 写侧接线:`DebtLocalDataSource.create/update` 及 repository 链路加 `countsTowardCardLimit` 透传(默认 true,不破坏既有调用点);form → bloc → repo → DS 全链路。
3. `debt/presentation/pages/debt_detail_page.dart`:顺手在挂接卡贷的详情页展示该开关当前值(只读一行,照页面既有信息行样式)。

## 已知坑(项目记忆)

- widget 测试:表单编辑推断读 **getIt 注册的仓库**,测试须 seed getIt(先例:yucai/client/test/debt/ 下既有 form 测试怎么 mock 就怎么来)
- 中文长行编辑陷阱:用 Edit 精确唯一锚点,勿 sed

## TDD(强制)

先失败测试再实现;单文件 RED→GREEN;完成后 `flutter test test/debt` 模块套件 + `flutter analyze` 无新增。测试至少:①非挂接/非卡贷不显示开关行 ②挂接卡贷显示且默认开 ③切换后保存 → DS 层读到新值(write 侧断言)④详情页只读行显示。

## 汇报

文件清单+要点、RED/GREEN 证据、模块套件与 analyze 结果。
