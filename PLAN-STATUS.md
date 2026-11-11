# Plan status: openjar-launcher (Open Jar Games)

Checked 2026-11-10 on `dev` at `d24c9ee` (branch `docs/plan-status-2`). Every row was checked by
the plan-status lane against the code, the test run and real frames, not against lane reports.

- **Test run:** `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode`
  exits 0: 117 test cases, 0 failures. Tests are written `tests/<file>.gd::<test>`.
- **Frames:** `scripts/tools/shots.sh` (Forward+ on the software GPU), fixtures in `tests/fixtures/hub_*`,
  with user data redirected to `.scratch/xdg` so no real save was touched. They live in
  `.scratch/shots/<run>/` in this worktree, which git ignores. Re-run them with the `HUB_DEMO` line in the Notes.
  `boot` = `HUB_DEMO=follow`, hub_8. `walk_p2_chooser` = `follow;1:go:3;5:p2;6:change;7.5:change2`.
  `launch` = `follow;1:go:2;5:slow:0.25;5.2:a`. `return` = `follow;2:return`. `empty` = hub_0, `one` = hub_1,
  `dev` = hub_2 plus a `dev: true` copy, with `launcher.show_dev` on.
- **Status values:** built / partial / missing / superseded / dropped / later (see `~/openjar/lanes/plan-status-format.md`).

Sources (oldest first):
- S1 `~/openjar/BUILD-PLAN-2026-11-09.md`, Kaden's plan: "Build 0: the Open Jar Games launcher", plus the
  launcher lines in "What we were missing" (profiles, store art), "Deploy to the TV box" and "Kid-design constraints".
- S2 `GAME.md` as first written for Build 0 (2026-11-09): Pitch, Players, Core loop, Camera, Art direction,
  Audio, Lanes, First playable, Out of scope, and the 2026-11-09 "Decisions made without Kaden".
- S3 Hub pivot (2026-11-09): the 2D card row was replaced by Jar Island, a 3D hub (commits `b8205f7`, `1d71b82`,
  "D42 a" in `~/openjar/HANDOFF-2026-11-10-morning.md`). GAME.md logs its three follow-up calls under
  "Decisions made without Kaden" (2026-11-09, Gary). It does **not** log the pivot itself; see "Unrecorded" below.
- S4 Kaden chat, 2026-11-10, quoted in GAME.md Controls: "On the launcher, I want to be able to run around."
  Also covers the GAME.md "(free roam)" decisions.
- S5 `~/openjar/CHARACTER-CHOOSER-PLAN-2026-11-10.md`, launcher parts. Kaden: "The launcher should be 'in-line' ...
  It can just be a part of the ready up screen". Also covers the GAME.md "(chooser)" decisions.
- S6 Kaden chat, 2026-11-10: "when a character is up on the screen, I'd like it to say it's catchphrase once."
- No playtest reports yet (`playtests/` holds only `_TEMPLATE.md`).

