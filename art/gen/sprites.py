"""Launcher sprites: intro stand-ins, profile faces, dev badge, card tiles, sky layers, glow ring."""
import math
import random

from vec import Scene, arc, bezier, circle, ellipse, rrect, star, xform
from logos import jar, sparkle

OW = 7  # outline half-width for 240 px figures


def jeff():
    """P1 stand-in (240x240, feet on y=234): round chicken hood with comb, beak above the face,
    yellow puffy body, green wing tips + headband + jeans stitching, flared jeans, big bare feet."""
    sc = Scene(240, 240)
    feet = [(ellipse(92, 224, 27, 11), "clay"), (ellipse(150, 224, 27, 11), "clay")]
    legs = [([(96, 166), (114, 166), (118, 216), (88, 216)], "jeans_blue"),
            ([(126, 166), (144, 166), (152, 216), (122, 216)], "jeans_blue")]
    wings = [(ellipse(70, 140, 17, 32, rot=20), "jeff_yellow"), (ellipse(170, 140, 17, 32, rot=-20), "jeff_yellow")]
    tips = [(ellipse(62, 162, 11, 13, rot=20), "p1_green"), (ellipse(178, 162, 11, 13, rot=-20), "p1_green")]
    body = [(ellipse(120, 140, 52, 40), "jeff_yellow")]
    comb = [(circle(100, 25, 12), "comb"), (circle(120, 18, 14), "comb"), (circle(140, 25, 12), "comb")]
    hood = [(circle(120, 74, 48), "jeff_yellow")]
    sc.outlined(feet + legs + wings + tips + body + comb + hood, OW,
                details=[("line", [(103, 172), (106, 210)], "p1_green", 3), ("line", [(135, 172), (138, 210)], "p1_green", 3)])
    # headband across the hood, under the comb
    band = arc(120, 74, 40, 40, 218, 322, 30)
    sc.line(band, "ink", 15)
    sc.line(band, "p1_green", 8)
    # face opening + beak above it
    sc.outlined([(ellipse(120, 88, 31, 26), "clay")], 4)
    sc.outlined([([(101, 60), (139, 60), (120, 78)], "magma")], 4)
    # half-lidded happy eyes, big two-tooth grin
    for ex in (107, 133):
        sc.line(arc(ex, 88, 6.5, 5, 200, 340, 12), "ink", 4.5)
    mouth = arc(120, 95, 14, 11, 0, 180, 20)
    sc.poly(mouth, fill="ink")
    sc.poly(rrect(113, 95, 6.5, 6, 1.5), fill="cloud")
    sc.poly(rrect(120.5, 95, 6.5, 6, 1.5), fill="cloud")
    return sc


def dino(cx, cy, s):
    """Small original chunky dinosaur silhouette for the hat panel (faces right)."""
    body = ellipse(cx - 1 * s, cy + 2 * s, 7 * s, 5 * s)
    head = rrect(cx + 3 * s, cy - 7 * s, 8 * s, 6 * s, 2.5 * s)
    neck = [(cx + 1 * s, cy - 2 * s), (cx + 6 * s, cy - 5 * s), (cx + 6 * s, cy + 1 * s)]
    tail = [(cx - 6 * s, cy), (cx - 13 * s, cy + 6 * s), (cx - 5 * s, cy + 5 * s)]
    legs = [rrect(cx - 4 * s, cy + 5 * s, 3 * s, 4 * s, 1 * s), rrect(cx + 1 * s, cy + 5 * s, 3 * s, 4 * s, 1 * s)]
    return [body, head, neck, tail] + legs


