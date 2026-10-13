# F59 code-plan

> 依据 spec(FR-1..7)+ design(ADR-1..4)+ 原型 v17。worktree r19-f59。全任务 TDD;每任务两轴评审。

## Tasks

- [x] **T1 design_kit:FloatingActionDock C' 升级**(增量 API:`muted` 组+内置分隔线新增;`secondary` 保留名,视觉方圆→全圆;淡显 hover/焦点恢复)——**向后兼容**,F58 三页旧调用全程可编译
- [x] **T4 表单页接线**(debt/receivable/account/budget/goal form + trade_sheet):三级面包屑注入(新增串/编辑·实体名,DetailTitleSync)+ FormLeaveGuard 包 body(首改即脏)+ 自带 AppBar 导航退役 + 无簇
- [x] **T5 工具页+面包屑覆盖**(app_shell:categories/template/tag/backup location 覆盖条目 + hideTopBar 全退役;四页自带返回箭头退役,页面头保留)
- [x] **T2 F58 三页回改**(debt/receivable/account):C' 重配(muted 组+菜单 AnchoredMenu 移除)+账户恒渲染改齐(依赖 T1)
- [x] **T3 四 detail 迁移**(budget/goal/transaction/holding):金圆映射+淡显组+holding 操作条退役(依赖 T1)
- [x] **T6 回归门**:金图重录+全量+analyze+e2e+窄屏走查

## 并行编排

波1:T1 ∥ T4 ∥ T5(文件不交叠)→ 波2:T2 ∥ T3 → T6。