## Core loop and launching (C)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| C-01 | S1 Build 0 | Boots from a single Steam tile, "Open Jar Games" | partial | `project.godot` `config/name`; tags `v0.0.1-dev.2` … `v0.0.2-dev.4`; `~/openjar/QUEUE-2026-11-10.md` "released + booted" | Only the `(dev)` tile runs the launcher. `origin/main` is still `483fa38` (the template rename), so the stable tile has no real launcher build. |
| C-02 | S1 Build 0, S2 Pitch | Big, loud, fun animated intro: the jar opens, the roster tumbles out, the logo lands with a thump | partial | `scripts/hub/hub.gd` `INTRO_SECONDS` (2.6 s camera glide from the wide shot); frames `boot/t000.4s.png`, `boot/t004.0s.png` | The hub opens with a quiet camera glide over the island. No jar pops open, no characters tumble out, there's no logo, and `intro_thump` is never played. Nothing records a decision to drop the intro. |
| C-03 | S1 Build 0, S2 decision | Intro skippable (A) and played only on the first boot of the day | superseded | `hub.gd:18` "input works throughout"; `LauncherState.intro_date` is no longer called from the hub | Superseded by S3: the glide doesn't block input, so there's nothing to skip. If C-02 comes back, this rule comes back with it. |
| C-04 | S1 Build 0 | Jeff and Chuck appear in the intro; as the roster grows, so does the tumble | partial | `tests/test_hub.gd::test_held_jarlings_are_the_picks_and_jeff_and_chuck_are_residents`, `::test_a_resident_who_is_on_screen_already_is_hidden` | Jeff and Chuck stand on the island as residents. They're hidden while someone plays them, and with the default picks (Jeff + Chuck) both are hidden. The 21-character roster never shows up as a group. |
| C-05 | S1 Build 0 | A horizontal row of game cards, one per installed game | superseded | `tests/test_hub.gd::test_spots_built_from_0_1_2_8_manifests`, `::test_eight_jars_are_sorted_and_each_holds_a_tiny_world`; frame `boot/t000.4s.png` | Superseded by S3: one glass jar per game, in a curved row on the island. |
| C-06 | S1 Build 0, S2 Art | A looping gameplay clip or animated art on each card | built | `scripts/hub/jar_world.gd`; `tests/test_jar_world.gd::test_every_fallback_kind_builds_a_world_with_no_text`; frame `boot/t004.0s.png` | Each jar holds a slowly turning animated diorama. The manifest's `clip` is parsed (`manifest_scanner.gd`) but never played. That's fine for now. |
| C-07 | S1 Build 0, S2 Controls | Dev toggle: hold LB + RB for 1 s to show the `(dev)` builds, which wear a dark lid | built | `tests/test_hold_combo.gd::test_fires_once_after_hold_time`, `::test_one_button_never_fires`; `tests/test_manifest_scanner.gd::test_dev_filtering_and_sorted_order`; `hub.gd` `_toggle_dev` (`ui_toggle`); frame `dev/t003.5s.png` | The dev jar's lid is a dark slate with a beacon (middle jar in the frame). It reads blue-grey more than dark. The hold itself needs a pad, so it isn't in a frame. |
| C-08 | S1 Build 0, S2 Players | Profile picker: two faces, no names | superseded | `tests/test_hub.gd::test_profile_swap_switches_to_that_profiles_picks_in_place`, `::test_launch_hand_off_return_and_profile_pick` | Superseded by S3 and S5: B (solo) switches the save profile in place and you become that profile's pick. No faces, no picker screen. Both profiles start as Jeff + Chuck, so B looks like a pop in place (GAME.md decision). |
| C-09 | S1 Build 0 | Launches the chosen game's binary and passes the profile | built | `tests/test_launch_args.gd::test_binary_gets_profile_then_args`, `::test_command_keeps_its_own_args_first`, `::test_unknown_profile_falls_back_to_p1`; `tests/test_hub.gd::test_launch_hand_off_return_and_profile_pick` | |
| C-10 | S1 Build 0 | Returns to the launcher when the game exits | built | `tests/test_hub.gd::test_launch_hand_off_return_and_profile_pick`; frame `return/t003.6s.png` | The Jarling pops back out and the lid bonks back on. |
| C-11 | S1 Build 0 | Reads `~/Games/openjar/*/openjar.json` written by each game's export | built | `tests/test_manifest_scanner.gd` (9 tests, e.g. `::test_good_binary_manifest`, `::test_malformed_manifests_are_skipped`, `::test_launcher_folders_are_skipped`); `.github/workflows/release.yml` writes `build/openjar.json` | Read from disk only, never from GitHub (S2 decision). |
| C-12 | S1 Build 0 | Born from the template, shipped through the same Release flow | built | `.github/workflows/release.yml` (on tag: test, export, Release); tags up to `v0.0.2-dev.4` | |
| C-13 | S2 Core loop, decision | Back on the last card after a game; last card remembered by slug | built | `tests/test_hub.gd::test_remembered_jar_is_where_you_start`; `tests/test_launcher_state.gd::test_round_trip` | Now "you start at the last jar". |
| C-14 | S2 First playable | Boots on the TV, shows cards for what's installed (Smash Party counts), launches one, comes back. Tag `v0.1.0` | missing | `git tag`: no `v0.1.0`; `origin/main` = `483fa38` | Every piece works on `dev`, but there's no `v0.1.0` and no `dev` → `main` merge after a playtest. Smash Party's jar exists only in fixtures (`tests/fixtures/hub_8/smash-party`). The real kiosk manifest is unverified. |
| C-15 | S2 decision | Start quits to Steam from every screen, ignored while a game runs | built | `hub.gd` `_unhandled_input` (returns early while `Screen.RUNNING`) / `quit_to_steam` (`ui_back`, `Save.flush`, `Audio.quit(0)`); `tests/test_audio_release.gd::test_close_button_goes_through_audio_quit` | See K-02: Start is one press from leaving the TV. |
| C-16 | S2 decision | No games installed: one empty slot; A on it plays `ui_back` and wobbles | built | `tests/test_hub.gd::test_empty_hub_a_wobbles_and_never_launches`; frame `empty/t002.9s.png` | Now one "sleepy" bubbling jar. It's plain next to the dioramas. |
| C-17 | S2 decision | The card row clamps at the ends and wobbles the end card | superseded | GAME.md 2026-11-10 (free roam): "the island edge just stops you" | Superseded by S4. |
| C-18 | S2 decision | B on the card row opens the profile picker | superseded | `tests/test_hub.gd::test_profile_swap_switches_to_that_profiles_picks_in_place` | Superseded by S3 and S5: B swaps the profile in place. |
| C-19 | S2 Out of scope | No downloading, no settings screens | built | `scenes/` holds only `main.tscn`, `hub/`, `players/` and `ui/theme.tres` | |
| C-20 | S3 decision | A game without its own jar world keeps its poster as a small card behind the generated diorama | built | `scripts/hub/jar_world.gd`; frames `boot/t004.0s.png`, `one/t003.0s.png` | |
| C-21 | S3 | A game can ship its own jar world (manifest `jar` field); a bad file never breaks the hub | built | `tests/test_jar_world.gd::test_custom_tscn_is_loaded_stripped_fitted_and_animated`, `::test_custom_glb_is_loaded_and_fitted`, `::test_scenes_with_scripts_or_outside_resources_are_refused`; `tests/test_manifest_scanner.gd::test_jar_field_is_optional` | No real game ships a `store/jar.*` yet (only the `moon-golf` fixture). |
| C-22 | S3 | Launch animation: rattle, lid pops, the Jarling dives in, the camera goes into the jar, the game starts on the last beat; A spam launches once | built | `tests/test_launch_sequence.gd` (6 tests); frames `launch/t005.6s.png`, `launch/t006.4s.png`, `launch/t007.3s.png` | |
| C-23 | S3 decision | The spun-off lid lands on the other Jarling's head (a one-time joke) and is back on the jar on return | built | frame `launch/t006.4s.png` (lid on Chuck's head); `tests/test_hub.gd::test_launch_hand_off_return_and_profile_pick` (lid back on) | |

