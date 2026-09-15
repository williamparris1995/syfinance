# Feature — F23 字符标「御」品牌图标全套(R8 sprint-7)

> 2026-09-15 brainstorm 拍板(方向:字符标「御」,三选一)。

## Description

现状:windows/runner/resources/app_icon.ico 为 Flutter 模板默认 10 档 ICO(任务栏/开始菜单/桌面/文件管理器均显示 Flutter 默认图标);assets/tray_icon.ico 为托盘专用;无 flutter_launcher_icons 配置——design-v2 品牌视觉(墨鎏金暗/晨白亮、鎏金渐变)从未落地到系统层。

设计方向(字符标):墨底 #0B0E13 圆角方块 + 鎏金渐变(#E8C07A→#C9964A)「御」单字,私行/印章气质,与 app 内部视觉一致;大尺寸带金渐变描边细节;**16px 托盘版用加粗单字简化形**(「16px 不清晰=设计失败」基线,Microsoft 官方规范;app 图标全形直接缩到 16px 会糊)。

管线:SVG 1024 源(入库为 design 资产)→ PNG 阶梯 → 多尺寸 ICO(16/24/32/48/64/256)手工合成(ImageMagick 或等价工具)替换 windows/runner/resources/app_icon.ico;托盘 assets/tray_icon.ico 替换为单独 16/24 简化形。**不用 flutter_launcher_icons**(Windows 端只生成单尺寸 ICO,fluttercommunity/flutter_launcher_icons#573)。托盘图标渲染档:16px(100% DPI)/24px(150%)。

## Stories

- [x] S1: 源设计(spec 排除项改道:弃手绘 SVG 路径,字体栅格+手绘印章基元;取色 design-v2 令牌;三轮视觉 QC 定稿)
- [x] S2: ICO 合成管线(tool/gen_app_icon.py,PIL 逐档原生帧合成,可重跑)
- [x] S3: 替换落地(runner 六档 + tray 16/24;Runner.rc 核对无异常)
- [x] S4: 视觉验收(CDN 视觉三轮 QC 达可发布标准;真机任务栏/开始菜单/托盘走查待用户——Windows 图标缓存需 ie4uinit -show 或新文件名刷新)

## Keywords

`图标` `icon` `app-icon` `ico` `字符标` `御` `品牌` `brand` `托盘图标` `tray-icon`
