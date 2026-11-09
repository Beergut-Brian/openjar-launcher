"""Pillow drawing for the palette sheets: the mock game card, the swatch sheet and
the side-by-side compare sheet. Everything is drawn supersampled and scaled down."""
import math
import os

from PIL import Image, ImageDraw, ImageFont

import colormath as cm

FONT_DIR = "/usr/share/fonts/truetype/lato"


def font(size, weight="Black"):
    try:
        return ImageFont.truetype(os.path.join(FONT_DIR, f"Lato-{weight}.ttf"), size)
    except OSError:
        return ImageFont.load_default(size)


class Pen:
    """Sticker-style drawing: every shape gets an ink outline of width w drawn outside it.
    Coordinates are in output pixels; S is the supersample factor."""

    def __init__(self, img, S, ink, w):
        self.d = ImageDraw.Draw(img)
        self.S, self.ink, self.w = S, ink, w

    def _p(self, pts):
        return [(x * self.S, y * self.S) for x, y in pts]

    def _b(self, box, grow=0):
        x0, y0, x1, y1 = box
        return [(x0 - grow) * self.S, (y0 - grow) * self.S, (x1 + grow) * self.S, (y1 + grow) * self.S]

    def ellipse(self, box, fill, w=None, outline=True):
        w = self.w if w is None else w
        if outline:
            self.d.ellipse(self._b(box, w), fill=self.ink)
        self.d.ellipse(self._b(box), fill=fill)

    def circle(self, c, r, fill, w=None, outline=True):
        self.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill, w, outline)

    def rrect(self, box, r, fill, w=None, outline=True):
        w = self.w if w is None else w
        if outline:
            self.d.rounded_rectangle(self._b(box, w), radius=(r + w) * self.S, fill=self.ink)
        self.d.rounded_rectangle(self._b(box), radius=r * self.S, fill=fill)

    def dark_rrect(self, box, r, fill, rim, rw=3):
        """Near-black fixed colours: ink outline, then a rim-light line inside it."""
        self.rrect(box, r, rim)
        x0, y0, x1, y1 = box
        self.d.rounded_rectangle(self._b((x0 + rw, y0 + rw, x1 - rw, y1 - rw)),
                                 radius=max(1, r - rw) * self.S, fill=fill)

    def poly(self, pts, fill, w=None, outline=True):
        w = self.w if w is None else w
        P = self._p(pts)
        if outline:
            self.d.line(P + [P[0]], fill=self.ink, width=int(2 * w * self.S), joint="curve")
            for x, y in P:
                self.d.ellipse([x - w * self.S, y - w * self.S, x + w * self.S, y + w * self.S], fill=self.ink)
            self.d.polygon(P, fill=self.ink)
        self.d.polygon(P, fill=fill)

    def limb(self, a, b, width, fill, w=None, rim=None, rw=3):
        w = self.w if w is None else w
        for col, ww in ((self.ink, width / 2 + w), (rim, width / 2), (fill, width / 2 - (rw if rim else 0))):
            if col is None:
                continue
            self.d.line(self._p([a, b]), fill=col, width=int(2 * ww * self.S))
            for x, y in (a, b):
                self.d.ellipse(self._b((x - ww, y - ww, x + ww, y + ww)), fill=col)

    def line(self, pts, width, fill=None, curve=True):
        P = self._p(pts)
        fill = self.ink if fill is None else fill
        self.d.line(P, fill=fill, width=int(width * self.S), joint="curve" if curve else None)
        r = width / 2 * self.S
        for x, y in (P[0], P[-1]):
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def arc(self, box, a0, a1, width, fill=None):
        self.d.arc(self._b(box), a0, a1, fill=self.ink if fill is None else fill, width=int(width * self.S))


def wave(y, amp, freq, phase, x0=-20, x1=620, step=10):
    return [(x, y + amp * math.sin(x / 600 * 2 * math.pi * freq + phase)) for x in range(x0, x1 + 1, step)]


