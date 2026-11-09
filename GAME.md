# Open Jar Games (launcher)

> Build 0. The front door to every game on the TV. Born from `openjar-template`, shipped through
> the same Release pipeline, so it is also the template's first end-to-end test.

## Pitch
One Steam tile, "Open Jar Games". It opens on a big, loud, fun animation: the jar opens, the
roster of characters tumbles out (Jeff and Chuck for now), the logo lands with a thump. Then a
row of game cards. Pick one, it launches. When the game quits, you are back here.

## Players
- Either pad drives the launcher. No P1/P2 distinction here except the profile picker.
- Profile picker: two faces, no names. Picks which `--profile=` the game gets.

## Controls
| Input | Does |
| --- | --- |
| Left stick / D-pad | Move between cards |
| A | Launch the highlighted game (or skip the intro) |
| B | Back to the card row from the profile picker |
| Hold LB + RB for 1 s | Toggle showing the `(dev)` builds (badge in the corner of the card) |
| Start | Quit to Steam |

## Core loop
Intro (skippable after first viewing) → profile picker (remembers last pick, one press to confirm)
→ card row → launch → on exit, back to the card row with the last card highlighted.

## Progression
None. The roster in the intro grows as `openjar-characters` grows; the card row grows as games
are installed.

## Camera
Fixed 2D UI at 1080p.

## Art direction
- Technique: 2D, flat vector shapes with the house-style thick outlines; the intro animation is
  Godot `AnimationPlayer` over sprites, not video. Characters in the intro are their library
  reference renders.
- Palette: the Open Jar master palette (the maker profile proposes three, Kaden picks). This is
  where the master palette is born.
- Cards: 600x900 grid art from each game's `store/grid.png`, a looping clip (`store/clip.mp4`)
  or animated art on highlight, a small dev badge when showing dev builds.
- Logo: "Open Jar Games" wordmark and a jar icon. Original design.

## Audio
- Intro: a short, loud sting (jar pop, tumble, logo thump). Characters bark as they land.
- UI: `ui_move`, `ui_confirm`, a soft loop under the card row.

## Lanes for this game
| Lane | Active | Definition of done |
| --- | --- | --- |
| Systems | yes | Reads `~/Games/openjar/*/openjar.json`, launches binaries with `--profile=`, returns on exit, remembers last card, dev toggle |
| Gameplay | no | |
| Design / Art | yes | Intro animation, logo, card layout, theme (which becomes the `openjar-addons` theme), profile faces |
| Content | no | |
| Audio | yes | Intro sting, UI cues, loop |
| Reviewer | yes | |

## First playable
Launcher boots on the TV from a Steam tile, shows the intro once, shows cards for whatever is
installed (Smash Party via its kiosk shortcut counts), launches one, comes back. Tag `v0.1.0`.

## Out of scope
- Downloading or updating games (that is `openjar-tv/update.sh`).
- Settings screens. There is nothing to set.
- Anything a kid has to read.

## Decisions made without Kaden
- 2026-11-09: launcher reads manifests from disk rather than calling GitHub; keeps it offline-safe.
- 2026-11-09: intro plays on the first boot of each local day only (date kept in the launcher's
  Save as `launcher.intro_date`), and A always skips it. This is the proposal from Open questions.
- 2026-11-09: card row clamps at the ends instead of wrapping; pressing past an end still plays
  `ui_move` and wobbles the end card, so the input is never silent.
- 2026-11-09: B on the card row opens the profile picker (B in the picker goes back). That is the
  only way back to the picker after boot.
- 2026-11-09: no games installed shows one empty grey card; A on it plays `ui_back` and wobbles.
- 2026-11-09: Start quits to Steam from every launcher screen (intro, picker, cards), not only
  the card row. Ignored while a game runs.
- 2026-11-09: last card is remembered by `slug`, not position, so installs/removals do not shift it.

## Open questions
- Logo and jar design: Kaden approves the Art lane's three options.
- Should the intro play every boot or only the first boot of the day? Proposal: first boot of the day, skippable always.
