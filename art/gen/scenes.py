"""Writes the visual side of scenes/launcher/*.tscn. Node names, node types the scripts type-hint,
and every root script stay exactly as Systems made them (docs/contracts.md, "Launcher scenes").

intro.tscn: the systems tween in intro.gd still moves the Jar / Lid / Jeff / Chuck / Logo nodes;
an AnimationPlayer ("Anim") layers squash-and-stretch and effects on their Sprite children, keyed to
the same clock (pop at 0.5 s, logo thump at 2.15 s). It starts from a scene connection on the root's
visibility_changed signal, so no script changes are needed.
"""
import re

from pal import ROOT, godot

L = ROOT / "scenes" / "launcher"
SP = "res://assets/sprites/launcher/"

# Intro keys: node path -> property -> [(time, value)]. Times line up with intro.gd's tween:
# wobble 0-0.5, POP at 0.5, Jeff lands 1.6, Chuck lands 1.7, logo THUMP at 2.15, done at 2.85.
V = lambda x, y: (x, y)
LENGTH = 2.85
ANIM = {
    "Jar/Sprite": {"scale": [(0, V(1, 1)), (0.1, V(1.06, 0.94)), (0.2, V(0.95, 1.05)), (0.3, V(1.07, 0.93)),
                             (0.45, V(1.14, 0.84)), (0.5, V(0.86, 1.18)), (0.62, V(1.08, 0.93)), (0.75, V(0.97, 1.03)),
                             (0.9, V(1, 1)), (2.15, V(1, 1)), (2.2, V(1.07, 0.93)), (2.35, V(1, 1))]},
    "Jar/Lid/Sprite": {"scale": [(0, V(1, 1)), (0.45, V(1.12, 0.82)), (0.5, V(0.78, 1.3)), (0.7, V(1, 1))]},
    "PopBurst": {"scale": [(0, V(0.2, 0.2)), (0.48, V(0.2, 0.2)), (0.6, V(1.2, 1.2)), (0.85, V(1.6, 1.6))],
                 "modulate": [(0, (1, 1, 1, 0)), (0.48, (1, 1, 1, 0)), (0.5, (1, 1, 1, 1)), (0.7, (1, 1, 1, 1)), (0.85, (1, 1, 1, 0))],
                 "rotation": [(0.48, 0.0), (0.85, 0.7)]},
    "Jeff/Sprite": {"scale": [(0, V(0.7, 1.35)), (0.6, V(0.7, 1.35)), (0.9, V(1, 1)), (1.5, V(0.9, 1.12)), (1.6, V(1.32, 0.68)),
                              (1.72, V(0.9, 1.12)), (1.85, V(1.05, 0.96)), (1.95, V(1, 1)), (2.15, V(1, 1)),
                              (2.2, V(1.12, 0.88)), (2.3, V(0.94, 1.08)), (2.42, V(1, 1))]},
    "Chuck/Sprite": {"scale": [(0, V(0.7, 1.35)), (0.7, V(0.7, 1.35)), (1.0, V(1, 1)), (1.6, V(0.9, 1.12)), (1.7, V(1.32, 0.68)),
                               (1.82, V(0.9, 1.12)), (1.95, V(1.05, 0.96)), (2.05, V(1, 1)), (2.15, V(1, 1)),
                               (2.2, V(1.12, 0.88)), (2.3, V(0.94, 1.08)), (2.42, V(1, 1))]},
    "DustL": {"scale": [(0, V(0.3, 0.3)), (1.58, V(0.3, 0.3)), (1.85, V(1.3, 1.1))],
              "modulate": [(0, (1, 1, 1, 0)), (1.58, (1, 1, 1, 0)), (1.6, (1, 1, 1, 1)), (1.85, (1, 1, 1, 0))]},
    "DustR": {"scale": [(0, V(0.3, 0.3)), (1.68, V(0.3, 0.3)), (1.95, V(1.3, 1.1))],
              "modulate": [(0, (1, 1, 1, 0)), (1.68, (1, 1, 1, 0)), (1.7, (1, 1, 1, 1)), (1.95, (1, 1, 1, 0))]},
    "Logo/Sprite": {"scale": [(0, V(0.8, 1.25)), (2.1, V(0.8, 1.25)), (2.15, V(1.32, 0.7)), (2.25, V(0.9, 1.12)),
                              (2.35, V(1.06, 0.95)), (2.45, V(0.98, 1.02)), (2.55, V(1, 1))]},
    "ThumpBurst": {"scale": [(0, V(0.5, 0.5)), (2.13, V(0.5, 0.5)), (2.5, V(2.6, 1.6))],
                   "modulate": [(0, (1, 1, 1, 0)), (2.13, (1, 1, 1, 0)), (2.15, (1, 1, 1, 0.9)), (2.5, (1, 1, 1, 0))]},
}