## Players and free roam (P)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | S2 Players | Either pad drives the launcher | built | `project.godot` `launcher_*` actions on device -1; `tests/test_smoke.gd::test_input_map_has_every_player_action` | |
| P-02 | S3, CLAUDE.md | P2 drops in; rings are P1 green and P2 red, whoever you play | built | `tests/test_hub.gd::test_second_player_takes_the_other_jarling_and_rings_are_by_player`; `tests/test_smoke.gd::test_players_colors_are_green_and_red`; frame `walk_p2_chooser/t006.8s.png` | |
| P-03 | S3 decision | P1 keeps the profile Jarling they picked, P2 gets the other | superseded | `tests/test_hub.gd::test_picks_from_the_shared_file_build_the_jarlings` | Superseded by S5: each player is their own Roster pick. |
| P-04 | S4 | "I want to be able to run around": walk anywhere, all the way over runs | built | `tests/test_hub.gd::test_every_direction_walks_and_jars_are_solid`, `::test_full_tilt_runs_and_a_small_tilt_walks`, `::test_holding_right_walks_past_the_jars_instead_of_snapping`; `tests/test_hub_layout.gd::test_stick_is_analogue_and_full_tilt_runs` | Analogue walk, run at 7 m/s. Not tried with a real pad. |
| P-05 | S4 | Walk up to a jar and it comes into focus: `ui_move`, a bounce, the lid lifts, your pad lights | built | `tests/test_hub.gd::test_walk_away_then_walk_up_to_another_jar_to_focus_it`; `tests/test_hub_layout.gd::test_walking_up_to_the_front_or_the_side_of_a_jar_focuses_it`, `::test_focus_holds_on_at_the_edge_of_its_range`; frame `boot/t004.0s.png` | |
| P-06 | S4 | Jars are solid; the row is one smooth wall; the island edge stops you | built | `tests/test_hub_layout.gd::test_jarlings_bump_into_jars_and_stay_on_the_island`; `tests/test_hub.gd::test_every_direction_walks_and_jars_are_solid` | |
| P-07 | S4 Controls | A away from a jar is a happy cheer; B with two players is a cheer | built | `hub.gd` `press_action` (`ui_move` + `cheer`), B handler (`cheer`) | Code only. No test asserts the cheer. |
| P-08 | S4 decision | `--demo` / `HUB_DEMO=tour` walks from jar to jar and never presses A | built | `tests/test_hub.gd::test_demo_walks_between_jars` | |

