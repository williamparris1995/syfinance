# Design — F23 字符标「御」品牌图标全套

**prototype: none**(资产替换型 feature,无新 UI 屏;视觉决策已由变体预览对比图经用户拍板——变体 A,预览源 `.scratch/gen_icon_variants.py` 产物)

## Context

[spec.md](spec.md)。现状:runner `app_icon.ico` 为 Flutter 模板默认 10 档;`assets/tray_icon.ico` 托盘专用;无 flutter_launcher_icons 配置。

## Goals / NonGoals

- **Goals**:变体 A 视觉规格化落地 exe/托盘全套;管线脚本入库可重跑;ICO 结构测试守护。
- **NonGoals**:跨平台图标;手绘 SVG 路径;发布元数据变更(F24 线)。

## Decisions(ADR)

### ADR-1 字形 = 微软雅黑 Bold 字体栅格化(非手绘路径)
- **理由**:脚本可重跑、零手工资产;雅黑 Bold「御」笔形在 16px 仍可辨(变体预览+QC 已验证);字体 Windows 内置(`msyhbd.ttc`),管线依赖文档化。
- **备选**:手绘 SVG 路径(完全可控、跨机一致,但单字路径成本不成比例);裁剪为「彳/卸」部首简化形(16px 更锐但品牌辨识降)。
- **Grill**:挑战=「换机器没这字体怎么办」→ 脚本启动时校验字体文件存在,缺失即报错退出(不静默换字体);挑战=「版权」→ 雅黑随 Windows 授权分发,栅格化产物为图片非字体嵌入,常规桌面 app 惯例。

### ADR-2 管线 = 单脚本 PIL(预览脚本升格)
- **理由**:PIL 12.2 已验证(圆角/渐变/字形蒙版/ICO 多尺寸保存);ImageMagick 本环境未验证;无新依赖(Python 仓外工具)。
- **备选**:ImageMagick 命令行(等价但引入新工具依赖)。

### ADR-3 托盘独立简化形(非全形缩放)
- **理由**:app 全形(圆角+渐变字 64%)在 16px 糊;简化形去细节、字面 78%(spec FR-3,Microsoft「16px 基线」)。

### ADR-4 源参数集中 + 产物直接覆盖目标文件
- 生成脚本头部集中常量(INK/GOLD_HI/GOLD_LO/圆角率/字面占比/档位表);输出直接写 `windows/runner/resources/app_icon.ico` 与 `assets/tray_icon.ico`(幂等,重跑即再生成)。

## HLD

```
yucai/client/tool/gen_app_icon.py   # 管线脚本(升格自 .scratch 预览,参数化+校验)
  ├─ make_icon(size, simple)         # 变体 A 渲染(墨底/金渐变/字形蒙版)
  ├─ app_icon: 16/24/32/48/64/256 → windows/runner/resources/app_icon.ico
  └─ tray_icon: 16(简化)/24(简化) → assets/tray_icon.ico
yucai/client/test/tool/app_icon_struct_test.dart  # ICO 结构守护(档位齐全)
```

## LLD

- 渐变:`Image.linear_gradient('L')` 旋转 45° 作索引在 #C9964A→#E8C07A 插值(预览同款)。
- 字形:`ImageDraw.text(anchor='mm')` 居中;frac=0.64(全形)/0.78(简化);≤20px 自动简化。
- ICO:逐档 RGBA 渲染 → `img.save(path, format='ICO', sizes=[...])`(PIL 原生多尺寸)。
- 结构测试:读 ICO 头(entry count=6/2 + 尺寸集合断言),纯 Dart 解析(ICO 目录 6 字节头 + 16 字节/entry)。

## Risks

| 风险 | 缓解 |
|---|---|
| 字体缺失机器跑管线 | 脚本启动校验,报错退出不静默降级 |
| Windows 图标缓存掩盖替换效果 | 验收清单注明 `ie4uinit.exe -show` 或改文件名验证法 |
| 托盘代码 start() 落盘旧 tray_icon 缓存 | 代码按存在性跳过落盘——验收时删 AppData 下 tray_icon.ico 再启 |

## Migration

默认行为零变化(纯资产);任务栏/开始菜单图标随 ICO 替换即时生效(缓存刷新后)。

## Open Questions

- 手绘字形路径(品牌完全可控)留 backlog;若未来跨平台/macOS 需要再评估。
