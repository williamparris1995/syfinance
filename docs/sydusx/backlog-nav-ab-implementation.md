# Task Brief — 导航增强 A+B 实施(⑨,用户拍板组合;排在视觉对齐批次之后)

**工作目录**:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance`(分支 main),代码 `yucai/client/`。**前置**:视觉对齐批次提交后开工(git log 确认)。原型事实源:Open Design 项目 `yucai-fin-report-r16-9239` 的 `nav-sidebar.html` 与 `nav-palette.html`(OD run 6cdbb8e2 产出,用户已过目拍板 A+B;必要时拷贝至 docs/sydusx/products/yucai-client/prototype/v10/ 归档+CURRENT 更新)。

## A · 侧栏增强(app_shell.dart)

1. 分组折叠:概览/资产/收支/工具四组组头(折叠箭头+组内项数徽标),点击折叠/展开(展开态记忆持久化,照 ThemeSettings 家法存 secure storage 或既有 settings 通道,选家法最近者);折叠动画照原型形态。
2. 当前项高亮强化:左侧 accent 指示条(3px 竖条)+活动组高亮(原型形态)。
3. 「常用」置顶区:仪表盘/交易记录/报表分析三钉(硬编码 v1,拖拽自定义=backlog;注释钉)。
4. 窄屏底栏不动;侧栏宽度不变。

## B · 命令面板 Ctrl+K(全局)

1. 全局快捷键 Ctrl+K 唤起(Shortcuts/Actions 挂 app 级,或 window_manager 键盘钩子——选 Flutter 内建 Shortcuts 优先,注释钉);Esc 关闭。
2. 面板:居中 560px+遮罩(照原型样式,design-v2 令牌零裸色);搜索框 autofocus;结果分组「页面」(静态路由清单:仪表盘/报表分析/财务报告/交易记录/预算管理/投资组合/账户管理/订阅中心/设置…)与「操作」(记一笔[跳 /transactions/new 或既有 FAB 路由]/生成财务报告[/reports/full]/导出报告/AI 解读——后两者仅在对应页面上下文有效,全局态置灰或跳报告页,注释钉取舍)。
3. ↑↓ 键盘高亮+Enter 执行;输入实时过滤(contains,页面名+拼音可选=backlog);空结果显示「无匹配」。
4. 数据 v1 硬编码清单(页面=router 静态表,操作=上述),不留插件面。

## 测试(TDD)

- A:折叠/展开/记忆/指示条/常用区 widget 测;
- B:快捷键唤起/Esc/↑↓/Enter/过滤/空态 widget 测;操作项路由跳转断言;
- 既有 shell/路由测试零破(新增 shell 分支若有);全量绿+analyze 零新增+make client-e2e(shell 面,跑前 taskkill yucai_client)。

commit(main):`feat(nav): 侧栏分组折叠+常用置顶(A)与全局命令面板 Ctrl+K(B)——⑨ 导航增强`。回报:取舍(快捷键机制/记忆通道/操作项语境)/测试数/commit hash。
