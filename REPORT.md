# Report: launch-ready-3 (launch-readiness lane, pass 3)

Branch `feature/launcher-launch-ready-3`, based on `origin/dev` at `9a18f24` (after press-answers-adopt-1,
hub-refusal-1, rules-audit-1, FR3-1, FR3-decide-1). Not pushed.

**Verdict:** the launcher hub is launch-ready on the producer box. Still open: the TV-box checks
(K-06 and real pads, Kaden's weekend item) and the items under "Needs Kaden".

## What changed

- `tests/test_hub.gd`, `test_hub_feel_rules.gd`, `test_hub_refusal.gd`, `test_playtest_1112.gd`,
  `test_player_flow.gd`, `test_hub_dpad.gd`: `before_test` loaded `data/roster.json`. Two chooser tests
  (`test_hub.gd::test_solo_change_trades_with_the_tag_along_and_is_remembered`,
  `::test_the_change_button_cycles_but_not_during_a_launch`) relied on the real roster's order, so they now load
  `tests/fixtures/roster_three.json`. Only `tests/test_real_roster_voices.gd` still reads the real roster, on
  purpose: it pins the vendored voices.
- `docs/launch-checklist.md` rewritten for `dev` at `9a18f24`: each standing rule with yes / no / n/a and its proof,
  the TV checks spelled out step by step, Needs Kaden, and how to load the build.
- `README.md`: P2 also drops in with a stick push (PT1112-1). The README said a button only.
- `PLAN-STATUS.md`: a launch-ready-3 line in the header. No row moved.

No game code changed. The text check found nothing to remove: no placeholder text, and the hub shows only the
glyph hints, the 1.5 s name tags and the faint version label in the corner. Log lines go to stdout only. F3
(stat overlay) and F12 (screenshot) are keyboard-only. F3 stays because K-06 needs it.

## Rows

- **Moved:** none. Open rows on `9a18f24`: V-01 and V-02 (partial), K-06 (missing). FR-7 is N/A.
- **Skipped:**
  - V-01 (logo): art. It needs Kaden's pick and the Art Director process.
  - V-02 (palette): art. It needs Kaden's pick and the Art Director process.
  - V-06 (store art redo after V-01): art. Built, so it was not reopened.
  - K-06 (60 fps on the GTX 1060): needs the TV box.
- Totals unchanged: 95 rows, 79 built, 12 superseded, 2 partial, 1 missing, 1 N/A.

## Session flow frames (`handoff/frames/`, Forward+ on the software GPU, `tests/fixtures/hub_8`)

Every run exited 0 with 0 script errors. I looked at every frame.

| Step | Frame | What it shows |
| --- | --- | --- |
| Main menu (the hub is the launcher's only screen) | `join_t000.8s.png` | Jar Island at boot with 8 jars. Jeff stands at the middle jar showing the keyboard hints (no pad has joined yet). Chuck waits with no ring. `v0.0.0-local` sits small in the corner. |
| Ready-up: P1 presses A | `join_t002.0s.png` | P1's A on pad 0 at the jar: Jeff dives into the jar, the lid spins off, a light beam. It launches the fixture game and comes back (`dino-dash exited (code 0)`). |
| Ready-up: P2 presses A | `join_t004.5s.png` | P2's A on pad 1 joins: Chuck gets a red ring, and A plus the into-the-jar glyph show at his jar. Jeff is back with a green ring. Nobody was moved. |
| Ready-up alone | `alone_quit_t002.0s.png`, `alone_quit_t002.5s.png` | One player walks away with the stick and presses A: a happy cheer (arms up), no launch. The hub has no ready step (FR-3 superseded): one player's A at a jar launches. |
| Pause / back to the launcher | `alone_quit_t003.7s.png`, `alone_quit_t005.9s.png` | No pause menu exists: this is the launcher. A Start tap shows the door badge top right with a sliver filled. Holding Start fills the ring. The run then exits 0 on its own (the 9 s frame never came). Quit without a force-close. |
| Solo `--solo` and Select+Start 2 s | `solo_combo_t000.8s.png`, `t001.4s.png`, `t002.2s.png` | `--solo` changes nothing (normal hub; solo is per game, FR-7). Select+Start held: Select swaps P1 Jeff → Chuck (name tags "Chuck" and "Jeff", Jeff becomes the waiting friend) and the Start hold fills the door badge. The launcher quit at 1.5 s, before the 4 s frame. See Needs Kaden. |
| Drop-in | `dropout_t003.5s.png` | Both joined on pads, each at their own jar with their own A hints. Green and red rings, and each jar's floor pad lights in its player's colour. |
| Drop-out | `dropout_t004.3s.png`, `dropout_t006.0s.png` | P2's pad unplugged (`unplug:1`). The camera reframes on P1 (Jeff at the purple jar, A and Select hints). Chuck stays where he stood with no ring, out of shot. |

## Soak

`scripts/tools/soak.sh` (headless, 1800 s, the scripted session: walk, launch, return, change, P2 in and out, profile
swap), user data in `.scratch/`: **0 script or engine errors**, exit 0, 0 orphans, 66 launches and returns.
After a 2 min warm-up the counts stay flat: objects 3119 → 3097, nodes 624 → 626, static memory 116 → 100 MB.
Log: `handoff/soak/soak.tsv`, `soak.log`.

A first soak attempt aborted at 570 s. My fault: I wiped `.godot/` for the clean-import test run while the soak was
still running, so its imported models vanished mid-run (`handoff/soak/soak-aborted-by-cache-wipe.log`; every error
starts with `Cannot open file 'res://.godot/imported/...'`). It is not a launcher bug, and the re-run above is clean.
One side note: after a failed model load, `jarling.gd:489` `_squash` touches a freed body and the engine crashes.
A player can't hit it, since it needs the import cache deleted under a running build. I did not fix it.

## Tests

`scripts/tools/test.sh` after a clean import (`.godot/` removed), `--ignoreHeadlessMode --continue`: **219 test
cases, 0 failures, 0 errors, 0 orphans, 0 engine ERROR lines** (`handoff/test-output.txt`). The hub has no physics
bodies (`HubLayout.walkable` clamps positions), so no test depends on a pile.

## Needs Kaden

- **Select+Start in the hub quits.** In the games, Select+Start held 2 s means solo. In the hub, the same hold
  changes your character and then quits to Steam at 1.5 s (frames `solo_combo_*`). Keep it, or have the hub
  ignore the Start hold while Select is down?
- V-01 logo pick and V-02 palette pick (open since 2026-11-09).
- (Optional, open since 2026-11-10) K-02: keep Start as a 1.5 s hold, or go back to one press.

No playtest result was invented. The TV checks are listed in `docs/launch-checklist.md`, "Needs the TV box".
