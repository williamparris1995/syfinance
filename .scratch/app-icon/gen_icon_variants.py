# -*- coding: utf-8 -*-
"""F23 字符标「御」图标变体预览生成(brainstorm 已定方向:墨底+鎏金渐变单字)。

令牌取 design-v2:墨底 #0B0E13 / 鎏金 #E8C07A→#C9964A / 亮底演示 #F8FAFC。
三变体:A 实心墨底金渐变字 / B 金渐变描边款(私行印章感) / C 墨底+底部金条细节。
16px 简化形:全部去掉细节,粗体单字占满。
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

INK = (11, 14, 19)        # #0B0E13
GOLD_HI = (232, 192, 122) # #E8C07A
GOLD_LO = (201, 150, 74)  # #C9964A
FONT_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"

def gold_gradient(size, horizontal=False):
    """135° 对角金渐变(近似:垂直渐变旋转 45° 再裁切)。"""
    g = Image.linear_gradient("L").resize((size, size))  # 上黑下白
    g = g.rotate(45, expand=False)                        # 对角
    # 用灰度作索引在两金色间插值
    r = Image.merge("RGBA", (
        g.point(lambda v: GOLD_LO[0] + (GOLD_HI[0] - GOLD_LO[0]) * v // 255),
        g.point(lambda v: GOLD_LO[1] + (GOLD_HI[1] - GOLD_LO[1]) * v // 255),
        g.point(lambda v: GOLD_LO[2] + (GOLD_HI[2] - GOLD_LO[2]) * v // 255),
        Image.new("L", (size, size), 255),
    ))
    return r

def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m

def glyph_mask(size, frac, bold_path=FONT_BOLD):
    img = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(bold_path, int(size * frac))
    d.text((size / 2, size / 2 * 1.02), "御", font=f, fill=255, anchor="mm")
    return img

def make_icon(size, variant, simple=False):
    """simple=True → 16px 简化形(去细节,字占满)。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    radius = max(2, int(size * 0.19))
    mask = rounded_mask(size, radius)

    # 底:墨色(细微纵向明度渐变增加体积感)
    base = Image.new("RGBA", (size, size), INK + (255,))
    if not simple and size >= 48:
        shade = Image.linear_gradient("L").resize((size, size)).point(lambda v: 255 - v // 6)
        base = Image.composite(
            Image.new("RGBA", (size, size), (16, 20, 28, 255)), base, shade)
    img.paste(base, (0, 0), mask)

    d = ImageDraw.Draw(img)
    if variant == "B" and not simple:
        # 金渐变描边(先大圆角金底,再内缩墨圆角)
        border = max(2, int(size * 0.045))
        gold = gold_gradient(size)
        img.paste(gold, (0, 0), mask)
        inner = rounded_mask(size - 2 * border, radius - border)
        img.paste(base.crop((border, border, size - border, size - border)),
                  (border, border), inner)
    if variant == "C" and not simple and size >= 48:
        # 底部金渐变条(远端小细节)
        bar_h = max(3, int(size * 0.045))
        bar = gold_gradient(size).crop((0, size - bar_h, size, size))
        bar_mask = Image.new("L", (size, bar_h), 0)
        ImageDraw.Draw(bar_mask).rounded_rectangle(
            [size*0.28, 0, size*0.72, bar_h], radius=bar_h//2, fill=255)
        img.paste(bar, (0, size - int(size*0.10) - bar_h), bar_mask)

    # 金渐变单字(经字形蒙版贴渐变)
    frac = 0.74 if simple else (0.60 if variant == "B" else 0.64)
    if size <= 20:
        frac = 0.78  # 小尺寸字占满
    gm = glyph_mask(size, frac)
    img.paste(gold_gradient(size), (0, 0), gm)

    if not simple and size >= 128:
        # 大尺寸:字形外发一点极淡金晕,私行质感(可去)
        pass
    return img

def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    variants = ["A", "B", "C"]
    sizes = [256, 48, 16]
    files = {}
    for v in variants:
        for s in sizes:
            im = make_icon(s, v, simple=(s == 16))
            p = os.path.join(out_dir, f"v{v}_{s}.png")
            im.save(p)
            files[(v, s)] = p
    # 拼图:3 变体 × 3 尺寸,上下两条背景(暗/亮)
    pad, cell = 24, 280
    W = pad + 3 * (cell + pad)
    H = pad + (cell + 48) * 2 + 40
    sheet = Image.new("RGB", (W, H), (24, 26, 30))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 18)
    except Exception:
        font = ImageFont.load_default()
    for row, (bg, label) in enumerate([((11,14,19), "暗底"), ((248,250,252), "亮底")]):
        y0 = pad + row * (cell + 48) + 40
        for col, v in enumerate(variants):
            x0 = pad + col * (cell + pad)
            d.rectangle([x0, y0, x0 + cell, y0 + cell], fill=bg,
                        outline=(60, 64, 74) if row == 0 else (203, 213, 225))
            for k, s in enumerate(sizes):
                im = Image.open(files[(v, s)]).convert("RGBA")
                scale = 200 if s == 256 else (44 if s == 48 else 40)  # 16 原尺寸但放大位示意
                if s == 16:
                    im = im.resize((40, 40), Image.NEAREST)  # 像素级示意
                else:
                    im = im.resize((scale, scale), Image.LANCZOS)
                px = x0 + 16 + k * 84
                py = y0 + cell - im.height - 18
                sheet.paste(im, (px, py), im)
            d.text((x0 + 12, y0 + 8), f"变体 {v}" + {0:" 实心金渐变字", 1:" 金描边印章", 2:" 底部金条"}[col],
                   fill=(232,192,122) if row == 0 else (15,23,42), font=font)
            if row == 0:
                d.text((x0 + 12, y0 + 30), "256 / 48 / 16(放大示意)", fill=(139,147,163), font=font)
    p = os.path.join(out_dir, "contact_sheet.png")
    sheet.save(p)
    print(p)

if __name__ == "__main__":
    build(os.path.join(os.path.dirname(__file__), "icon_variants"))