## Character chooser (M)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| M-01 | S5 | In-line chooser in the hub, no screen of its own: Select changes your character in place | built | `tests/test_hub.gd::test_the_change_button_cycles_but_not_during_a_launch`; frames `walk_p2_chooser/t006.8s.png` (Astro Ana), `walk_p2_chooser/t008.6s.png` (Big Tiny) | |
| M-02 | S5 | "Left/right swaps who you are" while at the start | superseded | GAME.md 2026-11-10 (chooser): the chooser is on Select | Superseded by S4: the stick walks, so the chooser moved to Select. |
| M-03 | S5 | Remembered across games: shared `players.json`, keyed by profile and slot | built | `tests/test_roster.gd::test_shared_path_is_outside_user`, `::test_file_is_keyed_by_profile`, `::test_set_pick_writes_the_shared_file_and_keeps_other_keys`, `::test_pick_survives_a_relaunch`; `tests/test_hub.gd::test_solo_change_trades_with_the_tag_along_and_is_remembered` | |
| M-04 | S5 | Passes `--p1-char=` / `--p2-char=` on launch and re-reads the file on return | built | `tests/test_launch_args.gd::test_picks_follow_the_profile_as_char_args`; `tests/test_hub.gd::test_launch_passes_the_picks_and_return_rereads_the_file` | |
| M-05 | S5 | Same character twice not allowed: the other player's pick is skipped | built | `tests/test_hub.gd::test_two_players_skip_the_other_pick`, `::test_two_players_and_nobody_free_shakes_and_stays`; `tests/test_roster.gd::test_set_pick_refuses_the_other_players_character`, `::test_next_free_skips_taken_and_wraps` | |
| M-06 | S5 | The roster is playable characters only (no Mole, Dragon, ...); unknown ids fall back to the defaults | built | `data/roster.json` (characters v0.5.0, 21 playable ids, defaults Jeff/Chuck); `tests/test_roster.gd::test_unknown_ids_fall_back`, `::test_defaults_when_nothing_else` | |
| M-07 | S5 | Player colours stay with the slot, not the character | built | `data/roster.json` `player_colours`; frame `walk_p2_chooser/t008.6s.png` (green and red rings under any character) | |
| M-08 | S5 | Swap animation and the character's voice on a swap | built | `hub.gd` `change_character` (poof + `CHANGE_SOUND`), catchphrase in M-12 | The swap sound is still the stand-in `intro_pop`. The voice is the catchphrase (M-12). |
| M-09 | S5 | New characters go straight into the roster | built | `data/roster.json` (21); `assets/characters/*/`; frames show Astro Ana and Big Tiny | Four characters have no `voice/` folder at all (`assets/characters/{jeff,chuck,bloom,old_reel}`), and Jeff and Chuck are the default picks. |
| M-10 | S5 decision | Solo, the tag-along friend trades with you; a resident who is on screen already is hidden | built | `tests/test_hub.gd::test_solo_change_trades_with_the_tag_along_and_is_remembered`, `::test_a_resident_who_is_on_screen_already_is_hidden` | |
| M-11 | S5 decision | The hint ("Select  Change") fades in by your ring after 1.4 s standing still; the name tag shows for 1.5 s after a swap | built | `tests/test_hub.gd::test_the_hint_shows_by_the_ring_when_you_stand_still`; frames `boot/t004.0s.png`, `walk_p2_chooser/t006.8s.png` | It's words, not a glyph (see K-01). With no pad connected it reads "Tab  Change" or "/  Change". |
| M-12 | S6 | The chooser says the character's catchphrase once when it lands | built | `tests/test_chooser_voice.gd` (15 tests, e.g. `::test_fast_steps_say_only_the_last_after_the_settle`, `::test_standing_still_never_repeats`, `::test_p2_joining_says_their_pick_once`); `tests/test_sync_characters.gd::test_vendors_the_catchphrase` | 17 of 21 characters have `voice/catchphrase.ogg`. Jeff, Chuck, Bloom and Old Reel have no voice files, so they say nothing (see M-09). |

