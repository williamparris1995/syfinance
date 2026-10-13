# Design: F58 壳层导航地基+范式迁移

prototype: v16

> UI-scoped(Path B — OD 自生成,本票为已拍板对比页拷回落档);usage grounding:primary persona = Andy(单用户个人理财桌面操作者,熟练键鼠),key-path scenarios = ①债务详情查看 → 面包屑 page 级回列表 ②账户详情 → 悬浮簇「记一笔」快捷记账 ③长表单编辑态 → 导航离开弹确认。原型 = `prototype/v16/ui/crumb-nav-variants.html`(用户 2026-10-12 拍板形态 B;区块二统一方案 / 区块三形态 B 为实现基准)。

## Context

现状两层导航:AppShell 顶栏 `_BreadCrumb` 纯文本不可点;债务/债权/账户详情页自带 AppBar(面包屑/BackButton/actions)。spec(FR-1..FR-7)已 confirmed。架构继承 flutter_bloc + getIt injectable + go_router StatefulShellRoute;共享原语包 `yucai/packages/design_kit`(DesignTokens ThemeExtension 倒置缝,ADR-007 选取次序)。零 proto/schema 改动。

## Goals / Non-Goals

**Goals**:面包屑可点化(FR-1);标题注入通道(FR-2);悬浮簇组件(FR-3/4);三页迁移+特例收敛(FR-5/6);脏态守卫机制(FR-7);令牌/可达/回归(NFR-1..4)。
**Non-Goals**:F59 扫页范围(其余 detail/form/categories/订阅/返回链接);列表页入口;窄屏底栏;移动系统返回手势。

## Decisions (ADRs)

- **ADR-1 标题注入通道 = `ShellDetailTitle` ValueNotifier port**(getIt lazySingleton,照 `DataRefreshNotifier` 先例)。detail 页加载完成 `set(counterparty/账户名)`;dispose `clear()`;shell 顶栏 `ValueListenableBuilder` 消费,且 **location 变化即清零**(双保险:页面 dispose + shell location-diff,FR-2 残留验收由此钉死)。*Alternatives*:route extra(鸡生蛋:标题待页面数据;刷新/deep link 丢失;改名需重 push)/ shell 直接监听各 detail Bloc(违反跨模块 port 约束,每加页 shell 皆改)。*Grill*:挑战「notifier 泄漏残留」→ 双保险清理,用户拍板方案 A。
- **ADR-2 悬浮簇组件 = design_kit 新原语 `FloatingActionDock`**(垂直动作堆叠;`DesignTokens` 倒置缝取色,**零御财常量进包**,禁 Yucai 前缀——ADR-007)。组件契约见 LLD;app 层只给操作集配置。*Alternatives*:app 层私有组件(F59 同样要用 → 重复违反复用第一)/ 各页自摆(散)。*Grill*:挑战「主 FAB 金渐变是御财品牌,进共享包越界」→ 结构进包、颜色经缝注入;**DesignTokens 增补两字段 `accentGradient`(`List<Color>`)与 `actionShadow`(`List<BoxShadow>`)**,由 app 双主题构造器注入(本仓唯一构造点顺改,向后兼容;套件 `--fab-bg`/`--fab-shadow` 对应)。
- **ADR-3 脏态守卫 = `FormLeaveGate` port + `PopScope` 兜底**。`FormLeaveGate`(getIt lazySingleton):`register(LeaveVeto)/unregister`,`LeaveVeto = Future<bool> Function()`;面包屑 page 级 onTap 先 `await gate.mayLeave()` 再 `context.go`(go 非 pop,PopScope 拦不到,必须走统一问询);表单页侧 `FormLeaveGuard` widget = PopScope(拦系统返回/pop)+ 注册同一 veto(脏态弹「放弃/留下」确认)。F58 交付机制+测试 harness 表单页钉死两场景;存量接线 F59。*Alternatives*:GoRouter redirect(不适合 leave 语义且无 dirty 上下文)/ 只拦面包屑 onTap(漏 pop 路径)。
- **ADR-4 面包屑三段渲染**:`_BreadCrumb` 升级——section 段纯文本(muted);page 段 `InkWell`+link 色+hover 下划线,onTap = branch 元数据 rootPath 的 `context.go`;current 段(来自 ShellDetailTitle,空则不显第三段)加粗不可点。compact 顶栏同构(面包屑本就显示)。

## HLD

