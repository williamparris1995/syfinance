# -*- coding: utf-8 -*-
"""御财 App 图标管线(F23,spec FR-1~4):字符标「御」变体 A。

变体 A(2026-09-15 用户三选一拍板):墨底圆角方块 + 鎏金渐变「御」单字。
令牌取 design-v2(design-v2.md §2):墨底 #0B0E13 / 鎏金 #E8C07A→#C9964A。

产物(幂等,重跑即再生成):
  windows/runner/resources/app_icon.ico  六档 16/24/32/48/64/256(≤20px 简化形)
  assets/tray_icon.ico                  16/24 简化形专用档(托盘渲染档)

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
GOLD_HI = (232, 192, 122)   # #E8C07A 鎏金亮端
GOLD_LO = (201, 150, 74)    # #C9964A 鎏金暗端
RADIUS_RATIO = 0.19         # 圆角率(Fluent 系圆角方块)
GLYPH_FRACTION = 0.64       # 全形字面占比
                                  # (16px 下 12 画不可逐笔辨认,走印章式剪影:
                                  #   MaxFilter 滤波融笔画 — 支付宝/微信 16px 先例)
FONT_PATH = r"C:\Windows\Fonts\msyhbd.ttc"

APP_ICON_SIZES = [256, 64, 48, 32, 24, 16]  # exe 六档(FR-2)
TRAY_ICON_SIZES = [24, 16]                  # 托盘简化档(FR-3)
SIMPLE_MAX = 24  # ≤此档位用简化形(去细节、字占满)


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


def _simple_form_glyph(size: int) -> Image.Image:
    """小档(≤24px)简化形:印章外框 + 三笔抽象「御」(左竖=彳、右上横、右下横=卸/止)。

    手绘基元而非字体降采样(vision QC 两轮裁决:滤波剪影边缘破碎不可辨;
    行业先例=支付宝 16px「支」两笔交叉)。双色阶:暗金外框 + 亮金笔画,
    弃平滑渐变(小尺寸渐变加剧碎裂感)。
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = max(1, size // 8)        # 外框描边粗
    inset = max(2, size // 7)    # 外框内缩
    d.rounded_rectangle([inset, inset, size - 1 - inset, size - 1 - inset],
                        radius=max(2, size // 6), outline=GOLD_LO, width=m)
    w = max(1, size // 9)        # 笔画粗
    x0 = size * 30 // 100        # 左竖(彳 抽象)
    d.rectangle([x0, size * 28 // 100, x0 + w, size * 74 // 100], fill=GOLD_HI)
    y1 = size * 30 // 100        # 右上横(卸首横抽象)
    d.rectangle([size * 46 // 100, y1, size * 72 // 100, y1 + w], fill=GOLD_HI)
    y2 = size * 59 // 100        # 右下横(止 抽象;59%=QC 裁决与框底留暗底间隙)
    d.rectangle([size * 46 // 100, y2, size * 72 // 100, y2 + w], fill=GOLD_HI)
    return img


def make_icon(size: int, simple: bool) -> Image.Image:
    """渲染单档。simple=True:印章简化形(小尺寸防糊,ADR-3)。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = _rounded_mask(size)

    base = Image.new("RGBA", (size, size), INK + (255,))
    if not simple and size >= 48:
        # 大档:极轻纵向明度渐变给体积感(暗主题「描边分层」气质)。
        shade = Image.linear_gradient("L").resize((size, size)).point(lambda v: 255 - v // 6)
        base = Image.composite(
            Image.new("RGBA", (size, size), (16, 20, 28, 255)), base, shade)
    img.paste(base, (0, 0), mask)

    if simple or size <= 24:
        img.alpha_composite(_simple_form_glyph(size))
        return img

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
