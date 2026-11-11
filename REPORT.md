# Report: launcher-vendor-theme-1 (Systems lane, re-vendor the shared theme)

Branch `feature/launcher-vendor-theme-1` (off `dev` at ea2a417). Not pushed. Status: **done**.

## What changed (3 commits)

- `3f64360 launcher: re-vendor openjar-addons v0.2.1 (ships the house theme)`:
  `addons/openjar/` replaced by `git -C ~/openjar/openjar-addons archive v0.2.1` (9c91639), a plain
  tree, no submodule. The only launcher-kept file there, `addons/openjar/VENDORED.md`, was kept and
  updated (tag v0.2.1, commit 9c916391c64b…, and a note that the theme is a byte copy of the generator
  output). The diff against v0.2.0 matches the upstream `v0.2.0..v0.2.1` diff exactly: CHANGELOG.md,
  README.md, plugin.cfg, theme/.gitkeep (removed), theme/README.md, theme/openjar_theme.tres,
  tests/project/suites/test_theme.gd(.uid).
- `a0d2ce1 launcher: load the addon theme, pin it to the generator output`:
  - `tests/test_openjar_addon.gd`: `test_addon_version_is_0_2_0` became `test_addon_version_is_0_2_1`;
    `test_theme_resource_loads` loads `res://addons/openjar/theme/openjar_theme.tres` only (fallback
    to `scenes/ui/theme.tres` removed, doc comment updated); new
    `test_addon_theme_matches_generator_output` (the addon copy and `scenes/ui/theme.tres` are byte-identical).
  - `art/prompts/README.md` (the generator's README; `art/gen/` has none): says `scenes/ui/theme.tres`
    is copied into `openjar-addons` as `theme/openjar_theme.tres`, how to round-trip a change, and that
    the drift test goes red until it is re-vendored.
- `dac8f26 launcher: PLAN-STATUS: V-04 built (addon v0.2.1 theme)`: V-04 row, log line, totals, next-steps item 6.

`scenes/ui/theme.tres` and `art/gen/build.py` are unchanged (the vendored theme is already byte-identical).
No scene sets a theme, so there is no visual change and no screenshots.

## Tests

`rm -rf .godot; godot --headless --path . --import` (exit 0), then `scripts/tools/test.sh` (user data
under `.scratch/`): **exit 0, 170 test cases, 0 failures** (was 169; +1 new test). Log:
`handoff/test-output.txt` (gitignored, like earlier lanes). No test writes a settings file in this change.

## PLAN-STATUS IDs moved

- **V-04**: partial → built. Totals now 79 rows: 64 built, 11 superseded, 3 partial, 1 missing.

## Notes

- The clean import extracted embedded textures from the character `.glb` files as untracked
  `assets/characters/*/*_face.png` etc. They are import by-products, not part of this change; I left them
  uncommitted and didn't delete them.
- Upstream `ui/` and `launcher/` are still `.gitkeep` (no shared input/save code); that is outside V-04.
