# -*- coding: utf-8 -*-
"""御财 App 图标管线(F23,spec FR-1~4):字符标「御」变体 A。

变体 A(2026-09-15 用户三选一拍板):墨底圆角方块 + 鎏金渐变「御」单字。
令牌取 design-v2(design-v2.md §2):墨底 #0B0E13 / 鎏金 #E8C07A→#C9964A。

小档口径(2026-09-16 用户拍板,取代 F23 ADR-3 印章简化形):托盘图标必须
与 app 内品牌徽标同一(app_shell.dart:金渐变圆角方块 + 墨色「御」),
故 ≤24px 档 = 徽标形(金渐变方块 + 墨御);≥32px 档维持变体 A 不变。
F23 时「16px 字形不可辨」的取舍让位于用户明确的一致性要求。

产物(幂等,重跑即再生成):
  windows/runner/resources/app_icon.ico  六档 16/24/32/48/64/256(≤24px 徽标形)
  assets/tray_icon.ico                  16/24 徽标形专用档(托盘渲染档)

依赖:Python3 + Pillow;字形=微软雅黑 Bold(Windows 内置 msyhbd.ttc;
缺失即报错退出,绝不静默换字体——ADR-1)。禁用 flutter_launcher_icons
(Windows 端单尺寸缺陷 fluttercommunity/flutter_launcher_icons#573)。

用法:cd yucai/client && python tool/gen_app_icon.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

# ---- 源参数集中(FR-4;改动只动这里) ----
INK = (11, 14, 19)          # #0B0E13 墨底
GOLD_HI = (232, 192, 122)   # #E8C07A 鎏金亮端(= 令牌 accent)
GOLD_LO = (201, 150, 74)    # #C9964A 鎏金暗端(= 令牌 accentDeep)
ON_ACCENT = (26, 20, 8)     # #1A1408 徽标字色(= 令牌 onAccent)
RADIUS_RATIO = 0.19         # 变体 A 圆角率(Fluent 系圆角方块)
GLYPH_FRACTION = 0.64       # 变体 A 全形字面占比
BADGE_RADIUS_RATIO = 11 / 34  # 徽标形圆角率 = app_shell 品牌徽标 34px/圆角 11
BADGE_GLYPH_FRACTION = 0.62   # 徽标字面占比(徽标本体 17/34≈0.5;小档放大保可辨)
FONT_PATH = r"C:\Windows\Fonts\msyhbd.ttc"

APP_ICON_SIZES = [256, 64, 48, 32, 24, 16]  # exe 六档(FR-2)
TRAY_ICON_SIZES = [24, 16]                  # 托盘徽标形档(FR-3)
SIMPLE_MAX = 24  # ≤此档位用徽标形(2026-09-16 一致性拍板)


def _gold_gradient(size: int) -> Image.Image:
    """135° 对角鎏金渐变(垂直渐变旋转 45°,灰度作索引双色插值)。"""
    g = Image.linear_gradient("L").resize((size, size)).rotate(45)
    return Image.merge("RGBA", (
        g.point(lambda v: GOLD_LO[0] + (GOLD_HI[0] - GOLD_LO[0]) * v // 255),
        g.point(lambda v: GOLD_LO[1] + (GOLD_HI[1] - GOLD_LO[1]) * v // 255),
        g.point(lambda v: GOLD_LO[2] + (GOLD_HI[2] - GOLD_LO[2]) * v // 255),
        Image.new("L", (size, size), 255),
    ))


def _rounded_mask(size: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=max(2, int(size * RADIUS_RATIO)), fill=255)
    return m


def _badge_gradient(size: int) -> Image.Image:
    """亮金 TL → 暗金 BR(= app 内品牌徽标 LinearGradient [accent, accentDeep]
    topLeft→bottomRight 同向;注意与变体 A 字身渐变方向相反)。走逐像素对角
    索引而非 linear_gradient.rotate(45) —— 旋转的位图外填充会污染角落
    (v=0 映射亮端 → TL 角折痕伪影,首轮 QC 撞到)。"""
    idx = Image.new("L", (size, size))
    idx.putdata([
        (x + y) * 255 // max(1, 2 * size - 2)
        for y in range(size) for x in range(size)
    ])
    return Image.merge("RGBA", (
        idx.point(lambda v: GOLD_HI[0] + (GOLD_LO[0] - GOLD_HI[0]) * v // 255),
        idx.point(lambda v: GOLD_HI[1] + (GOLD_LO[1] - GOLD_HI[1]) * v // 255),
        idx.point(lambda v: GOLD_HI[2] + (GOLD_LO[2] - GOLD_HI[2]) * v // 255),
        Image.new("L", (size, size), 255),
    ))


def _badge_form(size: int) -> Image.Image:
    """小档(≤24px)徽标形:金渐变圆角方块 + 墨色「御」= app 内品牌徽标
    (app_shell.dart:BoxDecoration 渐变 accent→accentDeep + onAccent 字,
    圆角 11/34)。2026-09-16 用户拍板:托盘/app 内必须同一,印章简化形退役。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1],
        radius=max(2, round(size * BADGE_RADIUS_RATIO)), fill=255)
    img.paste(_badge_gradient(size), (0, 0), mask)
    gm = Image.new("L", (size, size), 0)
    font = ImageFont.truetype(FONT_PATH, max(8, int(size * BADGE_GLYPH_FRACTION)))
    ImageDraw.Draw(gm).text(
        (size / 2, size / 2 * 1.02), "御", font=font, fill=255, anchor="mm")
    img.paste(Image.new("RGBA", (size, size), ON_ACCENT + (255,)), (0, 0), gm)
    return img


