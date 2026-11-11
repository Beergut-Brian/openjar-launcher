# Launch checklist: openjar-launcher

Launch-readiness lane, 2026-11-10. The audit below was written before any fix; the verified / TV / Kaden lists follow it once done.

## Audit (before any fix)

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
| (new) version | — | no version anywhere; `config/version` is the template's `0.0.1` | Fix: release.yml stamps the tag; a quiet corner label; the boot log line. |
| (new) README | — | still the template's README | Fix: launcher README with play instructions. |
| (new) GAME.md Controls | — | two stale rows (one-press Start, a second LB+RB row) contradict the gap-close decisions | Fix the two rows; the stale 2D Pitch/Core loop/Camera/Art sections stay listed for Hermes. |
