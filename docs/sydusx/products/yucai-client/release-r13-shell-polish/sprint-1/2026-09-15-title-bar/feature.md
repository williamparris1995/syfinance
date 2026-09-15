# Feature — F29 自定义标题栏(R13 sprint-1)

> 2026-09-15 checkpoint 后立项;方案 grill 待用户拍板(无边框实现/标题栏内容)。

## Description

现状:窗口为 Flutter 默认 chrome(系统标题栏+系统按钮),与墨鎏金品牌割裂。目标:自定义标题栏——品牌语言(logo 徽标「御」+窗口控制钮三件),关闭钮走 windowManager.close() 复用 F22 onWindowClose 决策树(设置化关闭行为+首关对话框),双主题随 app。

## Stories

- [ ] S1: 方案 grill(无边框路线/内容形态,用户拍板)
- [ ] S2: 标题栏组件(logo/三钮/拖拽/双击最大化;双主题语义色)
- [ ] S3: 接线(setTitleBarStyle/框架改造+关闭→F22 决策树回归)
- [ ] S4: 测试(组件渲染/按钮 action mock/双主题探针+全量门)

## Keywords

`标题栏` `title-bar` `窗口` `window` `chrome` `无边框` `frameless` `窗口按钮` `窗口控制`