def star(c, r_out, r_in, n=4, rot=0.0):
    pts = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n - math.pi / 2
        pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    return pts


def wing(pen, base, ang, length, width, fill, tip):
    """A teardrop wing from base along ang, with three feather tips in the accent colour."""
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    for k in (-1, 0, 1):
        a = ang + k * 0.26
        ex, ey = base[0] + (length + 4) * math.cos(a), base[1] + (length + 4) * math.sin(a)
        pen.limb((base[0] + ux * length * 0.7, base[1] + uy * length * 0.7), (ex, ey), 22, tip, w=5)
    pts = []
    for i in range(24):
        t = i / 23 * math.pi
        along = length * 0.5 * (1 - math.cos(t))
        half = width * math.sin(t) * (1 - 0.35 * (1 - math.cos(t)) / 2)
        pts.append((base[0] + ux * along + nx * half, base[1] + uy * along + ny * half))
    for i in range(23, -1, -1):
        t = i / 23 * math.pi
        along = length * 0.5 * (1 - math.cos(t))
        half = width * math.sin(t) * (1 - 0.35 * (1 - math.cos(t)) / 2)
        pts.append((base[0] + ux * along - nx * half, base[1] + uy * along - ny * half))
    pen.poly(pts, fill, w=6)


def cloud_puff(pen, cx, cy, s, fill):
    blobs = [(-0.9, 0.25, 0.45), (-0.35, -0.15, 0.6), (0.35, -0.05, 0.55), (0.9, 0.3, 0.42), (0.0, 0.35, 0.5)]
    for dx, dy, r in blobs:  # ink pass first so the puff reads as one outlined shape
        pen.circle((cx + dx * s, cy + dy * s), r * s + pen.w, pen.ink, outline=False)
    for dx, dy, r in blobs:
        pen.circle((cx + dx * s, cy + dy * s), r * s, fill, outline=False)


def jar_icon(pen, x, y, s, glass, lid, shine):
    pen.rrect((x, y + 0.22 * s, x + s, y + 1.2 * s), 0.22 * s, glass, w=0.08 * s)
    pen.rrect((x + 0.12 * s, y, x + 0.88 * s, y + 0.26 * s), 0.08 * s, lid, w=0.08 * s)
    pen.rrect((x + 0.16 * s, y + 0.42 * s, x + 0.32 * s, y + 0.95 * s), 0.07 * s, shine, outline=False)


