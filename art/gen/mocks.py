"""Pillow mock-ups of each launcher screen, laid out from the same numbers as the scenes
(scenes.py, card_row.gd, card.gd, profile_picker.gd, intro.gd). No display is available here, so
these stand in for screenshots; the in-engine look is unverified until someone runs it on a screen."""
import math

from PIL import Image, ImageDraw, ImageFont

import scenes as SC
from pal import ROOT, rgb

SPR = ROOT / "assets" / "sprites" / "launcher"
OUT = ROOT / "handoff" / "screens"
W, H = 1920, 1080
_cache = {}


def tex(name):
    if name not in _cache:
        p = SPR / name if not str(name).startswith("/") else name
        _cache[name] = Image.open(p).convert("RGBA")
    return _cache[name]


# 2D affine as (a, b, c, d, e, f): x' = a x + b y + c ; y' = d x + e y + f
def mul(m, n):
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a * A + b * D, a * B + b * E, a * C + b * F + c, d * A + e * D, d * B + e * E, d * C + e * F + f)


def T(x, y):
    return (1, 0, x, 0, 1, y)


def R(r):
    c, s = math.cos(r), math.sin(r)
    return (c, -s, 0, s, c, 0)


def Sc(sx, sy):
    return (sx, 0, 0, 0, sy, 0)


def inv(m):
    a, b, c, d, e, f = m
    det = a * e - b * d
    ia, ib, id_, ie = e / det, -b / det, -d / det, a / det
    return (ia, ib, -(ia * c + ib * f), id_, ie, -(id_ * c + ie * f))


def control(pos, pivot, rot=0.0, scale=(1, 1)):
    """Godot Control transform: translate(pos + pivot) * rot * scale * translate(-pivot)."""
    return mul(mul(mul(T(pos[0] + pivot[0], pos[1] + pivot[1]), R(rot)), Sc(*scale)), T(-pivot[0], -pivot[1]))


def node2d(pos, rot=0.0, scale=(1, 1)):
    return mul(mul(T(*pos), R(rot)), Sc(*scale))


def draw(canvas, img, m, alpha=1.0):
    if alpha <= 0.001:
        return
    layer = img.transform(canvas.size, Image.Transform.AFFINE, inv(m), resample=Image.Resampling.BICUBIC)
    if alpha < 1:
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * alpha)))
    canvas.alpha_composite(layer)


def sprite(canvas, img, parent, pos, offset=None, scale=(1, 1), rot=0.0, alpha=1.0):
    off = offset if offset is not None else (-img.width / 2, -img.height / 2)
    draw(canvas, img, mul(mul(parent, node2d(pos, rot, scale)), T(*off)), alpha)


def background(t=0.0):
    c = tex("bg_sky.png").copy()
    cl = tex("bg_clouds.png")
    dx = int((t * 0.006 * W)) % W
    c.alpha_composite(_scroll(cl, dx))
    for i, (kind, x, y) in enumerate(SC.FLOATERS):
        s = math.sin(t * 1.4 + x * 0.011 + y * 0.007 + i)
        sprite(c, tex(f"floater_{kind}.png"), T(0, 0), (x, y + 12 * s), scale=(1 + 0.06 * s, 1 - 0.06 * s))
    c.alpha_composite(tex("bg_hills.png"))
    return c


def _scroll(img, dx):
    out = Image.new("RGBA", img.size)
    out.paste(img.crop((dx, 0, img.width, img.height)), (0, 0))
    out.paste(img.crop((0, 0, dx, img.height)), (img.width - dx, 0))
    return out


# ---------------------------------------------------------------- intro
def lerp(a, b, t):
    return a + (b - a) * t


def key(path, prop, t, default):
    keys = SC.ANIM.get(path, {}).get(prop)
    if not keys:
        return default
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / (t1 - t0) if t1 > t0 else 1
            if isinstance(v0, tuple):
                return tuple(lerp(a, b, u) for a, b in zip(v0, v1))
            return lerp(v0, v1, u)
    return keys[-1][1]


