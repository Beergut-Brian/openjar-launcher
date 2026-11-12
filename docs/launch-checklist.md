# Launch checklist: openjar-launcher

Launch-readiness lane, 2026-11-10/11. The audit was written before any fix (every row in it is now
fixed or listed below); then what's verified on the producer box, what needs the TV box, what needs
Kaden and what needs Gary. Row ids are PLAN-STATUS ids.

## Second-pass audit (2026-11-12, `feature/launch-ready-2`, before any fix)

Every PLAN-STATUS row re-checked against `dev` at `52e3ecf` (after gap-close-3, vendor-addons-1,
vendor-theme-1 and the roster v0.5.3 resync), not against the first pass. `playtests/` still holds only
`_TEMPLATE.md`, so "the most recent playtest sections" are the newest rows (gap-close-3, V-04, the
v0.5.3 resync), re-checked in real frames. Baseline: `scripts/tools/test.sh` exits 0, 170 test cases.

| Row | Status before | What's rough or missing on dev now | Plan |
| --- | --- | --- | --- |
| M-09 / M-12 / A-02 | built | v0.5.3 gave all 22 characters a `voice/` (8 barks + catchphrase), Jeff, Chuck, Bloom and Old Reel included; the rows (and L-06) still say four are silent, and no test pins the real roster's voices | Test: every real roster character has loadable barks and a catchphrase; check Jeff and Chuck speak in a real session log; fix the notes. |
| K-11 | built | `assets/CREDITS.md` voice section says "17 of the 21 playable characters, the four without a `voice/` folder say nothing" | Fix the text (22 of 22); test it. |
| L-06 | built | lists "four silent characters" as a left-over | Update. |
| (new) test noise | — | 13 engine `ERROR: Parameter "material" is null` lines in the gdUnit4 run (dummy renderer, every test that swaps a character); the headless soak with the real roster has none | Find the cause; fix if it's ours. |
| GAME.md | — | the chooser decision still says "Stand-in sound `intro_pop` until characters have recorded barks" (superseded by the launch-ready swap cue and the v0.5.3 voices) | Hermes's file: listed, not edited. |
| V-01 / V-02 | partial | no logo / palette pick | Needs Kaden. |
| V-06 | built | store art carries the option A logo stand-in | Re-shoot after V-01 (Kaden). |
| K-06 / K-07 | missing / partial | 60 fps and cold start on the GTX 1060 | Needs the TV box. |
| A-04 | built | 18 s loop repeats in free roam | Audio-lane option, not a gap; listed. |
| everything else | built / superseded | re-checked: tests, real frames of the full session, soak, export | Re-verify, no change expected. |

## First-pass audit (2026-11-10, before any fix)

`playtests/` holds only `_TEMPLATE.md`: there is no playtest report yet, so "the most recent
playtest sections" are the newest PLAN-STATUS rows (gap-close-1 and -2), re-checked in real frames
below. Every PLAN-STATUS row that is not built, superseded, dropped or TV-only, plus every built
row whose notes say something is rough:

