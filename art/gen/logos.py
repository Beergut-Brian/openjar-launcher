"""The jar icon and three "Open Jar Games" logo options (1200x600 design space)."""
import math

from letters import draw_word, width
from vec import Scene, circle, rrect, star, xform


def jar(sc, cx, cy, h, lid_dx=0.0, lid_dy=0.0, lid_rot=0.0, glass="sky1", lid="magma", band="comb",
        emblem="jeff_yellow", with_lid=True, ow=None):
    """Glass jar, body centred on (cx, cy), body+neck height ~h. Lid can be offset/rotated (popped)."""
    ow = ow if ow is not None else 0.045 * h

    def U(pts):
        return xform(pts, tx=cx, ty=cy, s=h)

    body = U(rrect(-0.44, -0.30, 0.88, 0.80, 0.26))
    neck = U(rrect(-0.31, -0.44, 0.62, 0.20, 0.05))
    rim = U(rrect(-0.36, -0.52, 0.72, 0.12, 0.05))
    band_p = U(rrect(-0.435, -0.02, 0.87, 0.24, 0.03))
    shine = U(rrect(-0.35, -0.22, 0.075, 0.30, 0.037))
    shine2 = U(circle(-0.312, 0.30, 0.04, 20))
    em = U(star(0, 0.10, 0.10, 0.045))
    sc.outlined([(body, glass), (neck, glass), (rim, "cloud")], ow,
                details=[(band_p, band), (shine, "cloud"), (shine2, "cloud")])
    sc.outlined([(em, emblem)], ow * 0.45)
    if with_lid:
        lid_pts = rrect(-0.40, -0.70, 0.80, 0.20, 0.07)
        ridges = [[(x, -0.665), (x, -0.535)] for x in (-0.24, -0.08, 0.08, 0.24)]
        o = (0.0, -0.60)
        lid_pts = xform(lid_pts, rot=lid_rot, ox=o[0], oy=o[1], tx=lid_dx, ty=lid_dy)
        ridges = [xform(r, rot=lid_rot, ox=o[0], oy=o[1], tx=lid_dx, ty=lid_dy) for r in ridges]
        sc.outlined([(U(lid_pts), lid)], ow,
                    details=[("line", U(r), "ink", ow * 0.7) for r in ridges])


def sparkle(sc, x, y, r, fill="jeff_yellow", ow=6):
    sc.outlined([(star(x, y, r, r * 0.42, 4, -90), fill)], ow)


def pop_lines(sc, cx, cy, r0, r1, angles, w):
    for a in angles:
        t = math.radians(a)
        sc.line([(cx + r0 * math.cos(t), cy + r0 * math.sin(t)), (cx + r1 * math.cos(t), cy + r1 * math.sin(t))], "ink", w)


def centred_word(sc, text, cx, y, size, fill, **kw):
    w = width(text, size, kw.get("tracking", 0.0))
    return draw_word(sc, text, cx - w / 2, y, size, fill, **kw)


# ---------- option A: horizontal lockup, popping jar left, two lines of words right ----------
def option_a():
    sc = Scene(1200, 600)
    pop_lines(sc, 225, 165, 92, 128, [-160, -135, -110, -85], 11)
    jar(sc, 215, 380, 340, lid_dx=-0.10, lid_dy=-0.22, lid_rot=-22)
    sparkle(sc, 70, 210, 30, "jeff_yellow")
    sparkle(sc, 375, 130, 24, "comb")
    sparkle(sc, 400, 250, 17, "cloud")
    size = 104
    x0 = 455
    draw_word(sc, "OPEN", x0, 282, size, "cloud", rot=(-5, 3, -3, 4), dy=(0, -6, 4, -3))
    draw_word(sc, "JAR", x0 + width("OPEN ", size), 282, size, "magma", rot=(4, -4, 5), dy=(-5, 3, -2))
    draw_word(sc, "GAMES", x0 + 40, 462, size, "sky1", rot=(-6, 4, -3, 5, -4), dy=(3, -4, 2, -5, 4))
    return sc