def draw_card(p, S=4):
    C = {k: hx for k, _, hx, _, _ in p["colours"]}
    W, H = 600, 900
    img = Image.new("RGB", (W * S, H * S), C["sky5"])
    pen = Pen(img, S, C["ink"], 7)
    face, comb, beak = C[p["face"]], C[p["comb"]], C[p["beak"]]
    green, red, yellow = C["p1_green"], C["p2_red"], C["jeff_yellow"]
    jeans, boots, hat, shirt = C["jeans_blue"], C["boots_brown"], C["hat_black"], C["shirt_black"]
    rim, cloud = C["stone"], C["cloud"]

    # Sky ramp: concentric bands around a centre far below, so the tiers curve like a planet.
    cx, cy = 300, 1900
    for key, top in (("sky4", 165), ("sky3", 300), ("sky2", 420), ("sky1", 530)):
        r = cy - top
        pen.d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=C[key])

    # Space: stars and sparkle dots
    for (x, y, r) in ((150, 40, 13), (530, 60, 16), (300, 105, 10), (95, 128, 8), (470, 135, 9)):
        pen.poly(star((x, y), r, r * 0.38), C["magma"], w=3)
    for (x, y) in ((220, 30), (390, 48), (575, 120), (30, 150), (250, 150)):
        pen.circle((x, y), 4, cloud, outline=False)

    # Clouds in the cloud deck
    cloud_puff(pen, 105, 355, 60, cloud)
    cloud_puff(pen, 515, 392, 48, cloud)

    # Ball trail from P1's foot up into the stratosphere
    trail = [(318, 566), (326, 500), (332, 436), (336, 374), (338, 316)]
    for i, (x, y) in enumerate(trail):
        pen.circle((x, y), 5 + i * 1.8, cloud, w=4)
    bx, by = 340, 210
    for ox, oy in ((-34, 56), (-6, 70), (-56, 30)):
        pen.line([(bx + ox, by + oy), (bx + ox - 18, by + oy + 42)], 6)
    pen.circle((bx, by), 46, cloud)
    pen.poly(star((bx, by), 24, 12, n=5, rot=0.3), comb, w=4)
    for a in (0.3, 1.55, 2.8, 4.05, 5.3):
        pen.circle((bx + 36 * math.cos(a), by + 36 * math.sin(a)), 7, comb, w=3)

    # Ground: grass, then a cut-away of the soil rings
    strata = [("grass", 648, 9, 1.0), ("topsoil", 712, 6, 2.0), ("clay", 768, 6, 2.6),
              ("stone", 822, 5, 3.1), ("magma", 866, 5, 3.7)]
    for i, (key, y, amp, fr) in enumerate(strata):
        top = wave(y, amp, fr, i * 1.3)
        pts = top + [(620, 940), (-20, 940)]
        pen.d.polygon(pen._p(pts), fill=C[key])
        pen.line(top, 7)
    for (x, y, r) in ((70, 842, 9), (210, 848, 7), (360, 838, 10), (520, 846, 8)):
        pen.ellipse((x - r * 1.5, y - r, x + r * 1.5, y + r), cloud, w=3)
    for (x, y, r) in ((130, 886, 7), (300, 892, 9), (460, 884, 6)):
        pen.circle((x, y), r, cloud, w=3)
    # a little worm in the topsoil, original and simple
    for i in range(4):
        pen.circle((440 + i * 20, 742 + 5 * math.sin(i * 1.4)), 12, comb, w=4)
    pen.circle((506, 738), 4, C["ink"], outline=False)

    # ---- P1: round chicken-hooded figure, green accents, kicking ----
    pen.ellipse((148, 646, 206, 678), face)                      # standing foot
    pen.limb((182, 585), (180, 652), 24, jeans)                   # standing leg
    pen.limb((210, 590), (282, 600), 24, jeans)                   # kicking leg
    pen.ellipse((270, 580, 322, 614), face)                       # kicking foot
    for (x0, y0, x1, y1) in ((175, 612, 188, 612), (175, 632, 188, 632), (238, 588, 238, 604), (258, 590, 258, 606)):
        pen.line([(x0, y0), (x1, y1)], 4, green)                  # green stitching
    wing(pen, (128, 520), math.radians(115), 78, 22, yellow, green)   # back wing, hanging
    pen.ellipse((112, 455, 262, 612), yellow)                     # puffy body
    for (x, y, r) in ((158, 362, 18), (186, 348, 21), (214, 362, 18)):
        pen.circle((x, y), r, comb)                               # comb
    pen.ellipse((118, 364, 254, 500), yellow)                     # hood
    pen.arc((126, 372, 246, 492), 205, 335, 16, green)            # headband
    pen.poly([(156, 486), (232, 482), (270, 494), (222, 514), (174, 512)], beak, w=6)   # lower beak
    pen.ellipse((146, 422, 238, 500), face)                       # face in the beak opening
    for ex in (174, 210):
        pen.ellipse((ex - 12, 440, ex + 12, 464), cloud, w=4)
        pen.circle((ex + 2, 456), 6, C["ink"], outline=False)
        pen.d.rectangle(pen._b((ex - 14, 436, ex + 14, 450)), fill=face)
        pen.line([(ex - 14, 450), (ex + 14, 450)], 5)             # half-lidded happy eyes
    pen.d.chord(pen._b((166, 462, 222, 492)), 0, 180, fill=C["ink"])
    pen.d.rectangle(pen._b((183, 472, 192, 480)), fill=cloud)
    pen.d.rectangle(pen._b((195, 472, 204, 480)), fill=cloud)    # two-tooth grin
    pen.poly([(142, 440), (164, 416), (214, 406), (258, 420), (304, 450), (240, 450), (150, 448)], beak, w=6)  # upper beak
    pen.ellipse((236, 422, 248, 430), C["ink"], outline=False)  # nostril
    wing(pen, (248, 500), math.radians(-58), 74, 22, yellow, green)   # raised wing, flapping

    # ---- P2: flat-hat figure, red accents, cheering ----
    ox = 34
    for x in (414 + ox, 452 + ox):
        pen.limb((x + 10, 560), (x + 10, 628), 24, jeans)
    for x in (414 + ox, 452 + ox):
        pen.poly([(x, 622), (x + 22, 622), (x + 24, 656), (x + 30, 658), (x + 30, 676),
                  (x - 22, 676), (x - 22, 662), (x - 4, 654)], boots, w=6)
        pen.line([(x + 4, 632), (x + 18, 648)], 3, red)           # boot stitching
    pen.limb((404 + ox, 488), (372 + ox, 416), 24, shirt, rim=rim)    # arms up
    pen.limb((486 + ox, 488), (522 + ox, 416), 24, shirt, rim=rim)
    pen.circle((368 + ox, 408), 15, face)
    pen.circle((526 + ox, 408), 15, face)
    pen.dark_rrect((396 + ox, 470, 494 + ox, 574), 20, shirt, rim)    # boxy torso
    sp = [(445 + ox + (3 + t * 1.3) * math.cos(t / 3), 522 + (3 + t * 1.3) * math.sin(t / 3)) for t in range(0, 29)]
    pen.line(sp, 9, red)                                          # tie-dye swirl
    pen.line([(x + 6, y - 6) for x, y in sp[6:24]], 3, cloud)
    for (x, y) in ((414 + ox, 492), (478 + ox, 556), (476 + ox, 490), (416 + ox, 556)):
        pen.circle((x, y), 5, red, outline=False)
    pen.ellipse((404 + ox, 392, 488 + ox, 476), face)             # head
    pen.line([(420 + ox, 420), (442 + ox, 426)], 9)               # thick brows
    pen.line([(452 + ox, 426), (474 + ox, 420)], 9)
    pen.line([(424 + ox, 438), (438 + ox, 438)], 5)               # squint
    pen.line([(456 + ox, 438), (470 + ox, 438)], 5)
    pen.line([(430 + ox, 458), (450 + ox, 460), (464 + ox, 454)], 6)  # determined mouth
    pen.dark_rrect((402 + ox, 328, 490 + ox, 400), 14, hat, rim)  # flat-top crown
    pen.d.rectangle(pen._b((405 + ox, 388, 487 + ox, 397)), fill=red)  # panel edge
    dino = [(424, 378), (432, 366), (446, 362), (452, 352), (460, 348), (472, 352), (472, 360),
            (462, 362), (458, 370), (456, 380), (450, 380), (448, 374), (440, 374), (438, 380), (432, 380)]
    pen.poly([(x + ox, y) for x, y in dino], yellow, w=3)         # hat emblem: a small plain dino
    pen.circle((463 + ox, 354), 2, C["ink"], outline=False)
    pen.poly([(x + ox, y) for x, y in ((346, 404), (366, 390), (424, 392), (424, 406), (362, 414))], red, w=6)  # brim

    # tiny jar mark, top left
    jar_icon(pen, 24, 22, 44, cloud, comb, C["sky2"])

    return img.resize((W, H), Image.LANCZOS)


