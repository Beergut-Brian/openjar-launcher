# Lanes

One Claude Code session per lane, each on its own `feature/<lane>-*` branch, each PR-ing into `dev`.
Hermes decides which lanes are active for a game (see `GAME.md`). A lane reads `CLAUDE.md`,
`GAME.md`, `docs/contracts.md` and its own file here before starting.

| Lane | Owns | Never touches |
| --- | --- | --- |
| systems | `project.godot`, `scripts/autoload/`, `scenes/players/`, `scenes/main.tscn`, physics layers, `docs/contracts.md` | `data/`, `assets/`, `scenes/levels/` |
| gameplay | `scenes/levels/`, `scripts/gameplay/`, camera, round flow, scoring | `scripts/autoload/`, `assets/`, `data/` schemas |
| art | `assets/sprites`, `assets/models`, `assets/fonts`, `art/`, `scenes/ui/theme.tres`, shaders, particles, `store/` | any `.gd` outside `art/` |
| content | `data/` | code, assets |
| audio | `assets/audio/`, `Audio.gd` cue names | gameplay code beyond adding `Audio.play` calls |
| reviewer | merges to `dev`; nothing else | authoring code |

Hermes (the producer) owns `GAME.md`, `playtests/`, lane assignments, `dev` → `main`, Releases.