# Sprite placement inside the systems' Control nodes (also used by mocks.py).
JAR_SPRITE = dict(position=(150, 362), offset=(-165, -380))   # jar_body.png 330x380, bottom-centre pivot
LID_SPRITE = dict(position=(170, 59))                          # jar_lid.png 300x100, centred
CHAR_SPRITE = dict(position=(120, 240), offset=(-120, -240))   # 240x240, feet pivot
LOGO_RECT = (540, 50, 1380, 470)                               # logo.png 840x420
LOGO_SPRITE = dict(position=(420, 420), offset=(-420, -420))
POP_AT, THUMP_AT = (960, 575), (960, 300)
DUST = {"DustL": (500, 932), "DustR": (1420, 932)}


def fmt(v):
    if isinstance(v, tuple) and len(v) == 2:
        return f"Vector2({v[0]:g}, {v[1]:g})"
    if isinstance(v, tuple):
        return "Color(%g, %g, %g, %g)" % v
    return f"{v:g}"


def anim_resource():
    lines = ['[sub_resource type="Animation" id="Animation_intro"]', 'resource_name = "intro"', f"length = {LENGTH}"]
    i = 0
    for path, props in ANIM.items():
        for prop, keys in props.items():
            t = ", ".join(f"{k[0]:g}" for k in keys)
            tr = ", ".join("1" for _ in keys)
            vals = ", ".join(fmt(k[1]) for k in keys)
            lines += [f'tracks/{i}/type = "value"', f"tracks/{i}/imported = false", f"tracks/{i}/enabled = true",
                      f'tracks/{i}/path = NodePath("{path}:{prop}")', f"tracks/{i}/interp = 1",
                      f"tracks/{i}/loop_wrap = true", f"tracks/{i}/keys = {{",
                      f'"times": PackedFloat32Array({t}),', f'"transitions": PackedFloat32Array({tr}),',
                      '"update": 0,', f'"values": [{vals}]', "}"]
            i += 1
    lines += ["", '[sub_resource type="AnimationLibrary" id="AnimationLibrary_intro"]', "_data = {",
              '&"intro": SubResource("Animation_intro")', "}"]
    return "\n".join(lines)


def header(ext, subs=0):
    out = [f"[gd_scene load_steps={len(ext) + subs + 1} format=3]", ""]
    for i, (typ, path) in enumerate(ext, 1):
        out.append(f'[ext_resource type="{typ}" path="{path}" id="{i}"]')
    return out


def build_intro():
    ext = [("Script", "res://scenes/launcher/intro.gd"), ("Texture2D", SP + "jar_body.png"),
           ("Texture2D", SP + "jar_lid.png"), ("Texture2D", SP + "jeff_standin.png"),
           ("Texture2D", SP + "chuck_standin.png"), ("Texture2D", SP + "logo.png"),
           ("Texture2D", SP + "pop_burst.png"), ("Texture2D", SP + "dust_puff.png")]
    out = header(ext, 2) + ["", anim_resource(), "", """[node name="Intro" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1")

[node name="PopBurst" type="Sprite2D" parent="."]
modulate = Color(1, 1, 1, 0)
position = Vector2(%d, %d)
scale = Vector2(0.2, 0.2)
texture = ExtResource("7")

[node name="Jar" type="Control" parent="."]
anchors_preset = 0
offset_left = 810.0
offset_top = 560.0
offset_right = 1110.0
offset_bottom = 920.0
pivot_offset = Vector2(150, 360)
mouse_filter = 2

[node name="Sprite" type="Sprite2D" parent="Jar"]
position = Vector2(%d, %d)
texture = ExtResource("2")
centered = false
offset = Vector2(%d, %d)

[node name="Lid" type="Control" parent="Jar"]
anchors_preset = 0
offset_left = -20.0
offset_top = -60.0
offset_right = 320.0
offset_bottom = 10.0
pivot_offset = Vector2(170, 35)
mouse_filter = 2

[node name="Sprite" type="Sprite2D" parent="Jar/Lid"]
position = Vector2(%d, %d)
texture = ExtResource("3")
""" % (POP_AT + JAR_SPRITE["position"] + JAR_SPRITE["offset"] + LID_SPRITE["position"])]
    for name, x, tex in (("Jeff", 380, 4), ("Chuck", 1300, 5)):
        out.append(f"""[node name="{name}" type="Control" parent="."]
anchors_preset = 0
offset_left = {x}.0
offset_top = 700.0
offset_right = {x + 240}.0
offset_bottom = 940.0
pivot_offset = Vector2(120, 120)
mouse_filter = 2

[node name="Sprite" type="Sprite2D" parent="{name}"]
position = Vector2{CHAR_SPRITE['position']}
texture = ExtResource("{tex}")
centered = false
offset = Vector2{CHAR_SPRITE['offset']}
""")
    for name, (x, y) in DUST.items():
        out.append(f"""[node name="{name}" type="Sprite2D" parent="."]
modulate = Color(1, 1, 1, 0)
position = Vector2({x}, {y})
scale = Vector2(0.3, 0.3)
texture = ExtResource("8")
offset = Vector2(0, -40)
""")
    l, t, r, b = LOGO_RECT
    out.append(f"""[node name="ThumpBurst" type="Sprite2D" parent="."]
modulate = Color(1, 1, 1, 0)
position = Vector2{THUMP_AT}
scale = Vector2(0.5, 0.5)
texture = ExtResource("7")

[node name="Logo" type="Control" parent="."]
anchors_preset = 0
offset_left = {l}.0
offset_top = {t}.0
offset_right = {r}.0
offset_bottom = {b}.0
pivot_offset = Vector2({(r - l) // 2}, {(b - t) // 2})
mouse_filter = 2

[node name="Sprite" type="Sprite2D" parent="Logo"]
position = Vector2{LOGO_SPRITE['position']}
texture = ExtResource("6")
centered = false
offset = Vector2{LOGO_SPRITE['offset']}

[node name="Anim" type="AnimationPlayer" parent="."]
libraries = {{
&"": SubResource("AnimationLibrary_intro")
}}

[connection signal="visibility_changed" from="." to="Anim" method="stop"]
[connection signal="visibility_changed" from="." to="Anim" method="play" binds= ["intro"]]
""")
    (L / "intro.tscn").write_text("\n".join(out))
    print("wrote scenes/launcher/intro.tscn")


