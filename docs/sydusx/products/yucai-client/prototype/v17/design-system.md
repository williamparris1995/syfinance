# Prototype v17 — F59 全量扫页(表单页收敛 + 悬浮簇模型 C' 终局)

> tier: high-fi(design)· path: OD 管线(项目 `f59-form-nav` run `82509954` + `f59-flat-compare` run `522d891b`,2026-10-13;用户逐页过目拍板)。
> 底版:design-output-v2/ab 套件(transaction-form.html / budgets.html fork,零硬编码令牌,双主题)。

## 内容(F59 的 UI 事实源)

- **ui/f59-form-nav.html(表单页收敛)**:现状还原(两级面包屑+表单返回条,三问题)vs 推荐方案(三级面包屑「财务 › <a>债务管理</a> › 新增债务」/AppBar 退役/**无悬浮簇**/脏态确认对话框 F58 逐字形态,可点击演示;编辑态小卡「编辑 · 平安现金分期」)。用户拍板:同意推荐。
- **ui/f59-flat-compare.html(悬浮簇终局)**:模型 B(两钮+菜单)vs **模型 C'(全平铺+视觉分级,用户拍板)**——竖排全圆钮:主操作金圆 52(底)→ 高频次级 44 圆正常亮度 → 细分隔线 → 低频/危险 44 圆降饱和淡显(置顶);hover 恢复亮度+tooltip;账户满配 6 钮 ~330px 高度真实比例;其余页速览(goal 主操作=完成进金圆 拍板 A;holding 操作条退役并入模型 拍板同意)。

## 两组件契约见 components.md(FloatingActionDock C' 三段式 / CrumbNav 表单态)。

## Constraints(people / data / finance / process)

- **people**:单用户桌面键鼠;tooltip+键盘可达(淡显钮可聚焦,焦点态不淡);满配高度 720p ~46% 的代价用户知情拍板。
- **data**:零 schema/proto 改动;样例禁真实 PII(掩码卡号/虚构名)。
- **finance**:簇操作全复用既有资金流 handler;删除/关闭等不可逆操作确认弹窗兜底;holding 加/减/清仓语义原样迁移。
- **process**:脏表单离开必须先确认;表单页无簇(保存/取消在表单底部);回归门 test+analyze+e2e。

## CURRENT

v17(F59 全量扫票;六裁定 2026-10-13:C' 全平铺/goal=完成/holding 并入/恒渲染禁用/表单三级面包屑/F58 三页回改;v16 为 F58 存档)。
