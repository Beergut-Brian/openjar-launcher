# theme/

`openjar_theme.tres`: the Open Jar house UI theme (palette "Cool Arcade"). Big, chunky,
high-contrast controls for kids: thick dark ink borders, round corners, a soft drop shadow, large
type (`default_font_size = 44`).

Source: copied verbatim from the launcher's `scenes/ui/theme.tres` (openjar-launcher origin/dev
ea2a417, generated there by `art/gen/build.py`). It is self-contained: only `StyleBoxFlat`
sub-resources, no `ext_resource`, no `res://` paths, no font file (the engine default font is
used; no open-licence chunky rounded font was available). It loads in any project with the addon
mounted, launcher or not. Change it in the launcher's generator first, then copy it here again,
so the two never drift.

## What it styles

| Type | Items |
| --- | --- |
| `Button` | styles `normal` (orange), `hover` (yellow), `pressed` (pink, no shadow), `disabled` (grey), `focus` (light outline ring, no fill); all five font colours (ink; disabled at 60%) |
| `Label` | `font_color` ink, `font_outline_color` light, `outline_size` 0 |
| `LabelOnSky` (variation of `Label`) | light text, ink outline 16, for text over the sky or art |
| `Panel`, `PanelContainer` | style `panel`: light card, 10px ink border, radius 36 |
| `PanelAccent`, `PanelDark` (variations of `PanelContainer`) | cyan / violet card, same shape |
| `ProgressBar` | `background` (grey, ink border), `fill` (teal); `font_color` ink |

## Using it in a game

Whole project (every Control, including popups): Project Settings > GUI > Theme > Custom, or in
`project.godot`:

```
[gui]
theme/custom="res://addons/openjar/theme/openjar_theme.tres"
```

One subtree (a menu, a HUD) only:

```gdscript
$Menu.theme = load("res://addons/openjar/theme/openjar_theme.tres")
```

Variations: set `theme_type_variation` on the node, e.g. `&"PanelDark"` on a `PanelContainer`,
`&"LabelOnSky"` on a `Label`. Per-node overrides (`add_theme_*_override`) still win.

Tested by `tests/project/suites/test_theme.gd`.
