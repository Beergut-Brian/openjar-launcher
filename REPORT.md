# Report: launcher-rules-audit-1 (Feel-rules audit lane)

Branch `fix/launcher-rules-audit-1` (off `dev` at `a1519fb`; `git merge origin/dev`: already up to date).
Not pushed. Status: **done**. Audits Kaden's standing game-feel rules (2026-11-13, as audited on Worm)
against the launcher hub on `dev`, and fixes the one that failed (FR-4: silent presses).

## Rules table

| # | Rule | Before (dev at a1519fb) | Now | Where |
| --- | --- | --- | --- | --- |
| 1 | The D-pad moves the hub character, the same as the stick | **Pass.** D-pad buttons are already in `project.godot`'s `p1_/p2_move_*` (PF-3); `hub.gd` `_read_players` walks on `Players.move_vector`. Only P1's slot had a test. | Pass, both pad slots tested | `tests/test_hub_dpad.gd` (new, real pad events: P1 slot, P2 slot, each direction); frames `handoff/frames/rules_dpad_*.jpg` |
| 2 | No forced movement and no snap in the hub; walk up to a jar to focus it, A uses it; no hop-to-next on stick or D-pad | **Pass.** `HubJarling.stick_velocity` is the raw stick; focus is `HubLayout.focus_at` (position only); the only steering is the `HUB_DEMO go:` script | Pass, now also pinned for the D-pad | `tests/test_hub_dpad.gd::test_dpad_held_walks_past_a_jar_instead_of_hopping_to_it`, `tests/test_hub.gd::test_holding_right_walks_past_the_jars_instead_of_snapping` |
| 3 | Both players join and ready up with A and the keyboard; the chooser in the join/ready step works with the D-pad | **Pass for join/ready** (any pad button or a stick push joins, P2's keys join, A at a jar launches for either player). **D-pad chooser: no.** There is no separate join/ready step: the chooser is in-line in the walkable hub (Select / Tab / slash), where the D-pad walks | Join/ready tested for pad A and P2's keys; D-pad chooser left for a decision (it would break rule 2) | `tests/test_hub_feel_rules.gd::test_p2_joins_with_a_on_a_second_pad`, `::test_p2_joins_from_the_keyboard`; "Needs a gameplay decision" below |
| 4 | Every action beeps; a press with no effect plays a refusal sound | **Fail.** Silent: A / B / the chooser while the Jarling is mid-jump or mid-swap, or while a launch plays; B and the chooser during the intro; X, Y, the stick clicks and stray keys (no action at all); LB or RB alone | **Fixed.** `hub.gd` `refuse()` plays `ui_back` (the "can't do that" cue, `assets/audio/CUES.md`), at most once a frame. `_input` catches buttons and keys no hub action uses (Godot's `ui_*` don't count; Guide is left to Steam). LB / RB alone tick `ui_move` like Start (half of a hold). | `scripts/hub/hub.gd` (`refuse`, `_pressed_now`, `_input`, `_bound_buttons`, `_process`, `_read_players`, `change_character`); `tests/test_hub_feel_rules.gd` (5 refusal tests) |
| 5 | The hub hint changes with context, with controller glyphs | **Pass.** At a jar with a game: A + "into the jar" over the head; the Select chooser hint by the ring after standing still; keyboard glyphs (Space/Enter, Tab/slash) with no pad; nothing at the empty jar | Pass (no change) | `tests/test_player_flow.gd::test_a_jar_in_focus_shows_the_jump_in_button`, `::test_the_jump_in_button_follows_the_players_pad_or_key`, `::test_the_empty_jar_never_offers_jump_in`; frames `rules_dpad_03_after_walked_to_jar_a_and_select_hints.jpg` (pad glyphs), `rules_quit_start_held_badge_filling.jpg` (key glyphs) |
| 6 | Quitting never needs a force-close, from the hub and from the menu | **Pass.** Start (pad) or Escape (keys) held 1.5 s quits, a tap never does; the window's close button goes through `Audio.quit`. The launcher has **no menu** (`pause` does nothing outside a round in `Game.gd`), so the menu half has nothing to check. Escape had no test. | Pass, Escape-hold now tested | `tests/test_quit_hold.gd`, `tests/test_hub_feel_rules.gd::test_escape_held_quits_and_a_tap_does_not`, `tests/test_audio_release.gd::test_close_button_goes_through_audio_quit`; frame `rules_quit_start_held_badge_filling.jpg` |
| 7 | Solo and start-fresh | **N/A.** The launcher keeps no game progress: `Save` holds only `LauncherState` (the last jar, the profile; the dev view is session-only). Solo is per game (`Players.gd` in each game). | N/A, nothing added | `scripts/launcher/launcher_state.gd` |

## Commits

- `1d324a1 hub: every ignored press answers with the refusal boop` (`scripts/hub/hub.gd`, `tests/test_hub_feel_rules.gd`)
- `14f5592 tests: the D-pad walks the hub character on both pad slots` (`tests/test_hub_dpad.gd`)
- `PLANSHA docs: PLAN-STATUS S8 feel rules, FR-1 to FR-7 (rules-audit-1)` (`PLAN-STATUS.md`, `REPORT.md`)

No change to `project.godot`, `addons/openjar/`, art, audio or store files.

## Tests

Clean import first (`rm -rf .godot && godot --headless --import --path .`), then `scripts/tools/test.sh`
(the full suite with `--continue`; user data, the tests' picks files and temp jars under `.scratch/`, never
the real `players.json`). The new suites use their own Save profiles and picks files
(`user://test_hub_dpad/players.json`, `user://test_hub_feel_rules/players.json`).

**Exit 0.** `Overall Summary: 209 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |` (198 before this lane), 0 engine errors. Log: `handoff/test-output.txt`.

New: 11 test cases (`test_hub_dpad.gd` 3, `test_hub_feel_rules.gd` 8).

## Frames (`handoff/frames/`)

Real Forward+ frames (`scripts/tools/shots.sh`, software GPU), `OPENJAR_ROOT=tests/fixtures/hub_8`, user data in
`.scratch/xdg-shots` (no real save or picks file touched), downscaled to 960x540.

- `rules_dpad_01_before_p1_at_start_jar.jpg`, `rules_dpad_02_dpad_right_held_walking.jpg`,
  `rules_dpad_03_after_walked_to_jar_a_and_select_hints.jpg`: `HUB_DEMO="follow;1.2:btn:0:14:1;2.4:btn:0:14:0"`
  (a real D-pad-right press on pad 0, shots at 1, 2, 4.5 s). P1 walks from the middle jar to a jar on the right,
  which comes into focus with the A + into-the-jar hint and the Select chooser hint; P2's Jarling waits.
- `rules_quit_start_held_badge_filling.jpg`: `HUB_DEMO="follow;1:holdstart:1.0"`, shot at 1.7 s: the quit badge
  filling in the corner; no pad joined, so the hints show key glyphs.

The refusal boop is sound only; the tests pin it (`hub.refusals`).

## Needs a gameplay decision

- **D-pad on the chooser (rule 3 vs rule 2).** The launcher's chooser is in-line in the walkable hub (M-01:
  Select / Tab / slash cycles your character where you stand). Rule 2 says the D-pad only moves the character
  in a walkable space, so it cannot also cycle the chooser. Options: (a) keep as is: the D-pad walks, Select
  changes (FR-3 stays partial, or is marked as superseded by rule 2); (b) give the chooser its own
  ready-up moment where the D-pad cycles. Recommendation: (a).
- **Refusal during a launch.** A, B or Select pressed while the launch animation plays now boop (rule 4). A kid
  mashing A through the launch will hear several boops over the launch beats. If that is too much, the
  alternative is to stay silent during the launch only.

## Template gaps

- `Game.gd` (template autoload) handles `pause` / `restart` but the launcher never enters a round, so Start's
  `pause` binding and Back's `restart` binding do nothing here by design. Not a launcher bug; noted in case the
  template wants launcher-style projects to drop those actions.

## Needs addons change

None.

## Notes

- The untracked `assets/characters/*/…_face.png` and pattern PNGs that appear after a clean import are textures
  Godot pulls out of the character models on import; they were not committed (not this lane's files).
- Not covered by the refusal: the triggers (they are axes, not buttons) and the 600 ms return grace after a
  game, which swallows the button that quit the game on purpose. A third pad pressing A while both slots are
  taken is still silent (A is a bound button).
