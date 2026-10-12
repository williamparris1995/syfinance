# F58 code-ledger

> SDD 执行档案:任务完成记录 / 评审轮次 / 裁决。控制器维护。

## 任务记录

| 任务 | 状态 | 实现 | 评审 | 修复轮 |
|---|---|---|---|---|
| T1 design_kit(DesignTokens 增补+FloatingActionDock) | ✅ | 15 测绿/analyze 0 | PASS-with-fixlist(1 MINOR:禁用措辞) | 1 轮:措辞「半透明降权」+测试注释+禁用焦点断言(15 绿) |
| T2 core(ShellDetailTitle+FormLeaveGate/Guard) | ✅ | 13 测绿/463 基线 | PASS-with-fixlist(2 MINOR:mounted 复核/回落测试) | 1 轮:both 修(5 绿) |
| T3 app_shell(面包屑三段+消费+特例收敛+主题注入) | ✅ | 全量 2662 绿/8 新测 | PASS-with-fixlist(1 MINOR:负向分支+detail→detail 钉测) | 1 轮:补 2 测+变异校验(10 绿);2 轮(M2):scrubber 条件精确化 `_lastDetailKey`(11 绿,变异校验过) |
| T4 债务+债权详情迁移 | ✅ | 全量 2691 绿/62 页测 | PASS-with-fixlist(**I-1** 跨分支回退标题永停「…」+2 MINOR) | 1 轮:DetailTitleSync 组件(TickerMode 活跃守卫)+两页接线+跨分支钉测(修前必红实证) |
| T5 账户详情迁移 | ✅ | 85→87 页测/全量含 | PASS-with-fixlist(3 MINOR:文档打架/标题回填/转账测试) | 1 轮:文档订正+转账 tap 测(86 绿);2 轮:DetailTitleSync 换接+跨分支等价用例(87 绿) |
| T6 收尾门(金图+全量+e2e) | ✅ | 全量 2699 绿/analyze 463/e2e 15 套件 | —(门即验证) | 金图重录 1 张(audit_menu_open,预期视觉变更);e2e 断言零改动;A12 三 FINDING 为存量软发现非本票引入 |

## 关键裁决(控制器)

- **T2-M2/T3-M2/T4-I-1 标题回填**:同一机制缺口三轮演进——T5 评审首报(push 往返「…」)→ T3 scrubber 改 `_lastDetailKey` 条件清零(同 key 往返恢复)→ T4 评审 I-1 揭穿跨分支 detail→detail→回退(builder 不重跑+无加载事件)→ 终解 `DetailTitleSync`(post-frame 幂等 set + **TickerMode 活跃守卫**,实证 go_router 14.6.2 分支回退靠 Offstage TickerMode 翻转作重建信号,非 builder 重跑)。三页同构接线,F59 扫页直接复用。
- **归档/降级语义**:primary 在场禁用(onTap null 半透明降权)而非隐藏——spec FR-4「每页必有且仅有一个主 FAB」上位;task-brief/design.md LLD 已订正一致(原「隐藏」措辞打架)。归档金圆禁用态视觉留**用户走查项**。
- **T4 卡贷/结清 primary 禁用**:与 F48 行内停用语义一致(卡贷手工记账停用防双重支付);结清=无下期可记。
- **AnchoredMenu 包整簇锚定**(T4/T5 同款):design_kit DockAction 契约无 trigger builder 缝;自适应翻转使菜单恰落簇顶(=更多钮)上方,几何经测试钉死。F59 若需单钮锚定再议组件缝。
- **go_router 14.6.2 两契约入测**:imperative push 不改 currentConfiguration;分支冻结树缓存(重建信号=TickerMode)。已作回归锚写进测试。

## 走查项(交验收)

- 归档账户页右下金圆禁用态视觉(半透明降权)是否可接受——不接受则改隐藏(单点改 `_dock`)。
