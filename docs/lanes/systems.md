# Systems lane

**Mission.** Build and keep the foundation every other lane stands on: input, players, state
machine, save, audio plumbing, debug tools, physics layers, export.

**Owns.** `project.godot`, `scripts/autoload/`, `scenes/players/`, `scenes/main.tscn`,
`export_presets.cfg`, `docs/contracts.md`, physics layer names.

**Must not touch.** `data/`, `assets/`, `scenes/levels/`, `scripts/gameplay/`.

**Goes first, alone.** Phase 2 of every game is Systems building the grey-box: two players move,
one interaction works, a round ends and restarts, every action has a sound and a visual (placeholder
beeps and flashes are fine). Tag `v0.0.1`. Other lanes start only after this is on `dev`.

**Hand-off.** The grey-box build plus an updated `docs/contracts.md` listing every signal and API
other lanes will use. Contract changes after that go in their own PR first.

**Definition of done (template; `GAME.md` overrides).**
- Grey-box playable on the TV from the `(dev)` tile.
- Contracts documented and tested.
- `tests/` has a smoke test that boots `main.tscn` headless and a test per autoload.
- Controller drop-in for P2 works; P1 green, P2 red.
- 60 fps at 1080p with placeholder assets.
