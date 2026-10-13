---
feature: f58-shell-nav-foundation
status: confirmed
---

# F58 壳层导航地基+范式迁移 — spec

> 依据:OD 视觉伴侣 crumb-nav-variants(用户 2026-10-12 拍板形态 B);grill 两决策(见 Grill record)。R19 release Decisions 为上位事实源。

## ADDED Requirements

### Requirement: FR-1 顶栏面包屑全路径与 page 级回退
- [ ] 债务/债权/账户详情页顶栏面包屑 SHALL 显示全路径 `section › page › 当前级`:page 级可点(点击导航至对应列表 root),section 级为纯标签不可点,当前级加粗不可点(对齐套件 account-detail.html crumb 先例)。

#### Scenario: 债务详情点 page 级回列表
- GIVEN 用户位于债务详情 `/debts/:id`
- WHEN 点击顶栏面包屑「财务 › **债务管理** › 平安现金分期」中的「债务管理」
- THEN 导航至 `/debts` 列表,详情栈清理,列表页正常呈现

#### Scenario: section 级不可点
- GIVEN 用户位于债务详情页
- WHEN 点击/悬停面包屑「财务」段
- THEN 无导航动作、无可点视觉暗示(无 link 色/下划线/手型)

#### Scenario: 窄屏同样可点
- GIVEN 窗口宽度 < 1100(compact 顶栏,面包屑仍显示)
- WHEN 点击面包屑 page 级
- THEN 回退行为与桌面态一致

### Requirement: FR-2 detail 当前级标题注入与清理
- [ ] 详情页实体标题 SHALL 由页面注入顶栏(债务/债权=counterparty,账户=账户名);加载中或失败时显示占位「…」且不阻塞 page 级回退;页面离开后注入标题 SHALL 被清理,不残留到后续页面。

#### Scenario: 加载完成后显示实体名
- GIVEN 债务详情数据加载完成
- THEN 顶栏面包屑当前级显示该债务 counterparty

#### Scenario: 加载中不阻塞回退
- GIVEN 债务详情数据加载中
- THEN 当前级显示「…」,「债务管理」page 级链接来自 branch 元数据静态数据,可点回退

#### Scenario: 离开清理防残留
- GIVEN 用户从债务详情导航至账户列表
- THEN 顶栏不残留上一实体的标题(面包屑回到 branch 元数据口径)

### Requirement: FR-3 右下角常驻竖排 FAB 悬浮簇
- [ ] 三个详情页 SHALL 在视口右下角常驻竖排悬浮操作簇:主 FAB(金圆,套件 .fab 视觉语言)居底,次级操作钮(编辑/转账/更多等,surface+border 方圆钮)叠于其上;簇不折叠、不随页面滚动移动;页面底部留白 SHALL ≥ 242px,保证滚动末屏关键信息不被遮挡。

#### Scenario: 长页滚动簇固定
- GIVEN 债务详情还款计划长列表,用户滚动到底
- THEN 悬浮簇仍固定视口右下,最后一行关键信息(合计/末期)不被遮挡

#### Scenario: 常驻不折叠
- GIVEN 任意滚动位置
- THEN 簇内全部操作恒可见,无收起/呼出交互

### Requirement: FR-4 悬浮簇操作集按页配置
- [ ] 悬浮簇操作集 SHALL 为按页配置的有序列表:每页必有且仅有一个主 FAB(债务=立即记账、债权=收款、账户=记一笔),次级钮按页语义配置(账户=编辑/转账(还款·充值按类别)/更多;债务/债权=编辑/更多);原 AppBar actions 的操作(含更多菜单:删除/复制账户/关闭账户等)SHALL 全量迁移,功能零丢失;配置结构面向后续快捷按钮扩展。

#### Scenario: 账户详情操作全量迁移
- GIVEN 用户位于活跃账户详情(旧 AppBar 有 编辑/记一笔/转账/更多四组)
- THEN 悬浮簇提供 记一笔(主)+ 编辑/转账/更多(次级),「更多」菜单含 复制账户/关闭账户/删除 等原有项

#### Scenario: 归档账户降级
- GIVEN 用户位于已归档账户详情(旧 AppBar 仅剩更多菜单)
- THEN 悬浮簇降级为无主操作可用/仅「更多」可用(复制/重新激活/删除),与现状语义一致

### Requirement: FR-5 三详情页第二层导航退役
- [ ] 债务/债权/账户详情页自带 AppBar(面包屑标题条/BackButton/actions)SHALL 整条退役,页面内容(hero 区)上移;页面自身不再承载任何导航语义。

#### Scenario: 详情页无第二层导航条
- GIVEN 用户位于债务详情页
- THEN 顶栏(_TopBar)与 hero 之间无任何页面级导航条,回退唯一路径为顶栏面包屑 page 级