def chuck():
    """P2 stand-in (240x240): flat-topped trucker hat (red brim + panel edge, yellow dino), boxy black
    tie-dye shirt with red swirl and stone rim line, straight jeans, brown heeled boots, stiff posture."""
    sc = Scene(240, 240)
    boots = [([(90, 206), (112, 206), (112, 222), (122, 224), (122, 233), (80, 233), (80, 222)], "boots_brown"),
             ([(128, 206), (150, 206), (160, 222), (160, 233), (118, 233), (118, 224), (128, 222)], "boots_brown")]
    heels = [(rrect(80, 226, 10, 10, 2), "boots_brown"), (rrect(150, 226, 10, 10, 2), "boots_brown")]
    legs = [(rrect(91, 160, 21, 50, 3), "jeans_blue"), (rrect(128, 160, 21, 50, 3), "jeans_blue")]
    arms = [(rrect(60, 104, 18, 54, 7), "shirt_black"), (rrect(162, 104, 18, 54, 7), "shirt_black")]
    hands = [(circle(69, 164, 10), "clay"), (circle(171, 164, 10), "clay")]
    torso = [(rrect(74, 98, 92, 70, 12), "shirt_black")]
    head = [(rrect(88, 44, 64, 60, 22), "clay")]
    crown = [([(86, 54), (90, 12), (150, 12), (154, 54)], "hat_black")]
    brim = [(arc(120, 52, 50, 14, 180, 360, 24)[::-1] + arc(120, 52, 50, 6, 0, 180, 24)[1:-1], "p2_red")]
    sc.outlined(boots + heels + legs + arms + hands + torso + head + crown + brim, OW,
                details=[("line", [(84, 220), (110, 220)], "p2_red", 2.5), ("line", [(130, 220), (156, 220)], "p2_red", 2.5)])
    # stone rim inside the dark parts (near-black can't contrast with ink)
    sc.line(rrect(78, 102, 84, 62, 9), "stone", 2.5, closed=True)
    sc.line([(92, 50), (95, 17), (145, 17), (148, 50)], "p2_red", 4.5)
    for part in dino(118, 32, 1.25):
        sc.poly(part, fill="jeff_yellow")
    # tie-dye swirl
    sw = [(120 + (3 + t * 2.2) * math.cos(t * 0.9), 132 + (3 + t * 2.2) * math.sin(t * 0.9)) for t in [i * 0.25 for i in range(46)]]
    sc.line(sw, "p2_red", 6)
    for x, y in ((92, 112), (150, 152), (146, 110), (96, 154)):
        sc.poly(circle(x, y, 3.5, 12), fill="cloud")
    # face: thick brows, squint, determined (slightly smug) mouth
    sc.line([(99, 64), (114, 69)], "ink", 7)
    sc.line([(126, 69), (141, 64)], "ink", 7)
    sc.line([(102, 77), (112, 77)], "ink", 5)
    sc.line([(128, 77), (138, 77)], "ink", 5)
    sc.line([(108, 92), (126, 92), (133, 88)], "ink", 5)
    return sc


def face(base, accent, picked, kind):
    """Profile face 512x512. kind 0: tuft + freckles; kind 1: two round ears + rosy cheeks."""
    sc = Scene(512, 512)
    ow = 14
    parts = []
    if kind == 0:
        parts.append(([(236, 70), (250, 18), (268, 46), (296, 26), (286, 76)], base))
    else:
        parts += [(circle(130, 118, 62), base), (circle(382, 118, 62), base)]
    parts.append((circle(256, 270, 200), base))
    sc.outlined(parts, ow)
    if kind == 1:
        sc.poly(circle(130, 118, 30), fill=accent)
        sc.poly(circle(382, 118, 30), fill=accent)
    cheek = accent
    sc.poly(ellipse(150, 330, 34, 22), fill=cheek, alpha=0.9)
    sc.poly(ellipse(362, 330, 34, 22), fill=cheek, alpha=0.9)
    if kind == 0:
        for x, y in ((140, 300), (160, 318), (130, 322), (372, 300), (352, 318), (382, 322)):
            sc.poly(circle(x, y, 6, 12), fill="topsoil")
    if not picked:
        for ex in (190, 322):
            sc.poly(ellipse(ex, 240, 24, 32), fill="ink")
            sc.poly(circle(ex + 8, 228, 9, 16), fill="cloud")
        sc.line(arc(256, 320, 58, 34, 20, 160, 24), "ink", 14)
    else:
        for ex in (190, 322):
            sc.line(arc(ex, 252, 30, 26, 200, 340, 20), "ink", 14)
        mouth = arc(256, 300, 80, 76, 0, 180, 32)
        sc.outlined([(mouth, "ink")], 4)
        sc.poly(ellipse(256, 352, 40, 22), fill="comb")
        sc.poly(rrect(214, 300, 84, 18, 6), fill="cloud")
        sparkle(sc, 80, 230, 28, "jeff_yellow", 6)
        sparkle(sc, 440, 210, 22, "cloud", 6)
    return sc