def text_on(bg, ink, light):
    return ink if cm.contrast(bg, ink) >= cm.contrast(bg, light) else light


def wrap(d, text, f, width):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if d.textlength(t, font=f) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return lines


def draw_swatches(p, rows):
    C = {k: (name, hx, grp, role) for k, name, hx, grp, role in p["colours"]}
    ink, cloud = C["ink"][1], C["cloud"][1]
    bg = "#F4F1EC"
    img = Image.new("RGB", (1920, 1080), bg)
    d = ImageDraw.Draw(img)
    d.text((60, 34), f"{p['letter']}  {p['title']}", font=font(64), fill=ink)
    d.text((60, 108), p["mood"], font=font(28, "Bold"), fill="#4A4652")

    # Sky ramp as stacked bands, space on top
    sx, sy, sw, sh = 60, 170, 440, 860
    skies = [k for k, *_ in p["colours"] if C[k][2] == "sky"]
    bh = sh / len(skies)
    for i, k in enumerate(reversed(skies)):
        y0 = sy + i * bh
        d.rectangle([sx, y0, sx + sw, y0 + bh], fill=C[k][1])
        tc = text_on(C[k][1], ink, cloud)
        tier = len(skies) - i
        d.text((sx + 24, y0 + 22), f"{tier}  {C[k][0]}", font=font(34), fill=tc)
        d.text((sx + 24, y0 + 66), f"{C[k][1]}   {C[k][3].split(': ')[-1]}", font=font(24, "Bold"), fill=tc)
    for i, k in enumerate(list(reversed(skies))[:-1]):
        y0 = sy + i * bh
        dE = cm.de(C[k][1], C[skies[len(skies) - 2 - i]][1])
        t = f"step ΔE {dE:.1f}"
        tw = d.textlength(t, font=font(22, "Bold"))
        d.rounded_rectangle([sx + sw - tw - 34, y0 + bh - 18, sx + sw - 10, y0 + bh + 18], 10, fill=bg, outline=ink, width=3)
        d.text((sx + sw - tw - 22, y0 + bh - 13), t, font=font(22, "Bold"), fill=ink)
    # players on the sky, to show they pop
    for j, (pk, k) in enumerate((("p1_green", 0), ("p2_red", 1))):
        for i in range(len(skies)):
            cxx, cyy = sx + sw - 120 + j * 48, sy + i * bh + bh / 2 + 6
            d.ellipse([cxx - 17, cyy - 17, cxx + 17, cyy + 17], fill=C[pk][1], outline=ink, width=5)
    d.rectangle([sx, sy, sx + sw, sy + sh], outline=ink, width=6)

    def chip(x, y, k, w=190, h=120):
        name, hx, grp, role = C[k]
        d.rounded_rectangle([x, y, x + w, y + h], 18, fill=hx, outline=ink, width=6)
        size = 25
        while d.textlength(name, font=font(size)) > w and size > 14:
            size -= 1
        d.text((x, y + h + 10), name, font=font(size), fill=ink)
        d.text((x, y + h + 40), hx, font=font(21, "Bold"), fill="#4A4652")
        for li, line in enumerate(wrap(d, role, font(16, "Regular"), w)[:3]):
            d.text((x, y + h + 66 + li * 19), line, font=font(16, "Regular"), fill="#4A4652")

    gx = 560
    keys = lambda g: [k for k, *_ in p["colours"] if C[k][2] == g]
    groups = [("Outline / ink", keys("ink")), ("Neutrals / UI", keys("neutral")), ("Accents / FX", keys("accent"))]
    x = gx
    for title, ks in groups:
        d.text((x, 170), title.upper(), font=font(22), fill="#7A7480")
        for k in ks:
            chip(x, 204, k)
            x += 214
        x += 30
    d.text((gx, 470), "GROUND / NATURE", font=font(22), fill="#7A7480")
    for i, k in enumerate(keys("ground")):
        chip(gx + i * 214, 504, k)

    # Worm planet preview: rings, surface outward, with a green and a red worm-dot on top
    px, py = 1530, 620
    rings = p["rings"]
    d.text((px - 250, 470), "WORM RINGS", font=font(22), fill="#7A7480")
    rad = [150, 118, 86, 54]
    d.ellipse([px - rad[0] - 6, py - rad[0] - 6, px + rad[0] + 6, py + rad[0] + 6], fill=ink)
    for r, k in zip(rad, rings):
        d.ellipse([px - r, py - r, px + r, py + r], fill=C[k][1], outline=ink, width=5)
    for a, pk in ((-2.2, "p1_green"), (-0.9, "p2_red"), (0.6, "p1_green"), (2.4, "p2_red")):
        for r in (134, 102, 70):
            cxx, cyy = px + r * math.cos(a + r / 90), py + r * math.sin(a + r / 90)
            d.ellipse([cxx - 12, cyy - 12, cxx + 12, cyy + 12], fill=C[pk][1], outline=ink, width=4)
    for i, k in enumerate(rings):
        d.rounded_rectangle([1720, 480 + i * 70, 1770, 530 + i * 70], 10, fill=C[k][1], outline=ink, width=4)
        d.text((1782, 490 + i * 70), C[k][0], font=font(20, "Bold"), fill=ink)

    d.text((gx, 790), "FIXED (NOT UP FOR A VOTE)", font=font(22), fill="#7A7480")
    for i, k in enumerate(keys("fixed")):
        chip(gx + i * 186, 824, k, w=166, h=100)

    fails = [r for r in rows if r[0] == p["id"] and not r[5]]
    note = ("All palette checks pass." if not fails else
            "Palette checks pass except: " + "; ".join(f"{r[2]} = {r[3]} (needs {r[4]})" for r in fails))
    for li, line in enumerate(wrap(d, note, font(20, "Bold"), 520)):
        d.text((1360, 36 + li * 26), line, font=font(20, "Bold"), fill="#8A3030" if fails else "#2F7A3A")
    return img