### Requirement: FR-6 hideTopBar 特例收敛
- [ ] AppShell 的 `_isReceivableDetail` 顶栏隐藏特例 SHALL 移除:债权详情页回归全局 _TopBar 承载(FR-1 全路径面包屑)。

#### Scenario: 债权详情显示全局顶栏
- GIVEN 用户位于债权详情 `/receivables/:id`
- THEN 全局 _TopBar 显示(含离线/同步徽章与搜索),面包屑为「财务 › 债权管理 › <counterparty>」

### Requirement: FR-7 脏表单离开确认(语义+通用守卫)
- [ ] 表单页处于脏态(用户已编辑未保存)时,任何导航离开(面包屑祖先点击/返回)SHALL 先弹确认提示;未编辑时直接离开。本票交付该守卫的通用机制并钉死语义;存量表单页接线归 F59。

#### Scenario: 脏态拦截
- GIVEN 用户在表单页修改过至少一个字段
- WHEN 点击顶栏面包屑祖先导航离开
- THEN 弹出确认提示(放弃/留下),确认后才离开

#### Scenario: 干净态直接离开
- GIVEN 用户进入表单页未做任何修改
- WHEN 点击面包屑祖先离开
- THEN 直接离开,无提示

## NFR

### Requirement: NFR-1 视觉令牌合规
- [ ] 悬浮簇与面包屑可点态 SHALL 全部使用既有语义令牌(主 FAB 金色 = --fab 对应 Flutter 令牌;零硬编码色值),符合 design-v2 双主题。

#### Scenario: 双主题渲染
- GIVEN 亮/暗主题分别启用
- THEN 悬浮簇与可点面包屑在两主题下均正确着色,无任一主题下的对比度缺失

### Requirement: NFR-2 组件归属选取次序
- [ ] 悬浮簇组件归属 SHALL 按 ADR-007 选取次序评估(design_kit 共享原语优先,产品特定逻辑留 app 层),决策记入 design.md ADR。

### Requirement: NFR-3 回归门
- [ ] flutter test 全绿 + flutter analyze 不超基线 + `make client-e2e` 通过;波及金图重录。

### Requirement: NFR-4 可达性
- [ ] 悬浮簇每钮 SHALL 有 tooltip;簇内按钮键盘可达(Tab 焦点 + Enter 触发)。

## Feasibility

- **technical 可行**:AppShell 顶栏改造点集中(`_BreadCrumb`/`_branchMetaOf`);标题注入有既有通道先例(ValueNotifier port/DataRefreshNotifier 同款);三页迁移为删除性改动(AppBar 退役)+操作搬迁;守卫机制有 WillPopScope/路由拦截先例。
- **economic 可行**:单 sprint 票,波及 ~6 文件(shell + 三页 + 组件 + 测试),无 schema/proto 改动。
- **operational 可行**:e2e 管道既有;金图重录有 F9/F15 惯例;唯一外部依赖=用户对三页范式走查(照 OD 已预演,风险低)。

## Out of scope

- 其余 detail 页(budget/goal/holding/security/transaction)与全部 form 页迁移 — owner: F59(sprint-1 次票) — excluded because: F58 先立机制+范式,F59 同质扫页降变异(用户分解拍板「两票串行」)。
- categories/订阅管理专属 topbar 收敛、「‹ 返回」链接退役 — owner: F59 — excluded because: 同上(特例页非范式所需)。
- 表单页脏态守卫的存量接线 — owner: F59 — excluded because: 机制在 F58 落地并测试钉死,接线是扫页工作(见 FR-7)。
- 列表页创建入口(顶栏创建钮)调整 — owner: none(维持现状) — excluded because: 本票只动详情页导航;列表页无第二层导航问题。
- 窄屏底栏(_BottomNav 8 项)改造 — owner: none(维持现状) — excluded because: 底栏是窄屏主导航,与详情页悬浮簇无冲突;无改造需求。
- 移动端系统返回手势适配 — owner: none(deferred) — excluded because: 桌面应用为主战场,go_router 栈语义既有未变。

## Grill record

- 主 FAB 每页必有 vs 债务页省略(记账入口已三处,第四处冗余) — challenged: 形态 B 视觉锚点在债务页缺失是否可接受,还是冗余但统一 — defended: 用户「都加上,方便后续扩展快捷按钮」;冗余知情接受,操作集为按页配置有序列表、面向扩展(FR-4)。
- 脏表单离开语义 — challenged: 误触面积变大(可点面包屑在保存钮必经路上方)丢长表单输入 vs 确认弹窗摩擦 — defended: 用户「如果编辑了内容,离开弹出提示」;仅脏态拦截、干净态直接离开(FR-7)。
- 窄屏形态 — challenged: 是否需要断点特判 — defended(事实自答,spec 审阅): 面包屑 compact 顶栏本就显示(仅藏搜索/设置),图标钮竖排窄屏友好;同构无特判。
