---
feature: f59-shell-nav-sweep
status: confirmed
---

# F59 全量扫页 — spec

> 依据:F58 已落范式(顶栏三段可点面包屑/DetailTitleSync/FormLeaveGuard/FloatingActionDock)+ 六项用户裁定(Grill record)。OD 依据:f59-form-nav(表单页)/f59-flat-compare(模型 C' 终局)。

## ADDED Requirements

### Requirement: FR-1 统一悬浮簇模型 C'(全平铺+视觉分级,零菜单)
- [ ] 所有详情页右下悬浮簇 SHALL 为竖排**全圆**钮三段式:**主操作金圆 52**(每页必有,居底)→ 高频次级钮 44 圆(正常亮度)→ **细分隔线** → 低频/危险钮 44 圆(**降饱和淡显**,危险项置顶离主钮最远);hover 恢复亮度;一切操作**零菜单零折叠一步直达**,tooltip 全覆盖;簇常驻不随滚动;页面底部留白 SHALL ≥ 满配簇高 + 28 + 冗余。

#### Scenario: 账户详情满配六钮
- GIVEN 活跃账户详情(记一笔/编辑/转账/复制/关闭/删除)
- THEN 右下竖排:记一笔(金圆)→ 编辑/转账(正常亮度)→ 分隔线 → 复制/关闭/删除(淡显,删除最顶);点删除直达确认弹窗,无中间菜单

#### Scenario: 淡显钮 hover 反馈
- GIVEN 簇中降饱和淡显钮
- WHEN 悬停
- THEN 亮度恢复 + tooltip 显示;点击正常触发

### Requirement: FR-2 FloatingActionDock 组件升级 + F58 三页回改
- [ ] design_kit FloatingActionDock SHALL 升级支持分级次级(正常/淡显两组 + 内置分隔线),次级钮改全圆;F58 已迁三页 SHALL 按模型 C' 回改:债务=立即记账+编辑+[删除]淡显;债权=收款+编辑+[删除]淡显;账户=记一笔+编辑/转账+[复制/关闭/删除]淡显(归档降级=仅删除?归档操作集照 F58 语义映射到平铺:仅「更多」模型退役后,归档=复制/重新激活/删除 全淡显无主操作可用——主操作记一笔禁用在场)。

#### Scenario: 债务页菜单退役
- GIVEN 债务详情(F58 版「更多」菜单含删除)
- THEN 迁移后无菜单,删除为淡显常驻钮,直达确认弹窗

### Requirement: FR-3 loading/error 态恒渲染全禁用
- [ ] 全部详情页(含账户页改齐)loading/error 态 SHALL 恒渲染悬浮簇,全部动作禁用(半透明降权),与 F58 债务/债权页口径一致。

### Requirement: FR-4 其余详情页迁移(逐页映射)
- [ ] 各页 SHALL 按统一模型迁移且操作零丢失:budget=编辑(主)+[删除]淡显;goal=**完成**(主,checkCircle)+编辑+[复制/删除]淡显(已完成态主钮禁用);transaction=编辑(主)+[删除/复制(按现状)]淡显+page-head「返回」链接退役;holding=加仓(主)+减仓/清仓+[删除]淡显,**底部 sticky 操作条退役**;security/trade_sheet/performance/goal_link 按「list 型页面维持现状、detail 型照模型」的判据处置(spec 扫页清单逐页列)。

#### Scenario: holding 操作条退役
- GIVEN 持仓详情(现状底部加仓/减仓/清仓文字操作条)
- THEN 操作条退役,右下簇=加仓(金圆)+减仓/清仓+[删除]淡显,功能零丢失

### Requirement: FR-5 表单页收敛(三级面包屑+守卫+无 dock)
- [ ] 全部表单页(new/edit)SHALL:顶栏面包屑注入第三级(新增=「新增债务」类;编辑=「编辑 · 实体名」);自带 AppBar 导航退役;**FormLeaveGuard 全量接线**(脏态任何离开路径弹确认,净态直接走);表单页**无悬浮簇**(操作语义=保存/取消在表单底部)。

#### Scenario: 编辑表单脏态拦截
- GIVEN 用户在编辑债务表单修改过字段
- WHEN 点击顶栏面包屑「债务管理」
- THEN 弹「未保存的修改」确认(放弃修改/继续编辑);净态同操作直接离开

### Requirement: FR-6 categories/订阅管理特例收敛
- [ ] `_isCategoryManagement` hideTopBar 特例 SHALL 移除:全局顶栏以 location 覆盖面包屑(「交易 › 分类管理」「交易 › 订阅管理」,照 `_isSubscriptionManagement` 先例);两页自带专属 topbar 的 crumb 部分退役,页面头(h1/说明/操作钮)保留为**内容头**(非导航)。

### Requirement: FR-7 页面内返回链接退役
- [ ] 详情页内「‹ 返回 XX 列表」类链接(transaction detail 等)SHALL 退役,回退统一走顶栏面包屑 page 级。

## NFR

### Requirement: NFR-1 令牌与形状合规
- [ ] 簇三段视觉全走令牌(金渐变/阴影/surface/border/淡显=降饱和透明度令牌化);全圆统一;design_kit 零御财常量。

### Requirement: NFR-2 可达性
- [ ] 淡显钮 SHALL 可聚焦可键盘触发(键盘焦点时视觉不淡);tooltip 全覆盖。

### Requirement: NFR-3 回归门
- [ ] flutter test 全绿 + analyze 基线 + `make client-e2e`;波及金图重录;窄屏 compact 走查。

## Feasibility

technical 可行(FloatingActionDock 小幅 API 扩展+三页回改为配置变化;表单守卫机制 F58 已备);economic 可行(单 sprint 票,~15 文件);operational 可行(e2e 管道既有;用户走查项=满配 6 钮高度实机感受)。

## Out of scope

- 列表页创建入口/顶栏创建钮 — owner: none(现状) — F58 定案不动。
- 窄屏底栏改造 — owner: none(现状)。
- A12 存量入口缺失(列表页「记一笔」等文本入口)— owner: none(存量软发现,非本票引入;F59 不扩入口,后续票)。
- account 表单三级面包屑经列表入口不可见(F-2 评审裁定)— owner: 后续路由票 — excluded because: AccountFormPage 自 F52 起为页面内 Navigator.push(预设参数构造注入),无 GoRouter 路由,`_isFormShapedLocation` 不命中;注入/守卫/AppBar 退役均已接线,路由补全即自动生效,路由改造超本票「纯 UI」范围。
- security 行情刷新钮重构 — owner: F59 扫页清单处置(若 list 型则维持)。

## Grill record

- loading/error 恒渲染 vs 仅 loaded — challenged: spinner 页摆灰簇是否噪音 — defended: 用户「同意推荐」(恒渲染禁用;操作锚点恒定+禁用语言已有)。
- 表单页形态 — challenged: 视觉伴侣确认(面包屑三级/守卫/无 dock;套件 transaction-form 三级先例佐证) — defended: 用户过 f59-form-nav 页「同意推荐」。
- 统一模型 B(两钮+菜单) vs C'(全平铺+分级) — challenged: 用户质疑「为什么需要更多按钮」→ 直陈两条路硬代价(菜单两击/隐藏 vs 满配 330px 高度+裸图标) — defended: 用户拍 C'(一切零点击可见可达,形态绝对统一;F58 三页回改联动)。
- goal 主操作 — challenged: 完成 vs 编辑进金圆 — defended: 用户选 A(完成,该页最有价值动作)。
- holding 归宿 — challenged: 免 dock 保留操作条 vs 并入统一 — defended: 用户「同意」随模型消解(操作条退役,文字标签代价知情)。
- F58 三页回改 — 随 C' 拍板自动成立(用户裁定统一性优先,已迁页不豁免)。