def make_icon(size: int, simple: bool) -> Image.Image:
    """渲染单档。simple=True:徽标形(小档与 app 内品牌徽标同一,见模块头)。"""
    if simple or size <= SIMPLE_MAX:
        return _badge_form(size)

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = _rounded_mask(size)

    base = Image.new("RGBA", (size, size), INK + (255,))
    if size >= 48:
        # 大档:极轻纵向明度渐变给体积感(暗主题「描边分层」气质)。
        shade = Image.linear_gradient("L").resize((size, size)).point(lambda v: 255 - v // 6)
        base = Image.composite(
            Image.new("RGBA", (size, size), (16, 20, 28, 255)), base, shade)
    img.paste(base, (0, 0), mask)

    # 金渐变「御」:字形蒙版贴渐变(雅黑 Bold,anchor 居中)。
    gm = Image.new("L", (size, size), 0)
    font = ImageFont.truetype(FONT_PATH, int(size * GLYPH_FRACTION))
    ImageDraw.Draw(gm).text(
        (size / 2, size / 2 * 1.02), "御", font=font, fill=255, anchor="mm")
    img.paste(_gold_gradient(size), (0, 0), gm)
    return img


def save_ico(path: str, sizes: list[int]) -> None:
    """逐档独立渲染后合成 ICO(每档原生帧,PIL 不重采样)。"""
    frames = [make_icon(s, simple=(s <= SIMPLE_MAX)) for s in sizes]
    frames[0].save(
        path, format="ICO",
        append_images=frames[1:],
        sizes=[(s, s) for s in sizes],
    )
    print(f"OK {path}: {sizes}")


def main() -> None:
    if not os.path.exists(FONT_PATH):
        sys.exit(f"FATAL: 字体缺失 {FONT_PATH}(ADR-1:报错退出,不静默换字体)")
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    save_ico(os.path.join(root, "windows", "runner", "resources", "app_icon.ico"),
             APP_ICON_SIZES)
    save_ico(os.path.join(root, "assets", "tray_icon.ico"), TRAY_ICON_SIZES)


if __name__ == "__main__":
    main()
