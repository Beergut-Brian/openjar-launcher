# Plan status: openjar-launcher

The launcher had no PLAN-STATUS.md before this lane; this file starts it with the row this lane
built. Status: built / partial / missing / later. Tests are `tests/<file>.gd::<test>`.

Sources:
- K1 Kaden's chat 2026-11-10: "on the character selector, whenever choosing a new character or
  scrolling through the list of characters, when a character is up on the screen, I'd like it to
  say it's catchphrase once. Give a little audio queue of who they are if that makes sense."

## Chooser

| Row | Source | Status | Proof |
| --- | --- | --- | --- |
| Chooser says the character's catchphrase once (Kaden 2026-11-10) | K1 | built | `scripts/hub/hub.gd` `say_soon` / `cancel_say` / `voice_step` (SAY_SETTLE 0.3 s after the swap lands); `scripts/autoload/Roster.gd` `catchphrase()` (bark fallback, per-player panned voice); `data/roster.json` v0.5.0 with `catchphrase` (17 of 21). Tests: `tests/test_chooser_voice.gd::test_fast_steps_say_only_the_last_after_the_settle`, `::test_the_settle_waits_for_the_swap_to_land`, `::test_standing_still_never_repeats`, `::test_every_settled_step_says_its_character`, `::test_p2_joining_says_their_pick_once`, `::test_two_players_each_on_their_own_voice`, `::test_leaving_cancels_a_pending_line`, `::test_launching_cancels_a_pending_line`, `::test_a_profile_swap_says_who_you_are_now`, `::test_catchphrase_*`, `tests/test_sync_characters.gd::test_vendors_the_catchphrase`. Real runs: `handoff/realrun-1.log`, `handoff/realrun-2.log`, exported build `handoff/exported-run.log` (three fast steps -> one line, the one you stop on). |
