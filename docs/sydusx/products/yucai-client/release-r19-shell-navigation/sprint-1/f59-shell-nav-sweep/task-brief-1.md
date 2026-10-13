# Task Brief T1 — design_kit:FloatingActionDock C' 升级(增量 API)

## 位置与环境
- worktree(只在此):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f59`
- 包:`<worktree>/yucai/packages/design_kit`;测试 `flutter test`(包内)
- 规格:`<feature>/design.md` ADR-1 + LLD 契约 + `prototype/v17/components.md`(C' 三段式)。`<feature>` = docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f59-shell-nav-sweep

## 任务
升级 `lib/src/floating_action_dock.dart` 为 **C' 三段式**(design LLD 契约):
1. 保留 `primary`/`secondary` 参数名(**向后兼容**:F58 三页现调用 primary+secondary 必须全程可编译,视觉随升级变化可接受)。
2. 新增 `muted: List<DockAction>`(缺省空):**降饱和淡显**组(Opacity 令牌级常量,如 0.45 同禁用语言但要可区分——淡显=视觉淡但可点;禁用=onTap null 不可点;两者叠加时以禁用为准);**hover 与键盘焦点恢复满透明度**(MouseRegion/Focus 联动)。
3. **内置分隔线**:muted 非空时在 muted 组与 secondary/primary 之间渲染(1px、宽 ~20、居中、tokens.border);muted 空则无。
4. 布局:`[...muted.reversed, divider?, ...secondary.reversed, primary]`,间距 10 恒定;**secondary/muted 钮改全圆**(borderRadius 50%,v16 方圆 12 废除)。
5. tooltip/键盘可达/禁用语义(既有)保持;NFR-2:淡显钮可聚焦,焦点态视觉不淡。
6. 注释中文照密度;零御财常量。

## TDD(硬性)
先红后绿,更新/新增 `test/floating_action_dock_test.dart`:
- 三段渲染(muted+secondary+primary 次序:muted 置顶 primary 居底)
- 分隔线条件渲染(muted 空→无;非空→有一条 1px)
- 淡显:Opacity 低于正常钮;hover(mouse enter)恢复;焦点(FocusNode)恢复;禁用叠加(onTap null 的 muted 钮不可点)
- secondary/muted 全圆(几何断言)
- 既有用例迁移到新 API 语义(secondary 全圆后旧断言更新)
完成后全包 `flutter test` + `flutter analyze`(基线 0)。

## 完成证据
测试输出(0 failures)+ analyze + 改动清单 + 偏离说明。
