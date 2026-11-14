# Launch checklist: openjar-launcher

Launch-readiness pass 3 (`feature/launcher-launch-ready-3`, 2026-11-14). Checked against `dev` at
**`9a18f24`** (after press-answers-adopt-1, hub-refusal-1, rules-audit-1, FR3-1 and FR3-decide-1).
Replaces the 2026-11-10/12 checklist (passes 1 and 2), which was written before those merges.
Row ids are `PLAN-STATUS.md` ids. Frames are in `handoff/frames/` in the lane worktree (git-ignored);
`REPORT.md` says what each one shows.

**Verdict:** launch-ready on the producer box, except the TV-box checks below (K-06 and the real-pad
checks) and the Kaden items (V-01 / V-02 picks, and one question about Select+Start in the hub).

## Standing rules

| Rule | Yes / no | Proof |
| --- | --- | --- |
| No stick-only requirement | yes | FR-1: the D-pad and keys walk too. `tests/test_hub_dpad.gd::test_dpad_walks_player_one_every_direction`, `::test_dpad_walks_player_two_every_direction`; `tests/test_player_flow.gd::test_every_move_action_has_its_dpad_button` |
| No auto-steering the player | yes | FR-2: the stick only moves the character, no snap or pull to a jar. `tests/test_hub_dpad.gd::test_dpad_held_walks_past_a_jar_instead_of_hopping_to_it`, `tests/test_hub.gd::test_holding_right_walks_past_the_jars_instead_of_snapping`; coming back from a game moves nobody: `tests/test_playtest_1112.gd::test_p2_at_a_jar_presses_a_and_launches_it_and_nobody_is_moved`. The only steering is the `HUB_DEMO` / `--demo` script, which a player can't reach. |
| Gear is worn | n/a | The hub has no gear or pickups. |
| Progress is earned behind visible barriers | n/a | The hub has no progression; every installed game is a jar from the start (C-11). |
| Each vehicle or tool has a job only it can do | n/a | No vehicles or tools in the hub. |
| Anything that changes play shows its cause | yes | Every change has a visible and audible cause: focus (P-05), the chooser poof and name tag (M-01, M-08, M-11), the dev lid (C-07), the profile swap pop (C-08), drop-in and drop-out (K-04, PF-5), refusals (FR-4: `tests/test_hub_refusal.gd`, 6 tests). Frames `join_*`, `dropout_*`, `solo_combo_t002.2s.png`. |
| No real places or personal details | yes | L-04: design docs, store art and kiosk files stay out of the pack (`export_presets.cfg`, `tests/test_export.gd`); hub text is character names and the version only. |
| Solo mode is session-only and never restored at boot | n/a (yes for what exists) | The launcher has no solo switch: one player is simply one joined pad (FR-7). `--solo` is accepted and ignored (frame `solo_combo_t000.8s.png` is the normal hub). Solo is per game. |
| Saved toggles never restore at boot | yes | The only toggle, the dev view, is never saved: `tests/test_manifest_scanner.gd::test_dev_filtering_and_sorted_order`, `tests/test_playtest_1112.gd::test_dev_view_shows_one_jar_per_game`; C-07 / PT1112-2. The save holds the last jar and the profile only (`LauncherState`, `tests/test_launcher_state.gd::test_round_trip`). |
| A game with a save offers Continue and New (New asks first, keeps a backup) | n/a | The launcher keeps no game progress (FR-7); each game does this itself. |
| The pause menu has a big icon back to the launcher | n/a | This is the launcher. It has no pause menu (the template's `pause` action does nothing outside a round, `Game.gd`). Its way out is the door badge: hold Start 1.5 s (K-02, FR-6). |
| Quitting never needs a force-close | yes | FR-6: `tests/test_quit_hold.gd::test_holding_start_quits`, `tests/test_hub_feel_rules.gd::test_escape_held_quits_and_a_tap_does_not`, `tests/test_audio_release.gd::test_close_button_goes_through_audio_quit`; frames `alone_quit_t003.7s.png` (tap: the badge shows), `alone_quit_t005.9s.png` (held: the badge fills), then the run exits 0 by itself. |
| Every press is heard and seen (CLAUDE.md #7) | yes | K-03, FR-4 (refusals heard and seen, hub-refusal-1). |
| P1 green, P2 red | yes | K-08; frames `join_t004.5s.png`, `dropout_t003.5s.png`. |
| Credits for every asset | yes | K-11 (`assets/CREDITS.md`); this pass added no assets. |

## Checked on the producer box (2026-11-14, `dev` at `9a18f24`)

- **Tests:** `scripts/tools/test.sh` after a clean import (`.godot/` removed first), `--continue`: 219 test cases,
  0 failures, 0 errors, 0 orphans, 0 engine `ERROR` lines (`handoff/test-output.txt`). The six hub suites that
  read the real roster (`test_hub`, `test_hub_feel_rules`, `test_hub_refusal`, `test_playtest_1112`,
  `test_player_flow`, `test_hub_dpad`) now use `tests/fixtures/roster_three.json`. Only
  `tests/test_real_roster_voices.gd` reads `data/roster.json` on purpose (it pins the vendored voices).
  The hub has no physics bodies (walking and jar blocking are worked out by `HubLayout`), so no test
  depends on a pile settling.
- **Session flow, real frames** (Forward+ on the software GPU, `tests/fixtures/hub_8`, user data in
  `.scratch/`): hub boot, A at a jar launches and comes back, P2 joins with A on a second pad, a cheer away
  from a jar, Start tap and hold (exits 0 by itself), Select+Start held, `--solo`, P2 joins and then
  unplugs. Every run exited 0 with 0 script errors.
- **Soak:** 30 minutes headless with the scripted session (`scripts/tools/soak.sh`): 1800 s, exit 0, **0 script or engine errors**, 0 orphans, 66 game launches and returns; after a 2 min warm-up objects 3119 → 3097, nodes 624 → 626, resources 169 → 143, static memory 116 → 100 MB (flat, no leak). Log `handoff/soak/soak.tsv`, `soak.log`. Frame times are the headless loop, not the TV (K-06).
- **Text:** no placeholder text, and no debug print or dev switch a player can see in normal play. The
  log lines (`launcher: ...`, `Chooser voice: ...`) go to stdout only. F3 (stat overlay) and F12
  (screenshot) are keyboard-only grown-up tools. Keep F3: the K-06 check uses it. The corner shows the
  version (`v0.0.0-local` on a local build, the tag on a release).

## Needs the TV box (Kaden's weekend)

- [ ] **K-06, 60 fps at 1080p on the GTX 1060.** Boot the launcher from the Steam tile, plug in a keyboard and
      press F3 (top-left overlay: `fps`). Read it (a) standing in the hub with 2 players, (b) during the intro
      (first boot of the day; to see it again, delete `launcher.intro_date` from the save or wait a day), (c)
      during a launch (walk to a jar, press A). Pass: 60 in all three, no visible hitches.
- [ ] **Cold start (K-07, built on the box's numbers, confirm on the TV).** From the Steam tile press to a hub
      you can walk in under 10 s. Read the `launcher: interactive ... after N ms` line in the log for the first
      boot of the day (with an `intro` mark) and a second boot.
- [ ] **8BitDo pads on the TV:** the first pad's A makes it P1 (green ring), the second pad's A or a stick push
      makes it P2 (red ring); switch P2's pad off: a "bye-bye" blip and a hop; D-pad walks both; Select changes
      character on that player's own pad only; LB+RB held 1 s shows the dark-lid dev jars; Start tapped shows
      the door badge, held 1.5 s quits to Steam.
- [ ] **One launch and return (S-02):** walk to a jar, press A; the game opens full screen; quit it from its
      pause menu; the hub comes back full screen and in front. Log: `launcher: window:` lines.
- [ ] **Smash Party (C-14):** `kiosk/smash-party/install.sh` once; launch its jar, play with a pad in the
      browser, then come home with the browser's close and again with Start held 2 s.
- [ ] The corner version reads the release tag and is small enough to ignore from the sofa.

## Needs Kaden

- [ ] **Select+Start in the hub.** In the games, Select+Start held 2 s is solo. In the hub, the same hold changes your
      character (Select) and then quits to Steam at 1.5 s (Start hold), frames `solo_combo_*`. Keep it, or have
      the hub ignore the Start hold while Select is held?
- [ ] V-01: pick a logo (`art/logo/compare.png`, A/B/C); then the intro logo and `store/` art are redone (Art Director process).
- [ ] V-02: pick a palette (`art/palettes/compare.png`).
- [ ] (Optional, open since 2026-11-10) K-02: keep Start as a 1.5 s hold, or go back to one press.

## Load the build

1. On a `v*` tag, `release.yml` tests, stamps the tag into `config/version`, exports Linux, writes
   `build/openjar.json` (`dev: true` for `-dev` tags) and attaches the zip to the GitHub Release.
2. On the TV box: `openjar-tv/update.sh` installs the release zip as `~/Games/openjar/openjar-launcher/`
   (dev builds as `openjar-launcher-dev/`).
3. The Steam tile "Open Jar Games" runs the launcher binary; it reads every `~/Games/openjar/*/openjar.json`
   (or `$OPENJAR_ROOT`). The first log line is `launcher: version v...`.
4. To try a build by hand: unzip it anywhere and run `./game.x86_64` (add `-- --demo` for the demo tour).

## Earlier passes

Pass 1 (`feature/launch-ready-1`, 2026-11-10/11) and pass 2 (`feature/launch-ready-2`, 2026-11-12) audits are
in git history (`git show 9a18f24:docs/launch-checklist.md`). Every item they fixed is still built; what they
left open is above.