## Audio (A)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| A-01 | S2 Audio | Intro sting: jar pop, tumble, logo thump | partial | `assets/audio/sfx/intro_pop.ogg`, `intro_thump.ogg` | The sounds exist, but the hub's opening is silent apart from the music. `intro_thump` is never played. Follows C-02. |
| A-02 | S2 Audio | Characters bark as they land | partial | `scripts/autoload/Roster.gd` `bark()` | There's no landing (C-02). Characters speak only on a chooser change, a P2 join or a profile swap. |
| A-03 | S2 Audio | `ui_move`, `ui_confirm` | built | `tests/test_audio_cues.gd::test_cues_md_lists_the_launcher_cues`, `::test_every_cue_resolves_to_loadable_streams`, `::test_ui_move_has_variants` | |
| A-04 | S2 Audio | A soft loop under the card row, stopped while a game runs | built | `tests/test_audio_cues.gd::test_card_row_loop_loops_when_played`; `hub.gd` `Audio.music("card_row_loop")` / `stop_music()` | Still the 2D-era loop, 18 s. It loops a lot in a free-roam hub. |
| A-05 | S3 | One sound per launch beat (rattle, pop, jump, lid, splash, launch) and a pop-out on return | partial | `hub.gd` launch beats; `assets/audio/CUES.md` | Five of the cues are marked "hub lane placeholder" synths. |

