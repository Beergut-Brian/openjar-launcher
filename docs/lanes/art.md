# Design / Art lane

**Mission.** Make it look like an Open Jar game, in this game's technique, without ever
blocking Gameplay.

**Owns.** `assets/sprites`, `assets/models`, `assets/fonts`, `art/` (palette, prompt packs),
`scenes/ui/theme.tres`, shaders, particle scenes, `store/` (grid, hero, clip).

**Must not touch.** `.gd` files outside `art/`. If a sprite needs code, PR to the owning lane.

**Depends on.** `docs/art-direction.md` filled in for this game; the chosen palette; the
character library for any recurring character.

**Rules.**
- Placeholders first: coloured boxes at final size and pivot, named as the final asset.
- Real assets swap in by matching file name. Never rename a placeholder.
- Generate with the prompt pack in `art/prompts/`; clean and palette-snap before committing.
- Every asset gets a line in `assets/CREDITS.md`.
- Nothing recognisable from existing IP. Original designs only.
- Library characters are rendered from their reference sheets; new renderings go back to
  `openjar-characters` by PR.
- Attach a screenshot (F12) to every visual PR.

**Hand-off.** Final assets, theme, store art, and an updated `art/prompts/` that reproduces the look.