| 单元 | 层 | 职责 |
|---|---|---|
| `ShellDetailTitle` | client `core/` | 标题 port:set/clear/监听;shell 消费 + location-diff 清零 |
| `FormLeaveGate` + `FormLeaveGuard` | client `core/` | 离开问询 port + 表单页守卫 widget(PopScope+注册 veto+确认 dialog) |
| `FloatingActionDock` | `packages/design_kit` | 竖排悬浮簇原语:primary(52 金圆)+ secondaries(44 方圆);DesignTokens 缝 |
| `_BreadCrumb` 改造 + `_TopBar` | client `app/widgets/app_shell.dart` | 三段渲染 + page 级 go(经 FormLeaveGate)+ 标题消费 |
| `DesignTokens` 增补 | design_kit | `accentGradient`/`actionShadow` 两字段,app 主题构造器注入 |
| 三页迁移 | client `debt/`×2 + `account/` | AppBar 退役;`FloatingActionDock` 挂载(Stack Positioned right/bottom 28);滚动容器 bottom padding ≥242;操作映射见 LLD;`_isReceivableDetail` 特例移除 |

依赖方向:`app_shell` → `core`(ports)→ 无反向;`design_kit` 不 import app。三页 → `design_kit`(pub path 依赖既有)。

## LLD

**FloatingActionDock 契约(design_kit)**

```dart
class DockAction {
  final IconData icon; final String tooltip;
  final VoidCallback? onTap;   // null = 禁用(视觉降饱和)
}
class FloatingActionDock extends StatelessWidget {
  final DockAction primary;              // 每页必有(FR-4)
  final List<DockAction> secondary;      // 有序,自下而上叠于 primary 之上
  // 视觉:primary 52px 圆,decor = LinearGradient(tokens.accentGradient) +
  //       BoxShadow(tokens.actionShadow);secondary 44px 圆角方,surface 底 + border 描边;
  // 布局:Column(mainAxisSize.min, vertical),secondary 逆序在上;
  // 常驻不折叠;自身不含 Positioned —— 由宿主 Scaffold body Stack Positioned(right:28,bottom:28) 摆放
}
```

**三页操作映射(操作集有序列表,FR-4;归档降级=primary 在场禁用(onTap null 半透明降权,FR-4「每页必有主 FAB」不缺席)+ 非「更多」次级项隐藏,照现状 `!archived` 隐藏语义)**

| 页 | primary | secondary |
|---|---|---|
| 债务详情 | 立即记账(打开下期 RecordPayment,同侧栏「登记一笔还款」语义) | 编辑 · 更多(删除) |
| 债权详情 | 收款(下期确认收款 dialog) | 编辑 · 更多(删除) |
| 账户详情(活跃) | 记一笔(`_recordTxn`) | 编辑 · 转账(信用卡=还款/储值=充值,`_transfer`) · 更多(复制账户/关闭账户/删除) |
| 账户详情(归档) | 记一笔(在场禁用:onTap null 半透明降权) | 更多(复制账户/重新激活账户/删除) |

**面包屑 onTap 流程**:`await formLeaveGate.mayLeave()`(注册的 veto 逐个问询,false=中止)→ `context.go(rootPath)`。detail 页加载态:current 段占位「…」(port 值 null + location 为 detail 形态时)。

**页面结构(三页)**:`Scaffold(body: Stack[ 内容(ListView/CustomScrollView,bottom padding ≥242), Positioned(right:28, bottom:28, child: FloatingActionDock(...)) ])`;原 AppBar 的 `preferredSize`/actions 全删;hero 直升页顶(顶栏毛玻璃下第一元素)。

**测试钉点**:①标题注入/清理(harness detail 页 set→显示,离开→清)②面包屑 go 回列表(三页 e2e 已有成员改断言)③dock 操作全量可达(账户四组/归档降级)④FormLeaveGuard 脏拦/净放(widget 测)⑤金图重录(shell 顶栏+三页)。

## Risks / Trade-offs

- [标题残留污染] → 双保险清理(dispose+location-diff)+ 场景①测试钉死
- [dock 遮挡动态尾部内容] → 底部留白 ≥242 + e2e 末屏断言
- [shell 顶栏改动波及全部金图] → 重录范围 = shell/三页相关 golden,照 F9/F15 重录惯例;full_audit 已有陈旧金图重生成先例
- [design_kit 字段增补破构造点] → 本仓唯一 app 构造点顺改 + 包测试同步;若第三方未来接入,字段带默认(渐变缺省回落 accent 纯色)
- [go 清栈语义跨入口] → inbox/托盘跨入口进 detail 后回列表为期望行为(spec FR-1 场景)

## Migration Plan

纯 UI 改动,零数据迁移;回滚 = revert 提交。

## Open Questions

无(spec/grill 已闭合;F59 范围细节留其 spec)。