def intro_frame(t):
    c = background(t)
    # PopBurst
    pb_s = key("PopBurst", "scale", t, (0.2, 0.2))
    pb_a = key("PopBurst", "modulate", t, (1, 1, 1, 0))[3]
    sprite(c, tex("pop_burst.png"), T(0, 0), SC.POP_AT, scale=pb_s, rot=key("PopBurst", "rotation", t, 0.0), alpha=pb_a)
    # Jar wobble (intro.gd: 5 x 0.1 s rotation steps)
    seq = [0, 0.06, -0.06, 0.08, -0.08, 0.0]
    i = min(int(t / 0.1), 4)
    jr = lerp(seq[i], seq[i + 1], min(1, t / 0.1 - i)) if t < 0.5 else 0.0
    jm = control((810, 560), (150, 360), jr)
    sprite(c, tex("jar_body.png"), jm, SC.JAR_SPRITE["position"], SC.JAR_SPRITE["offset"], key("Jar/Sprite", "scale", t, (1, 1)))
    u = max(0, min(1, (t - 0.5) / 0.4))
    lm = mul(jm, control((lerp(-20, 240, u), lerp(-60, -580, u)), (170, 35), 2.5 * u))
    sprite(c, tex("jar_lid.png"), lm, SC.LID_SPRITE["position"], scale=key("Jar/Lid/Sprite", "scale", t, (1, 1)))
    # Jeff / Chuck tumble (intro.gd _tumble)
    start = (810 + 150 - 120, 560 + 180 - 120)
    for name, rest, t0, d, png in (("Jeff", (380, 700), 0.6, -1, "jeff_standin.png"), ("Chuck", (1300, 700), 0.7, 1, "chuck_standin.png")):
        if t < t0:
            continue
        u = min(1, (t - t0) / 1.0)
        peak = ((start[0] + rest[0]) / 2, (start[1] + rest[1]) / 2 - 380)
        a = (lerp(start[0], peak[0], u), lerp(start[1], peak[1], u))
        b = (lerp(peak[0], rest[0], u), lerp(peak[1], rest[1], u))
        p = (lerp(a[0], b[0], u), lerp(a[1], b[1], u))
        s = min(1, (t - t0) / 0.25)
        m = control(p, (120, 120), d * math.tau * u, (s, s))
        sprite(c, tex(png), m, SC.CHAR_SPRITE["position"], SC.CHAR_SPRITE["offset"], key(f"{name}/Sprite", "scale", t, (1, 1)))
    for name, (x, y) in SC.DUST.items():
        sprite(c, tex("dust_puff.png"), T(0, 0), (x, y), (-100, -90), key(name, "scale", t, (0.3, 0.3)), alpha=key(name, "modulate", t, (1, 1, 1, 0))[3])
    sprite(c, tex("pop_burst.png"), T(0, 0), SC.THUMP_AT, scale=key("ThumpBurst", "scale", t, (0.5, 0.5)),
           alpha=key("ThumpBurst", "modulate", t, (1, 1, 1, 0))[3])
    if t >= 1.8:
        l, tp, r, b = SC.LOGO_RECT
        u = min(1, (t - 1.8) / 0.35)
        y = tp - 700 * (1 - u * u)
        m = control((l, y), ((r - l) / 2, (b - tp) / 2))
        sprite(c, tex("logo.png"), m, SC.LOGO_SPRITE["position"], SC.LOGO_SPRITE["offset"], key("Logo/Sprite", "scale", t, (1, 1)))
    shake = 18 if 2.15 <= t < 2.2 else (-12 if 2.2 <= t < 2.25 else 0)
    if shake:
        bg = background(t)
        bg.paste(c.crop((0, 0, W, H - abs(shake))), (0, max(0, shake)))
        c = bg
    return c


# ---------------------------------------------------------------- cards
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def nine_patch(img, w, h, m):
    out = Image.new("RGBA", (w, h))
    sw, sh = img.size
    xs, ys = [0, m, sw - m, sw], [0, m, sh - m, sh]
    dx, dy = [0, m, w - m, w], [0, m, h - m, h]
    for i in range(3):
        for j in range(3):
            part = img.crop((xs[i], ys[j], xs[i + 1], ys[j + 1]))
            tw, th = dx[i + 1] - dx[i], dy[j + 1] - dy[j]
            if tw > 0 and th > 0:
                out.paste(part.resize((tw, th), Image.Resampling.BILINEAR), (dx[i], dy[j]))
    return out


