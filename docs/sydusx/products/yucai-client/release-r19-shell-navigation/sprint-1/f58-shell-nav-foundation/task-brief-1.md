# Task Brief T1 — design_kit:DesignTokens 增补 + FloatingActionDock 原语

## 位置与环境
- worktree(所有工作只在此):`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r19-f58`
- 包:`<worktree>/yucai/packages/design_kit`(Flutter 包,path 依赖被 client 消费)
- 测试:`cd <worktree>/yucai/packages/design_kit && flutter test`
- 规格/设计(先读):`<worktree>/docs/sydusx/products/yucai-client/release-r19-shell-navigation/sprint-1/f58-shell-nav-foundation/{spec,design}.md`
- 原型基准:`<worktree>/docs/sydusx/products/yucai-client/prototype/v16/components.md`(FloatingActionDock 形态 B)

## 任务
1. `lib/src/design_tokens.dart`:DesignTokens(ThemeExtension)增两字段——`accentGradient: List<Color>` 与 `actionShadow: List<BoxShadow>`。**向后兼容缺省**:构造参数可空/带 const 缺省(空列表);`copyWith`/`lerp` 同步(lerp 逐项插值,长度不齐取短)。不破坏既有字段与构造点(缺省调用不强制传新字段——用可选参数)。
2. 新 `lib/src/floating_action_dock.dart`,契约(design.md LLD):
   - `class DockAction { final IconData icon; final String tooltip; final VoidCallback? onTap; }`(onTap null = 禁用态,视觉降饱和)
   - `class FloatingActionDock extends StatelessWidget { final DockAction primary; final List<DockAction> secondary; }`
   - primary:52px 圆,decoration = `LinearGradient(colors: tokens.accentGradient)`;**accentGradient 为空时回落 `tokens.accent` 纯色**;阴影 = `tokens.actionShadow`(空则无阴影)。前景 icon 色用适配色(如深色 `#1A1408` 语义 → 经参数或固定深色常量?**禁硬编码御财品牌值**——icon 前景色加可选参数 `primaryForeground`,缺省白)。
   - secondary:44px 圆角方(半径 ~12),底 `tokens.surface`,描边 `tokens.border`,icon `tokens.muted`。
   - 布局:`Column(mainAxisSize: min)`,secondary **逆序**叠于 primary 之上(primary 最下);间距 10;整体不可折叠。
   - 每钮 tooltip;键盘可达(InkWell/IconButton,焦点+Enter)。
3. `lib/design_kit.dart` 导出两个新类型。
4. **约束**:包内零御财前缀/零御财常量(ADR-007);颜色一律经 `DesignTokens.of(context)`/Theme.extension 缝;组件不 import app。
5. 注释:中文,照包内既有密度/风格(说明约束,不叙述显然)。

## TDD(硬性)
先写红测试再实现:`test/floating_action_dock_test.dart` 至少钉:
- 渲染 primary + N 个 secondary(数量/顺序:secondary 逆序在上)
- onTap=null → 禁用(不可点/降饱和视觉存在)
- accentGradient 空 → 回落 accent 纯色(断言 decoration 非 LinearGradient 或 colors 单源)
- tooltip 存在
每步:改完即跑 `flutter test`(单文件),绿后再全包。

## 完成证据(报告必须含)
- `flutter test` 全包输出(0 failures)
- `flutter analyze`(不新增 error/info,基线为准)
- 改动文件清单
