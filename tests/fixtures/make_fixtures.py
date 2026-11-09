#!/usr/bin/env python3
"""Builds the hub fixtures: tests/fixtures/hub_<n>/<game>/{openjar.json,game.sh,grid.png}.
Posters are original flat-shape art drawn here with Pillow. Run from the repo root."""
import json, math, os, shutil
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 600, 900
# slug, top colour, bottom colour, motif, has grid art, dev build
GAMES = [
    ("ball-bash", "#35B6FF", "#1466D6", "ball", True, False),
    ("bubble-pop", "#FF8AD0", "#B93BD9", "bubbles", True, False),
    ("comet-kick", "#3A2A8C", "#120A3C", "comet", True, False),
    ("dino-dash", "#FFD23F", "#FF8A1F", "dino", True, False),
    ("jelly-jump", "#5EF0C0", "#12A38F", "jelly", True, False),
    ("moon-golf", "#8C7BFF", "#3A2FA8", "moon", True, False),
    ("no-art-yet", "#888888", "#444444", "", False, False),
    ("smash-party", "#FF6A4D", "#D6204A", "star", True, False),
]
SETS = {0: [], 1: [0], 2: [0, 7], 8: list(range(8))}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def star(d, cx, cy, r, fill, n=5, inner=0.48, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill)


def poster(top, bottom, motif):
    S = 2
    img = Image.new("RGB", (W * S, H * S))
    d = ImageDraw.Draw(img)
    t, b = rgb(top), rgb(bottom)
    for y in range(H * S):
        d.line([(0, y), (W * S, y)], fill=lerp(t, b, y / (H * S)))
    c = lambda x, y, r, f: d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=f)
    white, ink = (255, 255, 255), (30, 24, 60)
    for i in range(7):   # soft sunburst so every poster has depth
        c(300, 470, 430 - i * 55, lerp(b, t, 0.25 + i * 0.1))
    if motif == "ball":
        c(300, 470, 210, white)
        for a in range(0, 360, 72):
            c(300 + 120 * math.cos(math.radians(a)), 470 + 120 * math.sin(math.radians(a)), 52, (255, 210, 63))
        c(300, 470, 60, (228, 80, 120))
        d.ellipse([110 * S, 730 * S, 490 * S, 790 * S], fill=lerp(b, (0, 0, 0), 0.35))
    elif motif == "bubbles":
        for x, y, r in [(190, 330, 120), (400, 470, 150), (220, 640, 100), (430, 220, 70), (120, 500, 50)]:
            c(x, y, r, (255, 240, 255)); c(x, y, r - 14, lerp(t, white, 0.45)); c(x - r * 0.35, y - r * 0.35, r * 0.2, white)
    elif motif == "comet":
        for i in range(12):
            c(120 + i * 26, 700 - i * 30, 30 + i * 8, lerp((255, 120, 60), (255, 230, 90), i / 11))
        c(430, 345, 130, (255, 250, 200)); c(395, 310, 26, ink); c(470, 310, 26, ink)
        for x, y in [(90, 150), (500, 110), (520, 640), (150, 420), (330, 820)]:
            star(d, x * S, y * S, 26 * S, white, 4, 0.35)
    elif motif == "dino":
        g = (60, 190, 110)
        c(300, 560, 190, g); c(420, 360, 130, g); c(165, 700, 70, g); c(400, 740, 70, g)
        for i in range(5):
            star(d, (190 + i * 50) * S, (400 - i * 45 + 60) * S, 46 * S, (255, 120, 60), 3, 0.5, -60)
        c(455, 330, 30, white); c(462, 334, 15, ink)
        d.pieslice([360 * S, 340 * S, 520 * S, 470 * S], 10, 150, fill=(255, 250, 240))
    elif motif == "jelly":
        d.pieslice([120 * S, 250 * S, 480 * S, 730 * S], 180, 360, fill=(255, 110, 170))
        d.rounded_rectangle([120 * S, 480 * S, 480 * S, 640 * S], 60 * S, fill=(255, 110, 170))
        for x in (165, 255, 345, 435):
            c(x, 640, 45, (255, 110, 170))
        c(240, 470, 34, white); c(360, 470, 34, white); c(246, 476, 17, ink); c(366, 476, 17, ink)
        d.arc([255 * S, 500 * S, 345 * S, 570 * S], 20, 160, fill=ink, width=10 * S)
    elif motif == "moon":
        c(300, 400, 200, (255, 244, 200)); c(240, 350, 46, (240, 215, 150)); c(370, 470, 60, (240, 215, 150)); c(330, 300, 24, (240, 215, 150))
        d.rectangle([292 * S, 150 * S, 302 * S, 330 * S], fill=white)
        d.polygon([(302 * S, 150 * S), (400 * S, 190 * S), (302 * S, 230 * S)], fill=(228, 57, 60))
        c(150, 720, 46, white)
        for x, y in [(80, 120), (520, 160), (500, 700), (110, 560)]:
            star(d, x * S, y * S, 22 * S, white, 4, 0.35)
    elif motif == "star":
        star(d, 300 * S, 450 * S, 250 * S, (255, 222, 70))
        c(245, 430, 30, ink); c(355, 430, 30, ink); c(253, 422, 10, white); c(363, 422, 10, white)
        d.chord([240 * S, 450 * S, 360 * S, 560 * S], 0, 180, fill=ink)
        for x, y, r in [(110, 180, 34), (500, 220, 26), (480, 730, 40), (120, 700, 22)]:
            c(x, y, r, white)
    return img.resize((W, H), Image.LANCZOS)


for n, idxs in SETS.items():
    root = os.path.join(HERE, "hub_%d" % n)
    shutil.rmtree(root, ignore_errors=True)
    os.makedirs(root)
    open(os.path.join(root, ".gitkeep"), "w").close()
    for i in idxs:
        slug, top, bottom, motif, has_grid, dev = GAMES[i]
        d = os.path.join(root, slug)
        os.makedirs(os.path.join(d, "store"))
        man = {"slug": slug, "name": slug.replace("-", " ").title(), "version": "v0.0.1",
               "binary": "game.sh", "dev": dev}
        if has_grid:
            man["grid"] = "store/grid.png"
            poster(top, bottom, motif).save(os.path.join(d, "store", "grid.png"), optimize=True)
        else:
            open(os.path.join(d, "store", ".gitkeep"), "w").close()
        json.dump(man, open(os.path.join(d, "openjar.json"), "w"), indent=2)
        sh = os.path.join(d, "game.sh")
        open(sh, "w").write("#!/bin/sh\n# fixture game: exits at once\necho \"%s $@\"\nsleep 0.3\n" % slug)
        os.chmod(sh, 0o755)
print("fixtures written to", HERE)
