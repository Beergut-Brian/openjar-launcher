# Vendored: openjar-addons

- Tag: `v0.2.1`
- Commit: `9c916391c64b50c3f7c38773dd16fe00a9c8ec91`
- How: `git -C ~/openjar/openjar-addons archive v0.2.1 | tar -x -C addons/openjar`
- Vendored 2026-11-11 by the Vendor-theme lane (`feature/launcher-vendor-theme-1`); v0.2.0 was
  vendored earlier the same day (`feature/launcher-vendor-addons-1`).
- `theme/openjar_theme.tres` is a byte copy of the launcher's `scenes/ui/theme.tres` (the output of
  `art/gen/build.py`); `tests/test_openjar_addon.gd::test_addon_theme_matches_generator_output` fails
  if they drift.
- Plain file tree, not a submodule. The tag ships no LICENSE file; README.md is kept as shipped.

Do not edit files here. Changes wanted upstream land in `openjar-addons` and come back as a new
vendored tag.
