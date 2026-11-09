#!/usr/bin/env python3
"""Builds the whole launcher look from the palette named in config.py:

    python3 art/gen/build.py

Writes art/logo/* (SVG + PNG + compare sheet), assets/sprites/launcher/*, assets/sprites/ui/*,
assets/shaders/*.tres (materials), scenes/ui/theme.tres, store/grid.png + hero.png,
regenerates scenes/launcher/{intro,card,profile_picker}.tscn and patches the palette colours in
launcher.tscn / card_row.tscn, then renders the hand-off mock screens into handoff/screens/.
Everything is original, drawn from code; no generative model, no external art.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw

import config
import logos
import sprites as S
from letters import draw_word
from pal import NAME, P, ROOT, godot, rgb
from vec import Scene, circle, rrect, star

SPR = ROOT / "assets" / "sprites" / "launcher"
UI = ROOT / "assets" / "sprites" / "ui"
SHD = ROOT / "assets" / "shaders"
LOGO = ROOT / "art" / "logo"

# Profile faces: two palette accents that are neither player colour.
FACES = {"a": ("magma", "comb", 0), "b": ("comb", "magma", 1)}


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", path.relative_to(ROOT))


def fit(img, w, h):
    return img.resize((w, h), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------- logos
def build_logos():
    renders = {}
    for k, f in logos.OPTIONS.items():
        sc = f()
        (LOGO / f"option_{k}.svg").parent.mkdir(parents=True, exist_ok=True)
        (LOGO / f"option_{k}.svg").write_text(sc.svg(f"Open Jar Games logo, option {k.upper()}"))
        print("wrote", (LOGO / f"option_{k}.svg").relative_to(ROOT))
        img = sc.render()
        save(img, LOGO / f"option_{k}.png")
        renders[k] = (sc, img)
    # option A is the in-game logo for now
    save(renders["a"][0].render(scale=0.7), SPR / "logo.png")
    return renders


def panel(w, h, fill, r=40):
    sc = Scene(w, h)
    sc.outlined([(rrect(8, 8, w - 16, h - 16, r), fill)], 8)
    return sc.render()


def build_compare(renders):
    W, H = 1920, 1080
    out = Image.new("RGBA", (W, H), rgb("ink") + (255,))
    for i, k in enumerate("abc"):
        x0 = i * 640
        img = renders[k][1]
        # 1) on the sky (how it sits in the launcher)
        p = panel(616, 330, "sky3")
        p.alpha_composite(fit(img, 576, 288), (20, 21))
        out.alpha_composite(p, (x0 + 12, 30))
        # 2) on light
        p = panel(616, 330, "cloud")
        p.alpha_composite(fit(img, 576, 288), (20, 21))
        out.alpha_composite(p, (x0 + 12, 380))
        # 3) small: phone-size (240 px wide) and icon-size (120 px wide)
        p = panel(616, 300, "sky4")
        p.alpha_composite(fit(img, 300, 150), (60, 85))
        p.alpha_composite(fit(img, 150, 75), (390, 112))
        p.alpha_composite(fit(img, 90, 45), (500, 210))
        out.alpha_composite(p, (x0 + 12, 740))
        # corner label
        b = Scene(84, 84)
        b.outlined([(circle(42, 42, 34), "magma")], 5)
        from letters import width as tw
        draw_word(b, k.upper(), 42 - tw(k.upper(), 34) / 2, 59, 34, "cloud", shadow=None, shine=False)
        out.alpha_composite(b.render(), (x0 + 22, 748))
    save(out, LOGO / "compare.png")


# ---------------------------------------------------------------- sprites
def build_sprites():
    jar = Scene(330, 380)
    # body+neck height 330: bottom of the glass sits on the sprite's bottom edge minus outline
    h = 330
    logos.jar(jar, 165, 380 - 15 - 0.5 * h, h, with_lid=False)
    save(jar.render(), SPR / "jar_body.png")
    lid = Scene(300, 90)
    ow = 0.045 * h
    lid.outlined([(rrect(150 - 0.40 * h, 45 - 0.10 * h, 0.80 * h, 0.20 * h, 0.07 * h), "magma")], ow,
                 details=[("line", [(150 + x * h, 45 - 0.065 * h), (150 + x * h, 45 + 0.065 * h)], "ink", ow * 0.7)
                          for x in (-0.24, -0.08, 0.08, 0.24)])
    save(lid.render(), SPR / "jar_lid.png")
    save(S.jeff().render(), SPR / "jeff_standin.png")
    save(S.chuck().render(), SPR / "chuck_standin.png")
    for k, (base, acc, kind) in FACES.items():
        save(S.face(base, acc, False, kind).render(400 / 512), SPR / f"face_{k}_calm.png")
        save(S.face(base, acc, True, kind).render(400 / 512), SPR / f"face_{k}_happy.png")
    save(S.dev_badge().render(), SPR / "dev_badge.png")
    atlas = Image.new("RGBA", (S.TW * 3, S.TH * 2), (0, 0, 0, 0))
    for i in range(5):
        atlas.alpha_composite(S.tile(i), ((i % 3) * S.TW, (i // 3) * S.TH))
    atlas.alpha_composite(S.empty_tile().render(), (2 * S.TW, S.TH))
    save(atlas, SPR / "card_tiles.png")
    save(S.sky().render(ss=2), SPR / "bg_sky.png")
    save(S.clouds().render(ss=2), SPR / "bg_clouds.png")
    save(S.hills().render(ss=2), SPR / "bg_hills.png")
    for i, n in enumerate(("star", "ball", "triangle", "jar")):
        save(S.floater(i).render(), SPR / f"floater_{n}.png")
    burst = Scene(360, 360)
    burst.outlined([(star(180, 180, 170, 95, 12), "jeff_yellow")], 8, details=[(star(180, 180, 120, 70, 12), "cloud")])
    save(burst.render(), SPR / "pop_burst.png")
    dust = Scene(200, 100)
    dust.outlined([(circle(x, 62 - abs(x - 100) * 0.12, r), "cloud") for x, r in ((48, 26), (82, 34), (122, 32), (156, 24))], 5)
    save(dust.render(), SPR / "dust_puff.png")
    save(S.glow_ring(), UI / "glow_ring.png")


# ---------------------------------------------------------------- store
def build_store():
    sky = S.sky().render(ss=1)
    hills = S.hills().render(ss=1)
    logo_a = logos.option_a()

    def char(scene, size, rot):
        return scene.render(size / 240).rotate(rot, resample=Image.Resampling.BICUBIC, expand=True)

    def burst(size):
        sc = Scene(360, 360)
        sc.outlined([(star(180, 180, 170, 95, 12), "jeff_yellow")], 8, details=[(star(180, 180, 120, 70, 12), "cloud")])
        return sc.render(size / 360)

    # grid 600x900: logo on top, Jeff and Chuck leaping out of a pop burst, ground at the bottom
    g = Image.new("RGBA", (600, 900))
    sk = sky.resize((960, 540)).crop((180, 0, 780, 540)).resize((600, 900))
    sk = sky.resize((1600, 900)).crop((500, 0, 1100, 900))
    g.alpha_composite(sk)
    b = burst(470)
    g.alpha_composite(b, (300 - b.width // 2, 560 - b.height // 2))
    gr = hills.crop((560, 720, 1360, 1080)).resize((600, 270))
    g.alpha_composite(gr, (0, 630))
    j = char(S.jeff(), 280, 14)
    c = char(S.chuck(), 280, -12)
    g.alpha_composite(j, (5, 470))
    g.alpha_composite(c, (595 - c.width, 480))
    lg = logo_a.render(570 / 1200)
    g.alpha_composite(lg, (15, 40))
    save(g.convert("RGB"), ROOT / "store" / "grid.png")
    # hero 920x430: logo left, the pair leaping out of the burst on the right
    h = Image.new("RGBA", (920, 430))
    h.alpha_composite(sky.resize((920, 518)).crop((0, 60, 920, 490)))
    b = burst(330)
    h.alpha_composite(b, (742 - b.width // 2, 240 - b.height // 2))
    h.alpha_composite(hills.crop((0, 780, 1920, 1080)).resize((920, 144)), (0, 430 - 144))
    j = char(S.jeff(), 185, 14)
    c = char(S.chuck(), 185, -12)
    h.alpha_composite(j, (568, 178))
    h.alpha_composite(c, (912 - c.width, 186))
    h.alpha_composite(logo_a.render(540 / 1200), (0, 82))
    save(h.convert("RGB"), ROOT / "store" / "hero.png")


# ---------------------------------------------------------------- theme + materials
def sb(bg, border="ink", bw=10, r=36, margin=(32, 24), shadow=None, draw_center=True, expand=0):
    lines = ['[sub_resource type="StyleBoxFlat" id="{id}"]',
             f"content_margin_left = {margin[0]}.0", f"content_margin_top = {margin[1]}.0",
             f"content_margin_right = {margin[0]}.0", f"content_margin_bottom = {margin[1]}.0",
             f"bg_color = {godot(bg) if bg else 'Color(0, 0, 0, 0)'}"]
    if not draw_center:
        lines.append("draw_center = false")
    lines += [f"border_width_{s} = {bw}" for s in ("left", "top", "right", "bottom")]
    lines.append(f"border_color = {godot(border)}")
    lines += [f"corner_radius_{c} = {r}" for c in ("top_left", "top_right", "bottom_right", "bottom_left")]
    lines.append("corner_detail = 12")
    if expand:
        lines += [f"expand_margin_{s} = {expand}.0" for s in ("left", "top", "right", "bottom")]
    if shadow:
        lines += [f"shadow_color = {godot('ink', 0.45)}", f"shadow_size = 1", f"shadow_offset = Vector2(0, {shadow})"]
    lines.append("anti_aliasing_size = 1.5")
    return "\n".join(lines)


def build_theme():
    boxes = {
        "panel": sb("cloud", shadow=12),
        "panel_accent": sb("sky1", shadow=12),
        "panel_dark": sb("sky5", border="ink", shadow=12),
        "btn_normal": sb("magma", bw=8, r=32, margin=(36, 20), shadow=8),
        "btn_hover": sb("jeff_yellow", bw=8, r=32, margin=(36, 20), shadow=8),
        "btn_pressed": sb("comb", bw=8, r=32, margin=(36, 20)),
        "btn_disabled": sb("stone", bw=8, r=32, margin=(36, 20)),
        "btn_focus": sb(None, border="cloud", bw=8, r=40, draw_center=False, expand=10),
        "bar_bg": sb("stone", bw=8, r=24, margin=(0, 0)),
        "bar_fill": sb("grass", bw=0, r=20, margin=(0, 0)),
    }
    ids = {k: f"StyleBoxFlat_{k}" for k in boxes}
    out = [f'[gd_resource type="Theme" load_steps={len(boxes) + 1} format=3]', ""]
    out.append(f"; Open Jar house theme, palette {NAME}. Generated by art/gen/build.py; do not hand-edit.")
    out.append("; No font: no chunky rounded font with an open licence was available offline, so the engine default is used.")
    out.append("")
    for k, body in boxes.items():
        out += [body.format(id=ids[k]), ""]
    T = lambda k: f'SubResource("{ids[k]}")'
    props = [
        "[resource]",
        "default_font_size = 44",
        f"Button/colors/font_color = {godot('ink')}",
        f"Button/colors/font_hover_color = {godot('ink')}",
        f"Button/colors/font_pressed_color = {godot('ink')}",
        f"Button/colors/font_focus_color = {godot('ink')}",
        f"Button/colors/font_disabled_color = {godot('ink', 0.6)}",
        f"Button/styles/normal = {T('btn_normal')}",
        f"Button/styles/hover = {T('btn_hover')}",
        f"Button/styles/pressed = {T('btn_pressed')}",
        f"Button/styles/disabled = {T('btn_disabled')}",
        f"Button/styles/focus = {T('btn_focus')}",
        f"Label/colors/font_color = {godot('ink')}",
        f"Label/colors/font_outline_color = {godot('cloud')}",
        "Label/constants/outline_size = 0",
        "LabelOnSky/base_type = &\"Label\"",
        f"LabelOnSky/colors/font_color = {godot('cloud')}",
        f"LabelOnSky/colors/font_outline_color = {godot('ink')}",
        "LabelOnSky/constants/outline_size = 16",
        f"Panel/styles/panel = {T('panel')}",
        f"PanelContainer/styles/panel = {T('panel')}",
        "PanelAccent/base_type = &\"PanelContainer\"",
        f"PanelAccent/styles/panel = {T('panel_accent')}",
        "PanelDark/base_type = &\"PanelContainer\"",
        f"PanelDark/styles/panel = {T('panel_dark')}",
        f"ProgressBar/styles/background = {T('bar_bg')}",
        f"ProgressBar/styles/fill = {T('bar_fill')}",
        f"ProgressBar/colors/font_color = {godot('ink')}",
    ]
    out += props
    p = ROOT / "scenes" / "ui" / "theme.tres"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(out) + "\n")
    print("wrote", p.relative_to(ROOT))


def material(name, shader, params):
    lines = ['[gd_resource type="ShaderMaterial" load_steps={n} format=3]', "",
             f'[ext_resource type="Shader" path="res://assets/shaders/{shader}.gdshader" id="1_shader"]']
    n = 2
    tex_lines = []
    for k, v in params.items():
        if isinstance(v, str) and v.startswith("res://"):
            tex_lines.append(f'[ext_resource type="Texture2D" path="{v}" id="{n}_tex"]')
            params[k] = f'ExtResource("{n}_tex")'
            n += 1
    lines = lines[:3] + tex_lines + ["", "[resource]", 'shader = ExtResource("1_shader")']
    lines[0] = lines[0].format(n=n)
    for k, v in params.items():
        lines.append(f"shader_parameter/{k} = {v}")
    p = SHD / f"{name}.tres"
    p.write_text("\n".join(lines) + "\n")
    print("wrote", p.relative_to(ROOT))


def build_materials():
    material("card_tiles", "card_tiles", {"tiles": "res://assets/sprites/launcher/card_tiles.png"})
    material("card_art", "card_art", {"ink": godot("ink")})
    material("glow_pulse", "glow_pulse", {})
    material("face_happy", "face_happy", {})
    material("face_calm", "face_calm", {"dim_color": godot("stone"), "dim_amount": "0.5"})
    material("bob", "bob", {"amp": "12.0", "speed": "1.4", "squash": "0.06"})
    material("drift", "drift", {"speed": "0.006", "amp": "6.0"})


if __name__ == "__main__":
    print(f"palette: {config.PALETTE} ({NAME})")
    r = build_logos()
    build_compare(r)
    build_sprites()
    build_store()
    build_theme()
    build_materials()
    import scenes
    scenes.build()
    import mocks
    mocks.build()
