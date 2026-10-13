# Task Brief T2 — F58 三页回改(C' 重配 + 菜单退役)

## 位置与环境
- worktree(只在此):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f59`;client `<worktree>/yucai/client`
- 前置:T1 已落(FloatingActionDock C' API:muted 组/分隔线/全圆——以实际落码为准)。
- 规格:`<feature>/spec.md` FR-2/FR-3 + design.md LLD 页面配置速查。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f59-shell-nav-sweep

## 任务(三页:debt_detail/receivable_detail/account_detail)
1. **C' 重配**(design LLD 速查):
   - 债务:primary=立即记账;secondary=[编辑];muted=[删除]
   - 债权:primary=收款;secondary=[编辑];muted=[删除]
   - 账户(活跃):primary=记一笔;secondary=[编辑/转账(还款·充值)];muted=[复制账户/关闭账户/删除]
   - 账户(归档):primary 禁用在场;muted=[复制账户/重新激活账户/删除];secondary 空
2. **AnchoredMenu 从 dock 挂载移除**(菜单模型退役;删除等直达既有确认弹窗)。
3. **账户恒渲染改齐**(ADR-4):dock 渲染移出 `AccountDetailLoaded` 门,loading/error 全禁用(照债务页形态);归档/卡贷/结清禁用态保持。
4. 底部留白按满配高度调整(账户 ~370;债务/债权按钮数算)。
5. 测试(先红后绿):三页菜单零残留(AnchoredMenu 引用清);muted 组渲染与直达行为(删除→确认弹窗);账户 loading/error 恒渲染全禁用;归档降级映射;既有断言更新。

## 约束
零功能丢失;不碰 form 页/工具页/其余 detail(并行任务);日志英文;注释中文。

## 完成证据
测试输出(0 failures)+ analyze 无新增 + 改动清单 + 偏离说明。
