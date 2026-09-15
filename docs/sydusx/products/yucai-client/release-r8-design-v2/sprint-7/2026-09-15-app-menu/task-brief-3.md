# Task Brief T3 — 首次关闭一次性对话框

> F22 code-plan Task3。TDD;controller 不改你的产物;评审独立。独立于 T2(不碰 settings_page)。

## 环境

- worktree:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r8-f22`(分支 feature/r8-f22;勿切分支勿 commit)
- 客户端 `yucai/client/`;注释中文。与 T2 并行进行——**只新建文件,不改任何既有文件**;若需共享常量,自包含在本文件内。

## 上下文(先读)

- 视觉契约:docs/sydusx/products/yucai-client/prototype/v1/ui/first-close-dialog.html + components.md 的 dialog-first-close 规格(400 宽卡/圆角 16/标题 15·700/正文 13 muted/次=文字钮/主=btn-primary/右上 ×/Esc=取消)。
- 语义色 context.yucai(lib/core/theme/app_design.dart;缺 soft 变体时用令牌+Opacity 注释说明,禁裸 hex)。
- 消费方是 T4 的 TrayController(spec FR-3:返回值驱动 hide/exit/取消)。

## 交付

1. 新 `lib/settings/widgets/first_close_dialog.dart`:
   - `enum FirstCloseDialogResult { minimize, quit }`
   - `Future<FirstCloseDialogResult?> showFirstCloseDialog(BuildContext context)` — showDialog,barrierDismissible:**true**(barrier 点击/Esc = 取消);卡内右上 ×(IconButton 图标钮,=取消);标题「御财将最小化到系统托盘」;正文含「系统托盘」「到期提醒与自动记账不受影响」「点击托盘图标恢复窗口」语义(照原型文案);actions 右对齐:「退出程序」次按钮(muted 文字钮)→ pop(quit);「最小化到托盘」主按钮(accent 主语义,含图标)→ pop(minimize);pop(null)=取消(**不写任何设置标记**——标记写入是 T4 消费方职责,本组件无副作用)。
   - 卡宽 400/圆角 16;组件无业务依赖(纯展示+返回),双主题经 YucaiTheme 生效。
2. 新 `test/settings/widgets/first_close_dialog_test.dart`:
   - 三态:点主按钮→minimize;点次按钮→quit;barrier 点击(Esc)→null。
   - 文案断言:标题与「系统托盘」关键词存在。
   - 主题探针:暗色/亮色下渲染不抛(照仓内 theme-follow 探针范式,若过重可简化为默认主题渲染断言+注释)。

## 完成门

flutter analyze 新文件无新增 issue;新测试全绿;全量 flutter test 无回归(基线 1606 绿,注意 T2 可能并行加了测试——全量以「无回归于你开始时的工作树状态」为准,若有并行改动的测试失败先重跑甄别再报告)。报告:文件清单/测试数/偏差。