## Visuals (V)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| V-01 | S2 Art, Open questions | "Open Jar Games" wordmark and jar icon; Kaden approves one of three | partial | `art/logo/option_a.svg`, `option_b.svg`, `option_c.svg`, `compare.png` | There's no recorded pick, and no logo appears anywhere in the hub (only in `store/grid.png`). |
| V-02 | S2 Art | The master palette is born here: three options, Kaden picks | partial | `art/palettes/candy_pop.json`, `cool_arcade.json`, `warm_toybox.json` | There's no recorded pick. The hub uses its own palette (`docs/hub-art-direction.md`). |
| V-03 | S2 Camera, Art | 2D flat vector, a fixed 2D UI at 1080p, intro via `AnimationPlayer` | superseded | `scenes/hub/hub.tscn` (3D, Forward+); commit `1d71b82` | Superseded by S3, but GAME.md still describes the 2D launcher (see "Unrecorded"). |
| V-04 | S2 Lanes | The launcher's theme becomes the `openjar-addons` theme | partial | `scenes/ui/theme.tres` | `addons/openjar/` (the CLAUDE.md submodule) isn't in this repo, and the theme is barely used by the 3D hub. |
| V-05 | S2 Lanes | Profile faces | superseded | see C-08 | |
| V-06 | S1 What we were missing | Store art: 600x900 grid, 920x430 hero (and `clip.mp4`) | partial | `store/grid.png` (600x900), `store/hero.png` (920x430), both checked | Both still show the 2D-era logo and stand-ins, not Jar Island. There's no `store/clip.mp4`. |
| V-07 | S3 | Jar Island at magic hour (`docs/hub-art-direction.md`) | built | frames `boot/t000.4s.png`, `boot/t004.0s.png` | |
| V-08 | S3 art direction, CLAUDE.md | Green and red belong to the players only | partial | frame `dev/t003.5s.png` | The Smash Party fixture jar's lid comes out bright red (its accent comes from its poster), right next to P2's red. |
| V-09 | S2 decisions | Dark costume parts get an inner stone rim; green/red deuteranopia check is advisory | superseded | `art/palettes/checks.py` | The 2D stand-ins went in `1d71b82`. Characters are now the library's 3D models. |

## Systems (S)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| S-01 | S1 What we were missing | The launcher owns the profile and passes `--profile=`; games read it with or without `--` | built | `tests/test_launch_args.gd::test_save_reads_profile_with_or_without_separator`; `tests/test_launcher_state.gd::test_bad_stored_profile_falls_back` | |
| S-02 | S2 decision | Minimise while a game runs, restore fullscreen on exit | partial | `tests/test_window_policy.gd::test_minimise_on_start_restore_on_exit`, `::test_launcher_default_is_minimise` | GAME.md: "Untested on the TV." |
| S-03 | S2 decision | A in the picker holds the happy face for 0.35 s | superseded | see C-08 | |
| S-04 | S2 decision | Fallback art never repeats on neighbours; a game keeps its own | built | `tests/test_jar_world.gd::test_fallback_kind_is_stable_and_neighbours_differ` | Carried over from cards to jar dioramas. |
| S-05 | S1 Deploy | `dev` builds show as a separate `(dev)` entry | built | see C-07; `.github/workflows/release.yml` writes `dev=true` for `-dev` tags | |

