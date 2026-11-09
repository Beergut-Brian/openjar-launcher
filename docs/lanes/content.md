# Content lane

**Mission.** Fill the game with data: upgrades, enemies, waves, items, levels, dialogue —
as `.tres` resources or JSON in `data/`, never as code.

**Owns.** `data/`.

**Must not touch.** Code and assets. If the data needs a new field, PR the schema change to
Gameplay first.

**Depends on.** The data schemas Gameplay defines (`scripts/gameplay/*_data.gd` resource
classes) and the loop in `GAME.md`.

**Rules.**
- Humour first. Read the "Pitch" in `GAME.md` before writing a single row.
- Each row gets a one-line human description in its `description` field; Hermes uses these
  for release notes.
- Balance by table, not by feel: keep a `data/BALANCE.md` with the intended curve
  (e.g. "normal path reaches space in 10 to 12 picks").
- Reference library characters by id from `characters.json`; never invent a recurring
  character here.

**Hand-off.** Data files plus `data/BALANCE.md`.
