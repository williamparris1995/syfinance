# Task Brief A — F50 debt 垂直片(entity 字段+占用纯函数+schema v13+映射+sync keep-existing)

## 工作区(严格遵守)

- 一切操作在 git worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f50`(branch `feature/r17-f50`)
- 客户端代码根:`yucai/client/`
- **禁止**:改 `yucai/proto/**`、`yucai/server/**`;碰主仓 checkout;`git commit`(控制器负责)

## 需求语义(spec FR-1/FR-2,design ADR-1/ADR-2)

1. `Debt` 实体(`yucai/client/lib/debt/domain/entities/debt_entity.dart`)新增 `final bool countsTowardCardLimit;`——构造默认 **true**,参与 equals/copyWith(照实体既有字段范式,该文件 line 100 附近有 progressRatio 等计算字段可参照)。
2. `yucai/client/lib/debt/domain/debt_query.dart` 新增纯函数:

```
/// 卡贷未出账占用(银行口径:仅剩余本金,期表口径;开关关的不计)。
int cardLoanOccupationCents(List<Debt> debts, String cardId)
```

过滤:`d.subtype == DebtSubtypes.cardLoan && d.collectionAccountId == cardId && d.countsTowardCardLimit`;求和 `d.remainingPrincipalCents`。**不得**使用载体户余额或 unpaidInterestCents。

3. drift schema(`yucai/client/lib/core/localdb/app_database.dart`,现 `schemaVersion => 12` → **13**):debts 表加列 `countsToward_card_limit` **INTEGER NOT NULL DEFAULT 1**(照该文件既有 MigrationStrategy 范式写 onUpgrade 分支;表定义类在 debt/data 或 core/localdb 下,自行定位 debts 表 drift 类)。
4. `yucai/client/lib/debt/data/debt_local_ds.dart` 及 `debt/data/mappers/`:行↔实体映射双向透出新字段(读行默认 true 兜底空值)。
5. **sync keep-existing**:定位债从 proto 重建/覆盖本地行的 applier 路径(R10 sync engine;grep proto Debt 映射到本地实体的代码)。该新列不在 proto 里——applier 重建行时必须**保留本地现值**(keep-existing);本地不存在的新拉取行取默认 true。若 applier 以「proto 全字段构造实体」方式覆写,需在映射处显式透传本地值。加注释说明该约束(防将来 proto 化前被误清)。

## TDD(强制)

先写失败测试再实现;每文件 RED→GREEN 后立即单独跑,再跑模块套件。测试落位照既有目录(`yucai/client/test/debt/...` 自行对齐):

- `cardLoanOccupationCents` 四组 fixtures(用 Debt 测试构造helper;金额用真实校准数,单位 cents):
  a. **平安真值**:卡欠款 31,963 cents 与挂接三笔(215,368 / 454,032 / 425,807 cents 剩余本金,开关开)+ 一笔 2,968,344 cents 开关**关** → occupation == 1,095,207 cents;再断言卡可用(50,0000,000−319.63−10,952.07)== 3,872,830 cents(组合进一个用例即可)
  b. **e招贷零占用**:collectionAccountId 为空的 2,606,286 cents 债 + 招行卡 → occupation == 0
  c. **开关排除**:同卡两债一开一关 → 只计开的
  d. **subtype 过滤**:同卡一笔 cashInstallment 债不计入
- schema 迁移测试:照库内既有 schemaVersion 迁移测范式(如有);没有则最少验证 v13 升级路径不抛
- sync keep-existing 回归:模拟 proto 重建行(不含该字段)→ 本地值保留;新行 → 默认 true

## 完成标准

- `cd yucai/client && flutter test test/debt`(或对应目录)全绿;新测试文件单独跑过 RED(先失败后过)
- `flutter analyze` 无新增 error/warning(基线既有 info 忽略)
- 汇报:改动文件清单 + 每处要点一行 + 测试输出摘要(含 RED 证据)+ sync applier 定位到的文件路径