def draw_compare(palettes, cards):
    W, H = 1920, 1080
    bg = "#26232C"
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)
    cw, ch = 566, 849
    gap = (W - 3 * cw) // 4
    for i, (p, card) in enumerate(zip(palettes, cards)):
        C = {k: hx for k, _, hx, _, _ in p["colours"]}
        x, y = gap + i * (cw + gap), 24
        d.rounded_rectangle([x - 8, y - 8, x + cw + 8, y + ch + 8], 22, fill="#0B0A0E")
        mask = Image.new("L", (cw, ch), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, cw, ch], 16, fill=255)
        img.paste(card.resize((cw, ch), Image.LANCZOS), (x, y), mask)
        # corner letter
        bx, by = x + cw - 82, y + ch - 82
        d.ellipse([bx, by, bx + 66, by + 66], fill="#FFFFFF", outline="#0B0A0E", width=6)
        f = font(44)
        tw = d.textlength(p["letter"], font=f)
        d.text((bx + 33 - tw / 2, by + 6), p["letter"], font=f, fill="#0B0A0E")
        # palette strip: two rows of ten
        order = ([k for k, *_ in p["colours"] if k.startswith("sky")] +
                 [k for k, _, _, g, _ in p["colours"] if g in ("ink", "neutral")] +
                 [k for k, _, _, g, _ in p["colours"] if g in ("ground", "accent")] +
                 [k for k, _, _, g, _ in p["colours"] if g == "fixed"])
        n1 = (len(order) + 1) // 2
        sy0 = y + ch + 26
        for row, ks in enumerate((order[:n1], order[n1:])):
            sw = cw / len(ks)
            for j, k in enumerate(ks):
                x0 = x + j * sw
                d.rectangle([x0, sy0 + row * 84, x0 + sw, sy0 + row * 84 + 78], fill=C[k])
            d.rectangle([x, sy0 + row * 84, x + cw, sy0 + row * 84 + 78], outline="#0B0A0E", width=4)
    return img