def card_image(entry, highlighted):
    """600x900 card + margin 64 for the glow ring. entry: {tile: int|None, art: path|None, name, dev}."""
    M = 64
    out = Image.new("RGBA", (600 + 2 * M, 900 + 2 * M))
    if highlighted:
        out.alpha_composite(nine_patch(Image.open(ROOT / "assets/sprites/ui/glow_ring.png").convert("RGBA"), 728, 1028, 96))
    face = Image.new("RGBA", (600, 900))
    if entry.get("art"):
        art = Image.open(entry["art"]).convert("RGBA").resize((600, 900))
        mask = Image.new("L", (2400, 3600), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, 2399, 3599), 192, fill=255)
        mask = mask.resize((600, 900), Image.Resampling.BOX)
        edge = Image.new("L", (2400, 3600), 0)
        d = ImageDraw.Draw(edge)
        d.rounded_rectangle((0, 0, 2399, 3599), 192, fill=255)
        d.rounded_rectangle((72, 72, 2399 - 72, 3599 - 72), 120, fill=0)
        edge = edge.resize((600, 900), Image.Resampling.BOX)
        face.paste(art, (0, 0), mask)
        ink = Image.new("RGBA", (600, 900), rgb("ink") + (255,))
        face.paste(ink, (0, 0), edge)
    else:
        atlas = tex("card_tiles.png")
        k = entry["tile"]
        tile = atlas.crop(((k % 3) * 450, (k // 3) * 675, (k % 3 + 1) * 450, (k // 3 + 1) * 675))
        face.alpha_composite(tile.resize((600, 900), Image.Resampling.LANCZOS))
        if entry.get("name"):
            d = ImageDraw.Draw(face)
            f = ImageFont.truetype(FONT, 56)
            d.text((300, 800), entry["name"], font=f, fill=rgb("ink"), anchor="mm")
    if entry.get("dev"):
        b = tex("dev_badge.png")
        face.alpha_composite(b, (530 - b.width // 2, 72 - b.height // 2))
    out.alpha_composite(face, (M, M))
    return out


def card_row(entries, index, t=0.0):
    c = background(t)
    order = sorted(range(len(entries)), key=lambda i: i == index)
    for i in order:
        hl = i == index
        s = 0.72 if hl else 0.6
        img = card_image(entries[i], hl)
        cx = 960 + (i - index) * 440
        m = mul(mul(T(cx, 560), Sc(s, s)), T(-img.width / 2, -img.height / 2))
        draw(c, img, m)
    return c


def picker(index):
    c = background(0.4)
    for i, (k, x) in enumerate((("a", 440), ("b", 1080))):
        sel = i == index
        s = 1.15 if sel else 0.8
        img = tex(f"face_{k}_{'happy' if sel else 'calm'}.png").resize((400, 400), Image.Resampling.LANCZOS)
        if not sel:   # face_calm.gdshader: solid, multiplied towards slate by 2 x 0.5
            r, g, b, a = img.split()
            sr, sg, sb = rgb("stone")
            img = Image.merge("RGBA", (r.point(lambda v: int(v * sr / 255)), g.point(lambda v: int(v * sg / 255)),
                                       b.point(lambda v: int(v * sb / 255)), a))
        draw(c, img, control((x, 340), (200, 200), 0, (s, s)))
    return c


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    times = [0.3, 0.56, 1.1, 1.6, 2.16, 2.8]
    sheet = Image.new("RGBA", (1920, 1080), rgb("ink") + (255,))
    for n, t in enumerate(times):
        f = intro_frame(t)
        if t == 2.8:
            f.convert("RGB").save(OUT / "intro_end.png")
        if t == 2.16:
            f.convert("RGB").save(OUT / "intro_thump.png")
        sheet.paste(f.resize((628, 353), Image.Resampling.LANCZOS), (8 + (n % 3) * 637, 120 + (n // 3) * 450))
        d = ImageDraw.Draw(sheet)
        d.text((14 + (n % 3) * 637, 478 + (n // 3) * 450), f"t = {t:.2f} s", font=ImageFont.truetype(FONT, 28), fill=rgb("cloud"))
    ImageDraw.Draw(sheet).text((14, 30), "Intro keyframes (Pillow mock of intro.tscn + intro.gd timing; not an engine capture)",
                               font=ImageFont.truetype(FONT, 34), fill=rgb("cloud"))
    sheet.convert("RGB").save(OUT / "intro_keyframes.png")
    entries = [{"tile": 3, "name": "Smash Party"}, {"art": ROOT / "store" / "grid.png"},
               {"tile": 0, "name": "Worm Dig", "dev": True}, {"tile": 2, "name": "Spaceballs"}]
    card_row(entries, 1).convert("RGB").save(OUT / "cards.png")
    card_row(entries, 2).convert("RGB").save(OUT / "cards_dev_highlight.png")
    card_row([{"tile": 5}], 0).convert("RGB").save(OUT / "cards_empty.png")
    picker(1).convert("RGB").save(OUT / "picker.png")
    for p in sorted(OUT.glob("*.png")):
        print("wrote", p.relative_to(ROOT))