def build_card():
    ext = [("Script", "res://scenes/launcher/card.gd"), ("Script", "res://scripts/launcher/placeholder_shape.gd"),
           ("Material", "res://assets/shaders/card_tiles.tres"), ("Material", "res://assets/shaders/card_art.tres"),
           ("Material", "res://assets/shaders/glow_pulse.tres"), ("Texture2D", "res://assets/sprites/ui/glow_ring.png"),
           ("Texture2D", SP + "dev_badge.png")]
    out = header(ext) + ["", """[node name="Card" type="Control"]
custom_minimum_size = Vector2(600, 900)
layout_mode = 3
anchors_preset = 0
offset_right = 600.0
offset_bottom = 900.0
pivot_offset = Vector2(300, 450)
mouse_filter = 2
script = ExtResource("1")

[node name="Placeholder" type="ColorRect" parent="."]
material = ExtResource("3")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color(0.33, 0.31, 0.42, 1)

[node name="Emblem" type="Control" parent="."]
visible = false
layout_mode = 1
offset_left = 120.0
offset_top = 230.0
offset_right = 480.0
offset_bottom = 590.0
mouse_filter = 2
script = ExtResource("2")

[node name="Caption" type="Label" parent="."]
layout_mode = 1
offset_left = 60.0
offset_top = 744.0
offset_right = 540.0
offset_bottom = 856.0
theme_override_font_sizes/font_size = 56
horizontal_alignment = 1
vertical_alignment = 1
text_overrun_behavior = 3

[node name="Art" type="TextureRect" parent="."]
visible = false
texture_filter = 5
material = ExtResource("4")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
expand_mode = 1
stretch_mode = 6

[node name="Frame" type="ReferenceRect" parent="."]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -14.0
offset_top = -14.0
offset_right = 14.0
offset_bottom = 14.0
mouse_filter = 2
border_color = Color(1, 1, 1, 0)
border_width = 0.0
editor_only = false

[node name="Glow" type="NinePatchRect" parent="Frame"]
material = ExtResource("5")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -50.0
offset_top = -50.0
offset_right = 50.0
offset_bottom = 50.0
mouse_filter = 2
texture = ExtResource("6")
patch_margin_left = 96
patch_margin_top = 96
patch_margin_right = 96
patch_margin_bottom = 96

[node name="DevBadge" type="Polygon2D" parent="."]
visible = false
position = Vector2(530, 72)

[node name="Icon" type="Sprite2D" parent="DevBadge"]
texture = ExtResource("7")
"""]
    (L / "card.tscn").write_text("\n".join(out))
    print("wrote scenes/launcher/card.tscn")


