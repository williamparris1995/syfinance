# Feature — F23 字符标「御」品牌图标全套(R8 sprint-7)

> 2026-09-15 brainstorm 拍板(方向:字符标「御」,三选一)。

## Description

现状:windows/runner/resources/app_icon.ico 为 Flutter 模板默认 10 档 ICO(任务栏/开始菜单/桌面/文件管理器均显示 Flutter 默认图标);assets/tray_icon.ico 为托盘专用;无 flutter_launcher_icons 配置——design-v2 品牌视觉(墨鎏金暗/晨白亮、鎏金渐变)从未落地到系统层。

设计方向(字符标):墨底 #0B0E13 圆角方块 + 鎏金渐变(#E8C07A→#C9964A)「御」单字,私行/印章气质,与 app 内部视觉一致;大尺寸带金渐变描边细节;**16px 托盘版用加粗单字简化形**(「16px 不清晰=设计失败」基线,Microsoft 官方规范;app 图标全形直接缩到 16px 会糊)。

管线:SVG 1024 源(入库为 design 资产)→ PNG 阶梯 → 多尺寸 ICO(16/24/32/48/64/256)手工合成(ImageMagick 或等价工具)替换 windows/runner/resources/app_icon.ico;托盘 assets/tray_icon.ico 替换为单独 16/24 简化形。**不用 flutter_launcher_icons**(Windows 端只生成单尺寸 ICO,fluttercommunity/flutter_launcher_icons#573)。托盘图标渲染档:16px(100% DPI)/24px(150%)。

## Stories

- [ ] S1: SVG 源设计(1024 主形 + 16px 简化形变体;取色 design-v2 令牌;暗底双主题下均成立)
- [ ] S2: ICO 合成管线(PNG 阶梯导出 + 多尺寸 ICO 合成;步骤脚本化或文档化,可重跑)
- [ ] S3: 替换落地(runner app_icon.ico + assets/tray_icon.ico;Runner.rc 版本元数据顺带核对)
- [ ] S4: 视觉验收(16/32/256 各档走查:任务栏/开始菜单/桌面/托盘/文件管理器;亮暗壁纸各一遍)

## Keywords

`图标` `icon` `app-icon` `ico` `字符标` `御` `品牌` `brand` `托盘图标` `tray-icon`
