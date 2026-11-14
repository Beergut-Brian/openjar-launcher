# Report: hub-refusal-1 (hub refusal feedback lane)

Branch `feature/hub-refusal-1` (off `dev`; `git fetch origin && git merge origin/dev`: already up to date at `2d70a0b`).
Not pushed.

## What changed

A press the hub refuses was heard (`ui_back`) but not seen. CLAUDE.md #7 wants both. Now `refuse(player)` answers on
the player who pressed, for about 0.3 s (`HubJarling.REFUSE_SECONDS`), and never moves anyone:

| That player's Jarling is... | Visible answer |
| --- | --- |
| idle (standing or walking) | `shake()`: a no-no head shake. The body tilts about its middle (`_flip.rotation.z`), so its position never changes. |
| busy: mid-jump, mid-swap, or a launch is playing | `flash()`: its ring blinks white and pops bigger. The body is left alone, so the jump or swap isn't disturbed. |
| out of sight: the intro, inside the jar after the leap, or no Jarling | `flash_bar()`: a 36 px bar in the player's colour (P1 green on the left half, P2 red on the right) along the bottom edge. It shows at once and is gone by 0.3 s. No words. |

- `scripts/hub/hub.gd`: `refuse(player)` (all 5 call sites pass the player; a raw pad button goes to the pad's owner,
  stray keys go to P1), `flash_bar`, `refuse_bars`, `bar_flashes`, `REFUSE_BAR_HEIGHT`. It now fires once a frame
  **per player** (it was once a frame for both), so two players mashing in the same frame each get an answer.
- `scripts/hub/jarling.gd`: `shake()` now counts (`shakes`), restarts cleanly and lasts 0.3 s (it was 0.24 s). The
  chooser's "nobody free" shake uses it too. New: `flash()`, `flashes`, `ring_flashing()`, `ring_shown()`.
- Same refusal sound (`ui_back`); no audio, art, save, join or chooser-flow changes.
- The launcher has no `docs/ui.md` and no template menu kit, so this is a hub-only change, as the brief expected.

## Tests

`tests/test_hub_refusal.gd`, 6 tests. Each one checks that the refusal count goes up and that the shake or flash
counter goes up:
- unused pad button, idle → shake. It also checks the Jarling is upright again and hasn't moved.
- P2's unused button → only P2's Jarling answers.
- A mid-jump → ring blink, no shake. The blink is over after 0.3 s.
- chooser mid-swap → ring blink.
- B during a launch → ring blink before the leap; A after the leap → P1's bar.
- B during the intro → P1's bar in P1's colour, faded after 0.3 s.

The tests use a throwaway Save profile and picks file. `scripts/tools/test.sh` keeps all user data under `.scratch/`.

**Full suite on a clean import** (`.godot/` removed, then `scripts/tools/test.sh`): exit 0, **219 test cases** (213
before), 0 failures, 0 errors. Output in `handoff/test-output.txt`.

## Frames (looked at)

These are real frames from `scripts/tools/shots.sh` with `HUB_DEMO`, fixture `hub_8`, rendered by Forward+ on the
software GPU. They are in `handoff/frames/`, which is git-ignored, as before.
- Idle shake (`follow;1:btn:0:12:1;1.05:btn:0:12:0;2.97:btn:0:2:1;3.0:btn:0:2:0`, X on P1's pad):
  `refusal_01_idle_before_x.png`, `refusal_02_idle_x_head_shake.png`, `refusal_03_idle_x_shake_back.png`,
  `refusal_04_idle_after_upright.png`, strip `refusal_strip_idle_shake.png`. The tilt is visible but modest in a still.
- Mid-swap ring blink (same, plus `2.95:change`): `refusal_05_mid_swap_x_ring_blinks.png` (the ring is pale and big),
  `refusal_06_mid_swap_after_ring_green.png`, strip `refusal_strip_mid_swap_ring.png`.
- Inside the jar during a launch (`...;2:a;3.47:btn:0:2:1;3.5:btn:0:2:0`): `refusal_07_inside_jar_before_x.png`,
  `refusal_08_inside_jar_x_p1_bar.png` (green bar, bottom left), `refusal_09_inside_jar_bar_gone.png`. The first take
  had an 18 px bar at 0.9 alpha that was hard to see, so I made it 36 px and fully opaque, held for 0.1 s.
- Not framed: the intro bar. Demo commands wait until the intro ends, so a scripted press can't land during it. The
  test covers it.

## PLAN-STATUS

- **FR-4** updated in place: the proof has the 6 new tests and frames, and the notes describe the visible answer. Its
  status was already `built` (for the sound), so no status changed and the totals are unchanged (95 rows). I added a
  Hub-refusal-1 line to the run log.
- Moved row IDs: **FR-4** (built → built, proof and notes extended). There was no separate "seen" row to move.

## For Gary / Hermes

- The clean import extracted embedded character textures as untracked PNGs under `assets/characters/*/`. They are
  not committed (art is off-limits, and they're import by-products). Delete them or ignore them as you prefer.
- Worth a TV check: whether the 0.3 s head shake reads from the couch. Bump the angles in `HubJarling.shake()` if not.
