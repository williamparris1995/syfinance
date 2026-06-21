# screens/ 原型（v1，旧版）

这些是御财 UI 的**第一版原型**（v1）。

## ⚠️ 优先参考 OD（v2）

**Open Design 项目是最新版本（v2），优先参考。** 本目录仅在 OD 无对应页面时作为备份参考。

## 原型版本对照

| 模块 | screens (v1，本目录) | OD (v2，优先) |
|------|---------------------|---------------|
| 账户列表 | desktop-accounts.html / mobile-accounts.html | `yucai-account-prototype-65e6` (accounts.html) |
| 账户详情 | desktop-detail-account.html / mobile-detail-account.html | `yucai-account-prototype-65e6` (detail-account.html) |
| 账户表单 | desktop-form-account.html / mobile-form-account.html | `yucai-account-prototype-65e6` (form-account.html) |
| 交易列表 | desktop-transactions.html | `yucai-transaction-trisize-9d3e` (transactions.html + mobile/) |
| 交易详情 | desktop-detail-transaction.html | `yucai-transaction-trisize-9d3e` (detail-transaction.html) |
| 交易表单 | desktop-form-transaction.html | `yucai-transaction-trisize-9d3e` (form-transaction.html) |
| 分类管理 | （无） | `yucai-category-management-db5f` (desktop/tablet/mobile) |
| 其他 | dashboard/budget/debts/goals/investments/reports/settings | （OD 暂无，需时新建） |

## 已知差异（screens v1 vs OD v2）

- **账户 card 副标题**：screens = 机构·卡号尾号；OD = 机构·币种。**以 OD 为准。**
- **账户详情 hero**：screens = hero-sub（机构+卡号）；OD = hero-org（机构·币种·卡号）+ hero-fields 网格。**以 OD 为准。**
- **饼图**：screens 无；OD `yucai-account-prototype-65e6` 收支统计 panel 有饼图。**以 OD 为准。**

## OD 项目路径

`C:\Users\andy\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\`
- `yucai-account-prototype-65e6/`
- `yucai-transaction-trisize-9d3e/`
- `yucai-category-management-db5f/`
