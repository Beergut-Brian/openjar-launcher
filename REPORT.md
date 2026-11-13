# Report: press-answers-adopt-1 (press-answers adoption lane)

Branch `feature/press-answers-adopt-1` (off `dev`; `git fetch origin && git merge origin/dev`: already up to date at
`cbe8125`). Not pushed.

**Status: blocked. Nothing to adopt yet.** I changed no code, wrote no tests, took no frames and moved no
PLAN-STATUS rows. Two of the brief's starting assumptions don't hold for this repo.

## 1. The template fix is not on the template's `dev`

- The fix is commit `9d99f29` ("template: every menu press answers (honk refusal + wobble)") in
  `~/openjar/openjar-template`. It is only on the local branch `feature/template-press-answers-1`.
- `git merge-base --is-ancestor 9d99f29 origin/dev` says it is **not** in `origin/dev`. The template's `dev` is at
  `f737145`, the pause-door PR #16 merge.
- In `origin/dev`, `menu_input.gd`, `menu_item.gd`, `icon_button.gd`, `lobby.gd`, `pause_menu.gd` and
  `settings_panel.gd` have no refusal or wobble code (`git grep -i "refus|honk|wobble"` finds nothing).
- I could not check GitHub: `ls-remote` needs credentials this box doesn't have.

## 2. The launcher has no template menu kit and no menu screens

| Screen in the brief | In this game? | Notes |
| --- | --- | --- |
| Start menu / lobby (`lobby.gd`) | no | `scenes/main.tscn` boots straight into the 3D hub (`scenes/hub/hub.tscn`). The chooser is in-line in the hub (S5). |
| Pause menu (`pause_menu.gd`) | no | `Game.gd` only pauses in `State.PLAYING`, and the launcher never starts a round. PLAN-STATUS FR-6 says the same: "The launcher has no menu". |
| Settings (`settings_panel.gd`) | no | Not in the repo. `Save.gd` keeps only `LauncherState`. |
| Leave question (`confirm_dialog.gd`) | no | You quit by holding Start or Escape (quit meter), with no dialog. |
| `scenes/ui/kit/*`, `icon_button.gd` | no | `scenes/ui/` holds only `theme.tres`. The vendored `addons/openjar/ui/` is empty. |
| **Hub** (this game's own screen; the template has nothing like it) | yes | Silent presses already refuse **with sound only** (below). |

So the copy-and-merge step (goal 1) has nothing in this game to land in. The only adoption would be importing the
whole lobby, pause and settings kit as new screens. That is a design change (GAME.md 2026-11-10: "the hub has no
ready screen"), not a fix to adopt.

## 3. The hub, the game's own screen (goal 2): sound yes, visual no

`scripts/hub/hub.gd` `refuse()` already makes every press answer (FR-4, built and tested in
`tests/test_hub_feel_rules.gd`): X, Y, stick clicks and stray keys; A, B and the chooser mid-jump, mid-swap,
during the intro and during a launch. It plays `ui_back`, the game's documented "can't do that" cue (CUES.md), at most
once a frame. LB and RB tick (`ui_move`) because together they are the dev hold.

**Gap:** a refusal has **no visual**. CLAUDE.md #7 asks for a sound and a visual on every press, and the template
pairs the honk with a wobble. I didn't add one, for three reasons:
- `refuse()` doesn't know which player pressed. `_input` would need to map the event's device to a player first.
- The obvious visual is `jarling.shake()`, a tween on `_flip.rotation.z`. Most refusals happen *because* that
  Jarling is mid-jump, mid-swap or launching, and a shake on top of those animations needs care and a frame check.
  That is hub feel code, which this brief puts out of bounds ("do not change gameplay code").
- The template's `honk` cue needs a game-side `honk.ogg` (audio lane). Until then, `ui_back` is this game's
  refusal sound.

**Suggested follow-up** (its own lane, hub/systems owner): in `refuse(player)`, shake that player's Jarling only
when it isn't busy or swapping, and flash the hint otherwise. Pin it with a test per refusal path (`refusals`
plus a shake counter), and take frames with `HUB_DEMO`.

## Tests, frames, PLAN-STATUS

- **Tests:** none added. With no code changed, I didn't re-run the suite. The last recorded run is FR3-1: 213 test
  cases, 0 failures.
- **Frames:** none. No pause menu or start menu exists to capture, and `handoff/frames/` is unchanged.
- **PLAN-STATUS: no rows moved.** This game's FR-5 is "the hub hint changes with context, with controller glyphs",
  already built. There are no FR-5 menu rows to move. Moved IDs: none.

## What would unblock it

1. Merge `feature/template-press-answers-1` into the template's `dev`. Then a decision for Hermes or Kaden: should
   the launcher get template menus at all? Today it deliberately has none.
2. Or re-scope this lane to the hub-only visual above, with hub feel code explicitly allowed.

## Commits

- `docs: press-answers adoption blocked, no menus to adopt` (this report; `handoff/handoff.json` sits in the worktree, uncommitted, because `handoff/` is in the local git exclude).
