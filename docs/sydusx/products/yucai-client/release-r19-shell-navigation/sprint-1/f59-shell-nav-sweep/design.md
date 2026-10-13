# Design: F59 全量扫页

prototype: v17

> UI-scoped(Path B — OD 两页已拍板拷回);usage grounding:primary persona = Andy(单用户理财桌面键鼠),key-paths = ①账户详情满配簇一步直达删除 ②goal 标记完成金圆一步达 ③表单脏态离开拦截 ④holding 加仓直达。基准:`prototype/v17/ui/`(f59-flat-compare = 模型 C' 终局;f59-form-nav = 表单页)。

## Context

F58 已落壳层地基(三段面包屑/DetailTitleSync/FormLeaveGuard/FloatingActionDock 两钮版)。F59 六裁定(2026-10-13):模型 C' 全平铺+分级(零菜单)/goal=完成/holding 并入(操作条退役)/loading-error 恒渲染禁用/表单页三级面包屑+守卫+无簇/F58 三页回改。零 proto/schema 改动。

## Goals / Non-Goals

**Goals**:FR-1..7(统一簇 C'/组件升级+三页回改/恒渲染/其余页映射/表单页/categories·订阅/返回链接退役)+ NFR-1..3。
**Non-Goals**:列表页入口、底栏、A12 存量、security 行情刷新重构(list 型维持)。

## Decisions (ADRs)

- **ADR-1 FloatingActionDock C' 三段式 API**:参数改 `primary` + `secondary`(高频,正常亮度)+ `muted`(低频/危险,降饱和淡显,hover/焦点恢复);**分隔线组件内置**(muted 非空才渲染);次级钮**全圆**(半径 50%,v16 方圆 12 废除);tooltip 全覆盖;禁用语义 onTap=null 不变。*Alternatives*:分层列表 `List<DockTier>`(过度设计,页配置只有两组)/单列表+每项 tier 枚举(调用方排序负担)。*Grill*:菜单模型被用户否决(「为什么不是都平铺」)——组件不保留菜单位;页面层 AnchoredMenu 挂载随回改移除。
- **ADR-2 扫页处置表(判据:list 型维持/detail 型照模型/form 型面包屑+守卫)**:

| 页 | 型 | 处置 |
|---|---|---|
| debt/receivable/account(F58) | detail | 回改 C'(菜单退役,操作平铺;归档=主钮禁用+复制/重新激活/删除淡显) |
| budget / goal / transaction detail | detail | 编辑 / **完成** / 编辑 进金圆;余项淡显 |
| holding detail | detail | 加仓金圆+减仓/清仓+删除淡显;**底部操作条退役** |
| debt/receivable/account/budget/goal form + trade_sheet | form | 三级面包屑注入+FormLeaveGuard 接线+自带 AppBar 退役+无簇 |
| categories | list 特例 | location 覆盖面包屑「交易 › 分类管理」+hideTopBar 退役+页面头保留 |
| template(周期模板)/tag/backup | list 工具页 | 自带 topbar 返回箭头退役(面包屑回退),标题/操作钮保留为内容头;面包屑 location 覆盖 |
| 订阅中心 | list | 已合规,零改动 |
| security/performance/goal_link | 嵌入/list | 维持现状(无第二层导航) |

- **ADR-3 表单页第三级注入来源**:表单页 loaded/构建期经 DetailTitleSync 注入——新增态=页面类型串(「新增债务」,复用各表单 mobile 标题既有语义);编辑态=「编辑 · {实体名}」(实体加载完成后刷新,加载中「编辑债务」)。守卫=FormLeaveGuard 包表单 body(isDirty=表单脏标志;各表单已有 controller/字段变更追踪则复用,无则统一 `_dirty` bool 于 onChanged 首改置位)。*Alternatives*:route extra(鸡生蛋,F58 ADR-1 已否)/表单页自渲染标题条(违背退役主旨)。
- **ADR-4 恒渲染禁用改齐**:账户页 dock 移出 `AccountDetailLoaded` 门(loading/error 渲染全禁用簇),与债务/债权一致。

## HLD

| 单元 | 层 | 职责 |
|---|---|---|
| FloatingActionDock 升级 | design_kit | 三段式 API + 全圆 + 内置分隔线 + 淡显(hover/焦点恢复);单测更新 |
| 扫页迁移 ×N | client 各模块 | 各页照处置表:AppBar/返回条退役、簇挂载、标题注入、守卫接线 |
| 表单守卫接线 | client 各 form | FormLeaveGuard 包 body + dirty 标志 |
| 面包屑 location 覆盖 | app_shell | categories/template/tag/backup 覆盖条目;hideTopBar 全退役 |
| 回归门 | client | 金图重录 + e2e 断言更新 + 窄屏走查 |

依赖:design_kit 先行(T1),页面迁移依赖组件(T2+);面包屑覆盖与 hideTopBar 退役在 app_shell(独立任务)。

## LLD

**FloatingActionDock C' 契约**

```dart
class FloatingActionDock extends StatelessWidget {
  final DockAction primary;          // 金圆 52,居底
  final List<DockAction> secondary;  // 44 全圆,正常亮度
  final List<DockAction> muted;      // 44 全圆,降饱和淡显(hover/焦点恢复),置顶
  // Column: [ ...muted.reversed, divider?, ...secondary.reversed, primary ]
  // divider = 1px line 宽 20 居中(muted 空则无);间距 10 恒定
  // 淡显实现:Opacity(tokens 层透明度常量);Focus/Handler 恢复满透明度
}
```

**页面配置速查(LLD 操作映射)**:债务=记账(主)+编辑+[删除];债权=收款+编辑+[删除];账户=记一笔+编辑/转账+[复制/关闭/删除](归档:主禁用+[复制/重新激活/删除]);budget=编辑+[删除];goal=完成(已完成禁用)+编辑+[复制/删除];transaction=编辑+[删除/复制(按现状)];holding=加仓+减仓/清仓+[删除]。

**表单注入串**:新增=`'新增${_sem.entityNoun}'` 类(照各表单 mobile AppBar 标题);编辑加载后=`'编辑 · ${entityName}'`。

**测试钉点**:组件三段渲染/分隔线条件/淡显态(hover 恢复/禁用叠加)/全圆几何;每迁移页=无 AppBar+dock 映射+标题注入+守卫脏拦净放;表单=脏态面包屑弹框/净态直走;回改三页=菜单零残留(AnchoredMenu 引用清);categories/template/tag/backup=面包屑覆盖串+返回箭头零残留;金图重录;e2e 导航断言更新。

## Risks / Trade-offs

- [满配 6 钮遮挡底部内容] → 留白按满配高(~330+28+冗余≈370)逐页钉;e2e 末屏断言
- [金图大面积波及(全部详情+表单+工具页)] → 重录照 F9/F15 惯例,一次门内收口
- [表单 dirty 追踪不齐(各表单字段多)] → 统一「首改即脏」粗粒度 bool,不逐字段比对(保存/重置后复净由页面重置标志)
- [trade_sheet 表单型判定(提交后 pop 流)] → 守卫仅拦「脏态未提交离开」,提交流程既有 pop 不受影响(PopScope canPop 净态直放)
- [holding 操作条退役的可达性回退(文字→图标)] → 用户知情拍板;tooltip 全覆盖兜底

## Migration Plan

纯 UI 改动;回滚=revert。

## Open Questions

无(六裁定闭合;security 判据 list 型维持已入处置表)。
