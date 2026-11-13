# Report: launcher-fr3-1 (Join-and-ready gap lane)

Branch `feature/launcher-fr3-1` (off `dev`; `git merge origin/dev`: already up to date). Not pushed.
Status: **done, FR-3 stays partial** (two paths need a gameplay decision, below). No game code changed.

## FR-3 audit: each path

| Path | In the code | Test (all in `tests/test_hub_feel_rules.gd` unless named) | State |
| --- | --- | --- | --- |
| Join with A on a second pad | `Players.gd` claims the pad, `hub.gd` `_on_player_joined` → `join_second_player` | `test_p2_joins_with_a_on_a_second_pad` | built |
| Join from the keyboard (P2 keys) | `hub.gd` `_read_players`: any P2 key with no P2 joins | `test_p2_joins_from_the_keyboard` | built |
| Join with the D-pad | any pad press claims the pad (PF-3) | `tests/test_player_flow.gd::test_a_dpad_press_joins_and_walks_player_one` | built |
| The press that joins never also launches | the joining event lands before P2's action is bound to that pad | `test_p2_joined_on_a_pad_gets_its_own_select_and_a_hints`, `test_p2_joined_from_the_keyboard_gets_the_slash_and_enter_hints` (new: P2 waits at a jar in the fixture) | built, newly tested |
| Hint follows the join | `_update_hints` on join: P2's ring gets Select + A (pad) or `/` + Enter (keys) in red | the same two new tests | built, newly tested |
| P2's chooser on their own pad | `_change_just_pressed` reads Back per device | `test_p2_changes_character_with_select_on_their_own_pad_only` (new; P1's pick does not change) | built, newly tested |
| Ready with A | A at a jar launches, for P1 or P2 | `tests/test_playtest_1112.gd::test_p2_at_a_jar_presses_a_and_launches_it_and_nobody_is_moved`, `::test_p1_launches_too_with_p2_far_away` | built |
| Chooser left / right on the D-pad | **not built.** In the hub the D-pad walks (FR-1); Select / Tab / `/` cycles | `test_the_dpad_left_and_right_walk_and_never_change_the_character` (new: pins today's behaviour) | partial |
| Un-ready with B | **not built.** There is no ready state: A at a jar launches straight away; B during the launch is a refusal boop (FR-4) | — | partial |

The brief expected the gap to be a missing D-pad binding on a join/ready chooser (the template's `docs/ui.md` fix). It
is not that: the D-pad bindings are all in `project.godot` (`tests/test_player_flow.gd::test_every_move_action_has_its_dpad_button`),
and the launcher has no join/ready step at all. Joining happens in the walkable hub and the chooser lives on your
Jarling (GAME.md, 2026-11-10 chooser: "the hub has no ready screen, so the chooser lives on your Jarling").

## Needs a gameplay decision (Hermes / Kaden)

FR-3's remaining two paths both need a join/ready step that the hub does not have. Adding the D-pad to the chooser in
the hub would take away D-pad walking, which FR-1 and FR-2 require (and the brief says not to change the stick). The
choices are the same as in the rules-audit-1 report:
- (a) Keep it as it is. The D-pad walks and Select changes the character. Mark FR-3's D-pad chooser and un-ready rows
  as superseded by FR-1. **Recommended:** a 5-year-old already joins with any button and launches with A.
- (b) Add a short ready-up moment when P2 joins (or before a launch) where the D-pad cycles characters, A means
  ready and B means un-ready. That is a new screen and a change to GAME.md, so it is not this lane's call.

## Tests

`rm -rf .godot && godot --headless --import --path .`, then `scripts/tools/test.sh` (the gdUnit4 command with
`--continue`, every user path in `.scratch/`): exits 0.
`Overall Summary: 213 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |` (`handoff/test-output.txt`).
The new tests use the suite's own throwaway picks file (`user://test_hub_feel_rules/players.json`) and Save profile.
One test uses `tests/fixtures/roster_three.json` so a two-player Select has a free character.

## Frames (real, Forward+ on llvmpipe, 1920x1080)

`HUB_DEMO="follow;1.0:btn:0:12:1;1.1:btn:0:12:0;1.6:btn:1:0:1;1.7:btn:1:0:0;2.6:btn:1:14:1;3.6:btn:1:14:0"`
(pad 0 D-pad down = P1, pad 1 A = P2 joins, pad 1 D-pad right held for 1 s). These are real pad events.
- `handoff/frames/fr3_01_p2_joined_with_a_on_pad_two.png` (2.3 s): the yellow Jarling with its green ring stands at
  the jar. Next to it, P2's character (the cap-and-hoodie kid) has a red ring and is cheering with both arms up, just
  after joining. No hint glyphs yet.
- `handoff/frames/fr3_02_p2_dpad_right_walked_select_hints_both.png` (6.0 s): P2 has walked well to the right on the
  D-pad and stands near the island edge. Its character is the same, because the D-pad did not cycle it. Both players
  show the chooser hint on the floor by their rings, in their own colours: the Select button glyph and a green swap
  icon for P1, a red one for P2. I did not see an A "into the jar" hint over P1's jar. The shot used this box's real
  games root, not a fixture, so that jar is probably the empty one, which never offers A.

There is no frame of "a D-pad chooser change" because that path does not exist (see above). The second frame shows
what the D-pad does on this step instead.

## Commits

See `handoff/handoff.json`.

## Not touched

Art, logo, palettes (V-01, V-02), audio, `project.godot` (no D-pad binding was missing), the launch-checklist TV
rows (K-06), other repos.

Note: the clean import (`rm -rf .godot`) extracts the character models' embedded textures as untracked PNGs under
`assets/characters/`. They were not in the repo before and are Art's folder, so I deleted them and did not commit them.