def dev_badge():
    """150x150: round badge with a little bubbling flask (dev builds)."""
    sc = Scene(150, 150)
    sc.outlined([(circle(75, 75, 62), "magma")], 7)
    flask = [(62, 34), (88, 34), (88, 56), (110, 104)] + arc(75, 104, 35, 14, 0, 180, 16)[1:] + [(40, 104), (62, 56)]
    liquid = [(52, 82), (98, 82), (110, 104)] + arc(75, 104, 35, 14, 0, 180, 16)[1:] + [(40, 104)]
    sc.outlined([(flask, "cloud"), (rrect(56, 28, 38, 12, 5), "cloud")], 6, details=[(liquid, "grass")])
    sc.line([(56, 104), (56, 104)], "cloud", 1)
    for x, y, r in ((68, 96, 5), (84, 88, 4), (78, 70, 4.5), (88, 58, 3.5)):
        sc.outlined([(circle(x, y, r, 14), "cloud")], 2.5)
    return sc


# ---------- card tiles (450x675 each; the card stretches them to 600x900) ----------
TW, TH, TR, TO = 450, 675, 36, 7   # tile size, corner radius, outline half-width


def _plate(sc):
    """Light caption plate at the bottom (card.gd draws the game's name over it)."""
    sc.outlined([(rrect(34, 552, TW - 68, 96, 30), "cloud")], 5)


