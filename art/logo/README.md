# "Open Jar Games" logo options (for Kaden)

Kaden sees `compare.png`: top row on the launcher sky, middle row on light, bottom row at phone and
icon sizes. All three are drawn from code (`art/gen/logos.py`, letters in `art/gen/letters.py`):
original chunky round-stroke letters, thick ink outlines, palette C colours. SVG and PNG come from
the same baked points, so they match.

| Option | Idea | Files |
| --- | --- | --- |
| **A** (in the game for now) | Horizontal lockup: the jar pops its lid on the left, "OPEN JAR / GAMES" bounces on the right. Widest and most "loud". | `option_a.svg`, `option_a.png` |
| B | The jar *is* the badge: lid on top, "OPEN JAR" in the glass, "GAMES" on a pink ribbon. Most compact; best as an app icon. | `option_b.svg`, `option_b.png` |
| C | "OPEN JAR" arched over a small popping jar in a starburst, "GAMES" on a banner. Most "title screen". | `option_c.svg`, `option_c.png` |

To switch the in-game logo, change `option_a()` to the pick in `build_logos()` in `art/gen/build.py`
(the line under "option A is the in-game logo") and re-run the build.