def build_picker():
    ext = [("Script", "res://scenes/launcher/profile_picker.gd"), ("Material", "res://assets/shaders/face_happy.tres"),
           ("Texture2D", SP + "face_a_calm.png"), ("Texture2D", SP + "face_a_happy.png"),
           ("Texture2D", SP + "face_b_calm.png"), ("Texture2D", SP + "face_b_happy.png"),
           ("Material", "res://assets/shaders/face_calm.tres")]
    out = header(ext) + ["", """[node name="ProfilePicker" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1")

[node name="Faces" type="Control" parent="."]
anchors_preset = 0
mouse_filter = 2
"""]
    for name, x, calm, happy in (("FaceP1", 440, 3, 4), ("FaceP2", 1080, 5, 6)):
        out.append(f"""[node name="{name}" type="Control" parent="Faces"]
anchors_preset = 0
offset_left = {x}.0
offset_top = 340.0
offset_right = {x + 400}.0
offset_bottom = 740.0
pivot_offset = Vector2(200, 200)
mouse_filter = 2

[node name="Calm" type="TextureRect" parent="Faces/{name}"]
material = ExtResource("7")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource("{calm}")
expand_mode = 1

[node name="Happy" type="TextureRect" parent="Faces/{name}"]
material = ExtResource("2")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource("{happy}")
expand_mode = 1
""")
    (L / "profile_picker.tscn").write_text("\n".join(out))
    print("wrote scenes/launcher/profile_picker.tscn")


# Background layers in launcher.tscn (shared by intro, picker and card row).
FLOATERS = [("star", 150, 170), ("ball", 430, 105), ("triangle", 1500, 120), ("jar", 1790, 205),
            ("ball", 70, 560), ("star", 1860, 600)]


def patch_launcher():
    p = L / "launcher.tscn"
    s = p.read_text()
    s = re.sub(r"\[gd_scene load_steps=\d+ format=3\]\n\n", "", s)
    s = re.sub(r'\[ext_resource type="(Theme|Texture2D|Material)"[^\n]*\n', "", s)
    ext = [("Theme", "res://scenes/ui/theme.tres"), ("Texture2D", SP + "bg_sky.png"), ("Texture2D", SP + "bg_clouds.png"),
           ("Texture2D", SP + "bg_hills.png"), ("Material", "res://assets/shaders/drift.tres"),
           ("Material", "res://assets/shaders/bob.tres")] + \
          [("Texture2D", SP + f"floater_{n}.png") for n in ("star", "ball", "triangle", "jar")]
    ids = {}
    lines = []
    for i, (typ, path) in enumerate(ext, 10):
        ids[path] = f"{i}_art"
        lines.append(f'[ext_resource type="{typ}" path="{path}" id="{i}_art"]')
    n_ext = len(re.findall(r"^\[ext_resource", s, re.M)) + len(ext)
    s = f"[gd_scene load_steps={n_ext + 1} format=3]\n\n" + "\n".join(lines) + "\n" + s
    # root theme
    s = re.sub(r'(\[node name="Launcher" type="Control"\]\n)(theme = [^\n]*\n)?', r'\1theme = ExtResource("10_art")\n', s)
    # replace the Background block (and any previous art children) with the layered sky
    bg = f"""[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = {godot('sky5')}

[node name="Sky" type="TextureRect" parent="Background"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource("{ids[SP + 'bg_sky.png']}")
expand_mode = 1

[node name="Clouds" type="TextureRect" parent="Background"]
texture_repeat = 2
material = ExtResource("{ids['res://assets/shaders/drift.tres']}")
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource("{ids[SP + 'bg_clouds.png']}")
expand_mode = 1

[node name="Floaters" type="Node2D" parent="Background"]
"""
    for i, (kind, x, y) in enumerate(FLOATERS):
        bg += f"""
[node name="Floater{i + 1}" type="Sprite2D" parent="Background/Floaters"]
material = ExtResource("{ids['res://assets/shaders/bob.tres']}")
position = Vector2({x}, {y})
texture = ExtResource("{ids[SP + f'floater_{kind}.png']}")
"""
    bg += f"""
[node name="Hills" type="TextureRect" parent="Background"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
texture = ExtResource("{ids[SP + 'bg_hills.png']}")
expand_mode = 1

"""
    s = re.sub(r'\[node name="Background".*?(?=\[node name="Intro")', bg, s, flags=re.S)
    p.write_text(s)
    print("patched scenes/launcher/launcher.tscn")


def patch_card_row():
    p = L / "card_row.tscn"
    s = p.read_text()
    for node, key in (("HoldMeter", "magma"), ("Flash", "cloud")):
        s = re.sub(r'(\[node name="%s"[^\[]*?\ncolor = )Color\([^)]*\)' % node, r"\g<1>" + godot(key), s, flags=re.S)
    p.write_text(s)
    print("patched scenes/launcher/card_row.tscn")


def build():
    build_intro()
    build_card()
    build_picker()
    patch_launcher()
    patch_card_row()