# ---------- option B: the jar is the badge, words inside it ----------
def option_b():
    sc = Scene(1200, 600)
    ow = 16
    body = rrect(110, 175, 980, 405, 130)
    neck = rrect(230, 120, 740, 80, 20)
    rim = rrect(200, 96, 800, 50, 22)
    lid = rrect(180, 18, 840, 92, 32)
    shine = rrect(146, 240, 30, 110, 15)
    sc.outlined([(body, "sky2"), (neck, "sky2"), (rim, "cloud")], ow, details=[(shine, "cloud"), (circle(161, 372, 14, 20), "cloud")])
    sc.outlined([(lid, "magma")], ow, details=[("line", [(x, 38), (x, 90)], "ink", 11) for x in range(300, 1000, 100)])
    centred_word(sc, "OPEN JAR", 600, 345, 120, ["jeff_yellow"] * 4 + ["cloud"] * 3, rot=(-4, 3, -3, 4, 3, -4, 4), dy=(0, -5, 3, -4, -3, 4, -2))
    # ribbon across the lower body
    rb = [(160, 395), (1040, 395), (1060, 470), (1040, 545), (160, 545), (140, 470)]
    sc.outlined([(rb, "comb")], ow)
    centred_word(sc, "GAMES", 600, 515, 92, "cloud", rot=(3, -3, 4, -4, 3), dy=(-3, 3, -2, 3, -3), shadow="sky5")
    sparkle(sc, 1080, 150, 36, "jeff_yellow")
    sparkle(sc, 110, 110, 26, "cloud")
    return sc


# ---------- option C: arched words over a popping jar with a banner, starburst behind ----------
def option_c():
    sc = Scene(1200, 600)
    rays = []
    cx, cy = 600, 420
    for i in range(16):
        a0 = math.radians(i * 22.5 - 5)
        a1 = math.radians(i * 22.5 + 5)
        if i % 2 == 0:
            rays.append([(cx, cy), (cx + 700 * math.cos(a0), cy + 700 * math.sin(a0)), (cx + 700 * math.cos(a1), cy + 700 * math.sin(a1))])
    burst = Scene(1200, 600)
    for r in rays:
        burst.poly(r, fill="sky4")
    sc.poly(circle(cx, cy, 300, 96), fill="sky4", alpha=0.0)
    for r in rays:
        clip = [(max(0, min(1200, x)), max(0, min(600, y))) for x, y in r]
        sc.poly(clip, fill="sky4", alpha=0.55)
    sc.outlined([(circle(cx, cy + 10, 160, 96), "sky3")], 14)
    pop_lines(sc, 640, 305, 70, 110, [-120, -95, -70, -45], 11)
    jar(sc, cx, 440, 250, lid_dx=0.62, lid_dy=-0.12, lid_rot=38, glass="sky1")
    text = "OPEN JAR"
    size = 108
    w = width(text, size)
    n = 7
    rot = [((i - 3) / 3) * 12 for i in range(n)]
    dy = [40 * ((i - 3) / 3) ** 2 for i in range(n)]
    draw_word(sc, text, 600 - w / 2, 160, size, ["cloud"] * 4 + ["magma"] * 3, rot=rot, dy=dy)
    rb = [(300, 478), (900, 478), (960, 440), (940, 520), (960, 600 - 20), (900, 565), (300, 565), (240, 580), (260, 520), (240, 440)]
    rb = [(300, 470), (900, 470), (900, 570), (300, 570)]
    tailL = [(300, 488), (225, 488), (255, 525), (225, 562), (300, 562)]
    tailR = [(900, 488), (975, 488), (945, 525), (975, 562), (900, 562)]
    sc.outlined([(tailL, "topsoil"), (tailR, "topsoil")], 13)
    sc.outlined([(rb, "comb")], 13)
    centred_word(sc, "GAMES", 600, 550, 66, "cloud", rot=(-3, 3, -2, 3, -3), dy=(2, -3, 2, -3, 2), shadow="sky5")
    sparkle(sc, 250, 330, 30, "jeff_yellow")
    sparkle(sc, 960, 330, 30, "jeff_yellow")
    sparkle(sc, 1080, 200, 20, "cloud")
    sparkle(sc, 120, 210, 20, "cloud")
    return sc


OPTIONS = {"a": option_a, "b": option_b, "c": option_c}