def tile(variant):
    """Returns a Pillow image: palette shapes clipped to the rounded card, ink edge on top."""
    from PIL import Image, ImageDraw
    sc = Scene(TW, TH)
    rnd = random.Random(variant * 17 + 3)
    bgs = [("sky2", "sky3"), ("sky4", "sky5"), ("grass", "sky1"), ("clay", "magma"), ("sky3", "sky4")]
    top, low = bgs[variant]
    sc.poly([(0, 0), (TW, 0), (TW, TH), (0, TH)], fill=top)
    sc.poly(arc(TW / 2, TH * 0.98, TW * 0.9, TH * 0.45, 180, 360, 48) + [(TW, TH), (0, TH)], fill=low)
    for _ in range(14):
        x, y = rnd.uniform(40, TW - 40), rnd.uniform(40, 500)
        sc.poly(circle(x, y, rnd.uniform(5, 10), 14), fill=rnd.choice(["cloud", "jeff_yellow", "comb", "sky1"]), alpha=0.85)
    cx, cy = TW / 2, 300
    if variant == 0:
        sc.outlined([(star(cx, cy, 150, 70, 5), "magma")], 10, details=[(circle(cx - 30, cy - 20, 14), "ink"), (circle(cx + 30, cy - 20, 14), "ink")])
        sc.line(arc(cx, cy + 10, 34, 24, 20, 160, 16), "ink", 10)
    elif variant == 1:
        sc.outlined([(circle(cx, cy, 130), "comb")], 10, details=[(circle(cx + 50, cy - 50, 24), "cloud")])
        sc.outlined([(circle(cx - 70, cy + 120, 50), "jeff_yellow")], 8)
    elif variant == 2:
        sc.outlined([([(cx - 170, 470), (cx - 20, 150), (cx + 120, 470)], "topsoil"),
                     ([(cx + 10, 470), (cx + 110, 260), (cx + 190, 470)], "stone")], 10,
                    details=[([(cx - 63, 240), (cx - 20, 150), (cx + 22, 240), (cx, 225), (cx - 20, 245), (cx - 42, 225)], "cloud")])
    elif variant == 3:
        jar(sc, cx, cy + 50, 280, lid_dx=0.15, lid_dy=-0.16, lid_rot=18)
    else:
        for dx, dy, r, c in ((-80, 40, 80, "grass"), (70, -40, 95, "magma"), (20, 150, 55, "comb")):
            sc.outlined([(circle(cx + dx, cy + dy, r), c)], 10, details=[(circle(cx + dx - r * 0.35, cy + dy - r * 0.35, r * 0.18), "cloud")])
    _plate(sc)
    img = sc.render()
    mask = Image.new("L", (TW * 4, TH * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((TO * 4, TO * 4, (TW - TO) * 4, (TH - TO) * 4), TR * 4, fill=255)
    mask = mask.resize((TW, TH), Image.Resampling.BOX)
    clipped = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    clipped.paste(img, (0, 0), mask)
    edge = Scene(TW, TH)
    edge.line(rrect(TO, TO, TW - 2 * TO, TH - 2 * TO, TR), "ink", 2 * TO, closed=True)
    clipped.alpha_composite(edge.render())
    return clipped


def empty_tile():
    """Empty slot: slate card, dashed light edge, a dashed jar outline in the middle."""
    sc = Scene(TW, TH)
    sc.poly(rrect(TO, TO, TW - 2 * TO, TH - 2 * TO, TR), fill="stone", alpha=0.75)

    def dashed(pts, color, w, dash=7):
        for i in range(0, len(pts) - 1, dash * 2):
            sc.line(pts[i:i + dash + 1], color, w)

    def dense(pts, step=6):
        out = []
        for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
            n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
            out += [(x0 + (x1 - x0) * t / n, y0 + (y1 - y0) * t / n) for t in range(n)]
        return out + out[:1]

    dashed(dense(rrect(26, 26, TW - 52, TH - 52, TR - 10)), "cloud", 12, 5)
    j = xform(rrect(-0.44, -0.30, 0.88, 0.80, 0.26), tx=TW / 2, ty=320, s=220)
    dashed(dense(j, 5), "cloud", 12, 4)
    dashed(dense(xform(rrect(-0.31, -0.48, 0.62, 0.16, 0.05), tx=TW / 2, ty=320, s=220), 5), "cloud", 12, 4)
    sc.line(rrect(TO, TO, TW - 2 * TO, TH - 2 * TO, TR), "ink", 2 * TO, closed=True)
    return sc


# ---------- background layers (1920x1080) ----------
def sky():
    """Five flat sky tiers, space at the top, aqua at the horizon, wavy edges."""
    sc = Scene(1920, 1080)
    tiers = ["sky5", "sky4", "sky3", "sky2", "sky1"]
    sc.poly([(0, 0), (1920, 0), (1920, 1080), (0, 1080)], fill=tiers[0])
    for i, key in enumerate(tiers[1:], 1):
        y = 90 + i * 150
        wave = [(x, y + 18 * math.sin(x / 1920 * math.tau * 3 + i)) for x in range(0, 1921, 32)]
        sc.poly(wave + [(1920, 1080), (0, 1080)], fill=key)
    rnd = random.Random(7)
    for _ in range(46):
        x, y = rnd.uniform(0, 1920), rnd.uniform(10, 300)
        r = rnd.uniform(3, 7)
        sc.poly(star(x, y, r * 2, r * 0.7, 4), fill="cloud", alpha=0.8)
    return sc


def clouds():
    """Tileable horizontal strip of clouds (scrolled by the drift shader), 1920x1080 transparent."""
    sc = Scene(1920, 1080)
    rnd = random.Random(11)
    for i in range(5):
        x = 180 + i * 384 + rnd.uniform(-60, 60)
        y = rnd.uniform(380, 560)
        s = rnd.uniform(0.8, 1.25)
        blobs = [(circle(x + dx * s, y + dy * s, r * s), "cloud") for dx, dy, r in
                 ((-60, 10, 42), (-10, -18, 58), (50, 0, 46), (95, 18, 30), (-100, 22, 28))]
        blobs.append((rrect(x - 128 * s, y + 10 * s, 250 * s, 42 * s, 21 * s), "cloud"))
        sc.outlined(blobs, 6)
    return sc


def hills():
    """Ground: far plum hills, near teal turf with an ink edge. 1920x1080, transparent above."""
    sc = Scene(1920, 1080)
    far = [(x, 840 - 70 * math.sin(x / 1920 * math.tau * 2.0 + 0.6) - 30 * math.sin(x / 1920 * math.tau * 5)) for x in range(0, 1921, 24)]
    sc.outlined([(far + [(1920, 1080), (0, 1080)], "topsoil")], 6)
    near = [(x, 930 - 36 * math.sin(x / 1920 * math.tau * 1.5 + 2.0)) for x in range(-24, 1945, 24)]
    sc.outlined([(near + [(1944, 1090), (-24, 1090)], "grass")], 7)
    rnd = random.Random(5)
    for _ in range(18):
        x = rnd.uniform(30, 1890)
        y = 930 - 36 * math.sin(x / 1920 * math.tau * 1.5 + 2.0) + rnd.uniform(40, 120)
        sc.line([(x - 10, y), (x - 4, y - 14)], "ink", 5)
        sc.line([(x + 6, y), (x + 10, y - 12)], "ink", 5)
    return sc


def floater(kind):
    """Small bobbing shapes for the background (96x96)."""
    sc = Scene(96, 96)
    if kind == 0:
        sc.outlined([(star(48, 50, 40, 18, 5), "jeff_yellow")], 5)
    elif kind == 1:
        sc.outlined([(circle(48, 48, 34), "comb")], 5, details=[(circle(36, 36, 8), "cloud")])
    elif kind == 2:
        sc.outlined([([(48, 10), (86, 80), (10, 80)], "magma")], 5)
    else:
        jar(sc, 48, 56, 66, lid_dx=0, lid_dy=0, ow=4)
    return sc


def glow_ring():
    """9-patch highlight ring (256x256, margins 96). The card edge sits 64 px in from the sides."""
    from PIL import Image, ImageDraw, ImageFilter
    from pal import rgb
    S = 4
    n = 256 * S
    inset, r = 64 * S, 40 * S
    glow = Image.new("L", (n, n), 0)
    ImageDraw.Draw(glow).rounded_rectangle((inset - 30 * S, inset - 30 * S, n - inset + 30 * S, n - inset + 30 * S), r + 30 * S, fill=170)
    glow = glow.filter(ImageFilter.GaussianBlur(16 * S))
    ring = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(ring)
    d.rounded_rectangle((inset - 22 * S, inset - 22 * S, n - inset + 22 * S, n - inset + 22 * S), r + 22 * S, fill=255)
    d.rounded_rectangle((inset - 2 * S, inset - 2 * S, n - inset + 2 * S, n - inset + 2 * S), r + 2 * S, fill=0)
    hole = Image.new("L", (n, n), 0)
    ImageDraw.Draw(hole).rounded_rectangle((inset, inset, n - inset, n - inset), r, fill=255)
    from PIL import ImageChops
    glow = ImageChops.subtract(glow, hole)
    alpha = ImageChops.lighter(glow, ring)
    out = Image.new("RGBA", (n, n), rgb("magma") + (0,))
    # ink hairline on both sides of the ring so it reads on light and dark art
    ink = Image.new("L", (n, n), 0)
    di = ImageDraw.Draw(ink)
    di.rounded_rectangle((inset - 26 * S, inset - 26 * S, n - inset + 26 * S, n - inset + 26 * S), r + 26 * S, fill=255)
    di.rounded_rectangle((inset - 20 * S, inset - 20 * S, n - inset + 20 * S, n - inset + 20 * S), r + 20 * S, fill=0)
    col = Image.new("RGBA", (n, n), rgb("magma") + (255,))
    col.putalpha(alpha)
    inkl = Image.new("RGBA", (n, n), rgb("ink") + (255,))
    inkl.putalpha(ImageChops.multiply(ink, ring.point(lambda v: 255)))
    out.alpha_composite(col)
    out.alpha_composite(inkl)
    return out.resize((256, 256), Image.Resampling.BOX)
