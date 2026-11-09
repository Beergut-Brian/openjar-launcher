"""Original chunky stroke letters for the wordmark (cap height 100, y down, baseline at 100).
Each glyph is (width, [polyline, ...]); the logo strokes them thick with round caps and joins."""
from vec import arc, circle

G = {
    "O": (80, [arc(40, 50, 40, 50, 0, 360, 72)]),
    "P": (60, [[(0, 100), (0, 0), (30, 0)] + arc(30, 27, 30, 27, -90, 90, 24)[1:] + [(0, 54)]]),
    "E": (54, [[(54, 0), (0, 0), (0, 100), (54, 100)], [(0, 50), (44, 50)]]),
    "N": (66, [[(0, 100), (0, 0), (66, 100), (66, 0)]]),
    "J": (56, [[(22, 0), (56, 0), (56, 64)] + arc(28, 64, 28, 36, 0, 160, 24)[1:]]),
    "A": (74, [[(0, 100), (37, 0), (74, 100)], [(15, 64), (59, 64)]]),
    "R": (62, [[(0, 100), (0, 0), (30, 0)] + arc(30, 26, 30, 26, -90, 90, 24)[1:] + [(0, 52)], [(26, 52), (62, 100)]]),
    "G": (80, [arc(40, 50, 40, 50, -40, -345, 60) + [(80, 52), (48, 52)]]),
    "M": (86, [[(0, 100), (0, 0), (43, 64), (86, 0), (86, 100)]]),
    "S": (60, [arc(30, 25, 30, 25, -25, -270, 30) + arc(30, 75, 30, 25, -90, 155, 30)[1:]]),
    "B": (62, [[(0, 48), (28, 48)] + arc(28, 24, 28, 24, 90, -90, 20)[1:] + [(0, 0), (0, 100), (32, 100)]
               + arc(32, 74, 30, 26, 90, -90, 20)[1:] + [(0, 48)]]),
    "C": (76, [arc(42, 50, 42, 50, -45, -315, 60)]),
}
SPACE = 34


def layout(text, x, y, size, tracking=0.0, rot=(), dy=(), fw_ratio=0.26):
    """Returns [(polylines, (cx, cy))] per glyph, placed with baseline at y (+ per-letter bounce).
    Advance includes the stroke width so outlined letters just kiss."""
    from vec import xform
    s = size / 100.0
    fw = size * fw_ratio
    out = []
    pen = x
    i = -1
    for ch in text:
        if ch == " ":
            pen += SPACE * s
            continue
        i += 1
        w, lines = G[ch]
        r = rot[i % len(rot)] if rot else 0.0
        oy = dy[i % len(dy)] if dy else 0.0
        cx, cy = pen + fw / 2 + w * s / 2, y - size / 2 + oy
        placed = [xform(pl, tx=pen + fw / 2, ty=y - size + oy, s=s) for pl in lines]
        placed = [xform(pl, rot=r, ox=cx, oy=cy) for pl in placed]
        out.append((placed, (cx, cy)))
        pen += w * s + fw + tracking * s
    return out, pen - x


def width(text, size, tracking=0.0, fw_ratio=0.26):
    return layout(text, 0, 0, size, tracking, fw_ratio=fw_ratio)[1]


def draw_word(sc, text, x, y, size, fill, tracking=0.0, rot=(), dy=(), shadow="sky5", shadow_off=(0.06, 0.10),
              ow_ratio=0.085, fw_ratio=0.26, shine=True):
    """Shadow pass, ink outline pass, fill pass, a small shine on each letter."""
    glyphs, _ = layout(text, x, y, size, tracking, rot, dy, fw_ratio)
    fw, ow = size * fw_ratio, size * ow_ratio
    fills = fill if isinstance(fill, (list, tuple)) else [fill]
    if shadow:
        sx, sy = shadow_off[0] * size, shadow_off[1] * size
        for lines, _ in glyphs:
            for pl in lines:
                sc.line([(px + sx, py + sy) for px, py in pl], "ink", fw + 2 * ow)
        for lines, _ in glyphs:
            for pl in lines:
                sc.line([(px + sx, py + sy) for px, py in pl], shadow, fw)
    for lines, _ in glyphs:
        for pl in lines:
            sc.line(pl, "ink", fw + 2 * ow)
    for i, (lines, _) in enumerate(glyphs):
        for pl in lines:
            sc.line(pl, fills[i % len(fills)], fw)
        if shine:
            p0 = lines[0][0] if len(lines[0]) < 40 else lines[0][len(lines[0]) // 2]
            sc.poly(circle(p0[0] - fw * 0.16, p0[1] - fw * 0.16, fw * 0.11, 16), fill="cloud")
    return glyphs