## Kid design (K)

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| K-01 | S1 checklist, S2 Out of scope | Nothing a kid has to read | partial | frames `boot/t004.0s.png`, `walk_p2_chooser/t006.8s.png` | The "Select  Change" hint and the character name tags are text. Name tags are decoration. The hint teaches with a word: it needs a Select-button glyph. |
| K-02 | S1 checklist | At most three buttons matter; the rest are harmless | partial | GAME.md Controls; `hub.gd` `quit_to_steam` | Move, A, B, Select, LB+RB and Start all do something. Start leaves the launcher in one press, which a 5-year-old will find. |
| K-03 | S1 checklist, CLAUDE.md #7 | A sound and a visual on every input | built | `hub.gd` `Audio.play` on focus, A, B, Select, the head shake, the dev toggle, quit, every launch beat and the return; `tests/test_audio_cues.gd` | |
| K-04 | S1 checklist | P2 drops in and out with no menu | built | `tests/test_hub.gd::test_second_player_takes_the_other_jarling_and_rings_are_by_player`; `tests/test_chooser_voice.gd::test_p2_joining_says_their_pick_once` | |
| K-05 | S1 checklist | One camera that never loses a player | partial | `hub.gd` `_update_camera` ("frames the held Jarlings"); frame `walk_p2_chooser/t008.6s.png` | No test or frame has the two players at opposite ends of the island. |
| K-06 | S1 checklist | 60 fps at 1080p on the GTX 1060 | missing | none | Frame rates on the software GPU mean nothing. Not measured on the TV. |
| K-07 | S1 checklist | Cold start to playing in under 10 s | partial | `hub.gd` `_report_cold_start`; the test log printed "interactive" after 2.3 to 10.1 s headless | Not measured on the TV. |
| K-08 | S1 checklist | P1 green, P2 red everywhere | built | `tests/test_smoke.gd::test_players_colors_are_green_and_red`; frames `walk_p2_chooser/*` | See V-08 for the red jar lid. |
| K-09 | S1 checklist | Nothing scary | built | frames `boot/*`, `launch/*` | |
| K-10 | S1 checklist | Saves at every stopping point | built | `tests/test_hub.gd::test_picked_jarling_is_remembered`, `::test_remembered_jar_is_where_you_start`; `tests/test_launcher_state.gd::test_round_trip` | |
| K-11 | CLAUDE.md #9 | Credits for every asset | built | `assets/CREDITS.md` (139 lines, a "Characters (synced from openjar-characters v0.5.0)" section) | |

## Unrecorded: GAME.md contradicts the plan

- **The hub replaced the 2D launcher** (S3: `b8205f7`, `1d71b82`, "D42 a") with no entry in GAME.md. The Pitch,
  Core loop ("profile picker → card row"), Camera ("Fixed 2D UI") and Art direction ("2D, flat vector",
  "Cards: 600x900") still describe what was removed. Only the Controls table and the decisions describe the hub.
- **The intro** (S1: "big, loud, fun animated intro ... the jar opens, the roster ... tumbles out, the logo lands")
  became a camera glide. Nothing records a decision to drop it.
- **The logo and palette picks** are still open questions in GAME.md, with no recorded pick.

## Next up

Ranked by how much Kaden will notice in play. S = an hour or so, M = a lane session, L = several sessions.

1. **C-02 / A-01 / A-02 / C-04: a real opening.** The jar pops, the roster tumbles out with barks, the logo lands with a thump. It's the first thing anyone sees, and right now it's a quiet glide. Needs V-01 (logo pick) first. **M**
2. **M-09: voices for Jeff, Chuck, Bloom and Old Reel.** None of them has a `voice/` folder. Jeff and Chuck are everyone's default picks, so the first characters Kaden sees in the chooser are the silent ones. Library work, then a resync. **M**
3. **K-02: Start quits the launcher in one press.** A kid will leave the TV by accident. Make it a hold, or ignore it with two players. Needs Kaden's OK because it changes a GAME.md decision. **S**
4. **C-14 / C-01: `v0.1.0` and a stable tile.** `main` is still the template, so the main "Open Jar Games" tile has no launcher. Playtest the dev build, merge to `main`, tag. **S** (after a playtest)
5. **K-01 / M-11: swap the "Select  Change" text for a button glyph.** **S**
6. **A-05 / A-04: real launch cues and a hub music loop.** The cues are placeholder synths, and the 18 s card-row loop plays for the whole free roam. **M**
7. **V-08: keep jar lids off player red and green.** Clamp poster accents away from `#e4393c` / `#3cc24a`. **S**
8. **K-06 / K-07 / S-02: measure on the TV.** Frame rate, cold start and the minimise-and-restore. Kaden won't notice unless it fails. **S**
9. **V-06: store art for Jar Island,** plus a `clip.mp4`. Seen only in the Steam grid. **S**
10. **V-04: move the theme into `openjar-addons`.** Kaden won't see this. **S**
11. **K-05: test two players at opposite ends of the island** (frame plus test). **S**