| Row | Status before | What's rough or missing | Plan |
| --- | --- | --- | --- |
| C-01 | partial | `main` is still the template; the stable tile has no launcher | Can't from a lane (no push; `dev` → `main` is Hermes after a playtest). Needs-Gary. |
| C-14 | partial | no `v0.1.0`; Smash Party never run with a real browser and pad | Needs the TV box + the tag. |
| C-07 | built | the dev jar's lid "reads blue-grey more than dark" | Fix: darker lid, frame. |
| C-16 | built | the empty "sleepy" jar is plain | Check in a frame; polish only if it reads wrong. |
| P-07 | built | "No test asserts the cheer" | Fix: test (sound + hop). |
| M-08 | built | the swap sound is the stand-in `intro_pop` | Fix: its own cue `chooser_swap`. |
| M-09 / M-12 / A-02 | built | Jeff, Chuck, Bloom and Old Reel have no `voice/` | Can't here: `assets/characters/` is resync-only. Needs-Gary (library voices, then resync). |
| A-04 | built | the 18 s loop repeats a lot | Audio lane; listed (no redesign here). |
| A-05 | built | six cues labelled "hub lane placeholder" | They are finished, seeded synth cues with their own design; the label goes, restyle stays an Audio-lane option. |
| V-01 / V-02 | partial | no logo / palette pick | Needs-Kaden. |
| V-04 | partial | the theme isn't in `openjar-addons` | Another repo; Kaden never sees it. Needs-Gary. |
| S-02 / K-06 / K-07 | partial / missing | window restore, 60 fps, cold start on the real box | Needs the TV box. |
| K-11 | built | voices not credited to their tool; no ElevenLabs line | Fix: a Character voices section. |
| (new) drop-out | — | P2's pad going away was silent | Fix: `player_leave` cue + a hop (CLAUDE.md #7). |
| (new) quit mid-launch | — | Start held to the end during the launch animation quit the hub while the GO beat could still start the game behind it | Fix: never start a game once quitting; test. |
| (found later) quit mid-intro | — | quitting during the intro leaked the crowd's voice streams at exit ("resources still in use") | Fixed: `Audio.quit` pauses the tree and silences every player in it; test. |
| (found later) shipped docs | — | GAME.md (Kaden's name, quotes) and the store art were packed into the export, unused | Fixed: export filter. |
| (new) version | — | no version anywhere; `config/version` is the template's `0.0.1` | Fix: release.yml stamps the tag; a quiet corner label; the boot log line. |
| (new) README | — | still the template's README | Fix: launcher README with play instructions. |
| (new) GAME.md Controls | — | two stale rows (one-press Start, a second LB+RB row) contradict the gap-close decisions | Fix the two rows; the stale 2D Pitch/Core loop/Camera/Art sections stay listed for Hermes. |

## Verified on the producer box (2026-11-10/11, `feature/launch-ready-1`)

- **Tests:** gdUnit4 `--ignoreHeadlessMode --continue`, all green (`handoff/test-output.txt`), including
  `tests/test_launch_ready.gd` (8 tests: the whole session, quit from the intro, quit mid-launch,
  P2 drop-out, the swap cue, the cheer, the version label, quitting mid-intro silences every voice).
- **Session flow in real frames** (`handoff/frames/flow_*`): intro (the roster tumbles out, logo
  thump, glide out), the chooser with P2 in (name tags, hints), P2 dropping out, the quit badge
  filling, launch (rattle, flash, game runs) and return (pop out, lid back). Dev jar lid and the empty
  hub re-checked (`c07_*`, `c16_*`).
- **Soak:** 30 min headless (leaks) and 30 min rendered at 960x540 (frame time), scripted launches,
  returns, swaps, P2 in and out; numbers in `handoff/REPORT.md`.
- **Export:** exported, zipped like release.yml, unzipped, booted: launch, return, Start-hold quit,
  exit 0, zero errors. Design docs, store art, kiosk files and the template player scene are out of
  the pack; scripts ship as binary tokens (no comments).
- **Hygiene:** version from the release tag (corner label + log); credits for every asset including
  the ElevenLabs voices; README play instructions; no personal info or real places in shipped files.

## Needs the TV box (the weekend)

- [ ] K-06: F3 on the GTX 1060, 1080p: 60 fps in the hub, the intro (22 characters) and a launch.
- [ ] K-07: cold start under 10 s: read the `launcher: interactive` line (the box's software GPU gives
      6.5 to 11.8 s depending on load, most of it first-frame pipeline compiling, so only the TV settles it).
- [ ] S-02: one launch and return: read the `launcher: window:` lines (minimised while the game runs,
      fullscreen and in front after). Already proven under openbox on the box: `docs/evidence/s02-window-log.txt`.
- [ ] C-14: install Smash Party (`kiosk/smash-party/install.sh`), launch it, play with a pad in the
      browser, quit it with the browser's close and with the 2 s Start hold.
- [ ] Real pads: P2 drops in with a button, drops out by switching the pad off (the "bye-bye"),
      Select changes character per pad, LB+RB 1 s shows the dev jars, Start held 1.5 s quits to Steam.
- [ ] The corner shows the release tag (`v…`) and is small enough to ignore on the TV.

## Needs Kaden

- [ ] V-01: pick a logo (`art/logo/compare.png`, options A/B/C). Then swap
      `assets/sprites/logo/intro_logo.png` and re-shoot `store/` (recipe in the gap-close report).
- [ ] V-02: pick a palette (`art/palettes/compare.png`).
- [ ] (Optional) K-02: keep Start as a 1.5 s hold, or one press back.

## Needs Gary

- [ ] Voices for Jeff, Chuck, Bloom and Old Reel in `openjar-characters` (cue names the launcher
      uses: `catchphrase`, `cheer`, `join`, `ready`, `swap_in`, `win`), then
      `scripts/tools/sync_characters.sh`. Until then they land and swap silently.
- [x] C-01 / C-14: `dev` → `main`, tag `v0.1.0`, boot the stable tile (done 2026-11-10: v0.1.0, v0.1.1
      booted; `v0.1.2` tagged at `ae25b42`; gap-close-3 sync).
- [ ] V-04: move `scenes/ui/theme.tres` into `openjar-addons` (another repo; Kaden never sees it).
- [ ] A-04 (optional, Audio lane): a longer hub loop; the 18 s loop repeats a lot in free roam.
