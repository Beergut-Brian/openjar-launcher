# The roster: who players can be (launcher copy)

**Launcher notes.** `scripts/autoload/Roster.gd` and `scripts/tools/sync_characters.sh` are the
template's (`openjar-template` `dev`, after the chooser merge) with three small additions listed in
`docs/contracts.md` "Launcher additions": `profile_override` (the hub's `p1`/`p2` profile picks the
`players.json` entry, while the launcher's own `Save` keeps its single profile), `set_pick(..., bump)`
(the solo hub chooser trades with the tag-along) and a test-run picks path. There is no lobby here:
the chooser is in-line in the hub (Select / Back), see `GAME.md` "Controls". Sections 3 and later
below describe the template's lobby and game spawning; in the launcher, `HubJarling` loads
`Roster.info(id).glb` directly (`hub.gd` `apply_characters()`).


Design: the character chooser plan (Kaden, 2026-11-10). Library side: `openjar-characters`
`docs/roster.md`. This page is the game side: how a game built from this template gets the
playable characters, remembers picks and spawns them. API: `docs/contracts.md` "`Roster`".

## 1. Vendoring the characters

```
scripts/tools/sync_characters.sh ~/openjar/openjar-characters v0.5.0
```

For every id in that tag's `characters.json` `roster` (playable characters only; residents such as
the Mole or the Dragon never appear) it copies into `assets/characters/<id>/`:

| File | What |
| --- | --- |
| `<id>.glb` | the 3D master (standard Jarling: `idle`, `run`, `kick`, `cheer`, ten gear slots). Godot extracts `<id>_*.png` textures on import; commit them too |
| `pixel.png` | the pixel form, front view at native size (40x32), drawn by the library's own sprite code (needs `python3` + Pillow) |
| `voice/*.ogg` | recorded barks (the top-level cues only) |
| `voice/catchphrase.ogg` | the chooser's catchphrase: `voice/lib/catchphrase_big.ogg` only (nothing else from `lib/`, to keep exports small); written as `"catchphrase"` in `data/roster.json` (`""` without one). Not a bark |

and writes `data/roster.json` (roster order, names, defaults, player colours, `res://` paths, the
tag) and the characters block in `assets/CREDITS.md`. It reads the tag with `git show` (Git LFS
files are smudged), so the library checkout can be on any branch. Each folder it writes gets a
`.synced` marker; a synced folder whose id left the roster is removed, anything else in
`assets/characters/` is left alone with a warning. **New characters: rerun with the new tag, import, commit. No code change.**

Current: `v0.5.0`, 21 characters, Jeff (P1 default) and Chuck (P2 default); 17 have a catchphrase (not Jeff, Chuck, Bloom, Old Reel).

## 2. Who each player is

`Roster` (autoload) resolves each slot at start, first hit that is in this game's roster:

1. `--p1-char=<id>` / `--p2-char=<id>` (the launcher passes them)
2. the shared picks file, `players.json[<profile>]["P1" | "P2"]`
3. `defaults` (Jeff, Chuck)
4. the first roster id the other player hasn't got

Unknown ids (a newer library's character, a resident, a typo) are skipped. Never the same character
twice: a clash moves P2 to the next free one.

## 3. The shared picks file

`OS.get_data_dir() + "/openjar/players.json"`, Linux `~/.local/share/openjar/players.json`,
outside every game's `user://`. Keyed by the launcher's save profile (`Save.profile`, from
`--profile=`), then slot:

```json
{ "p1": { "P1": "jeff", "P2": "chuck" } }
```

Written the moment a pick changes: read, change only this profile's two slots, keep every other
key, write `players.json.tmp`, rename. Tests point `Roster.picks_path` at `user://` so they never
write the real one.

## 4. The chooser

In the lobby, on your podium, before you ready up: left / right (stick, D-pad, keys) swaps your
character (squash, poof, pop, name bounce, bark or the `char_swap` cue), skipping the other
player's pick. A readies and locks it, B unlocks. Solo: Select switches which podium the pad
drives. Details and the per-game notes: `docs/ui.md` "The character chooser", "Per game".

### Chooser voice (launcher)

Kaden, 2026-11-10: "when a character is up on the screen, I'd like it to say its catchphrase
once. Give a little audio cue of who they are." Same behaviour as the template's lobby
(`openjar-template` `docs/ui.md` "Chooser voice"), in the hub's in-line chooser (`hub.gd`):

- **Each step** (Select / Tab / `/` that changes the character) plays the swap sound
  (`CHANGE_SOUND`, `intro_pop`) and the swap animation at once. It no longer barks.
- **`SAY_SETTLE` = 0.3 s** after the step **has landed**, the character now shown says its
  catchphrase, **once**, on that player's own voice (`Roster.catchphrase(id, p)`). The launcher's
  chooser ignores presses mid-swap (0.39 s, longer than the settle), so the settle only counts
  once the Jarling's swap animation is done; otherwise every step would speak. Pressing again
  inside the settle restarts it, so fast scrolling says only the one you stop on; standing still
  says nothing more; every settled step speaks.
- **P2 joining** and **a profile swap (B)** show a new character: they say it after the same settle.
- **P2 leaving** and **the launch** cancel a pending line. A head shake (nobody free) says nothing.
- **The line**: the character's `voice/catchphrase.ogg`; without one a random bark; neither (Jeff,
  Chuck, Bloom, Old Reel in `v0.5.0`): nothing more, the step's swap sound already sounded.
- The log says what played when: `Chooser voice: P1 boxbot res://.../catchphrase.ogg (t=5.83 s)`.
- **One voice call.** `Roster.say(player, id, path, on = null)` is the only thing that plays a
  character line: the chooser's catchphrase / bark, the intro's landing barks (`HubIntro._say`, on
  one of its 3 crowd voices, so never more than 3 at once; no voice: a `ui_move` tick) and the
  launch shouts (`hub.gd` `shout()`). Every line emits `Roster.said` and sets `last_said`.
- Tests: `tests/test_chooser_voice.gd` (fixture roster `tests/fixtures/roster_voice.json`, voice
  files in `tests/voice_fixture/`, outside the `.gdignore`d `tests/fixtures/`).

## 5. Spawning the pick in game

```gdscript
var who := Roster.info(Roster.pick(player))
var body: Node3D = load(who.glb).instantiate()   # pixel game: a Sprite2D with texture = load(who.pixel)
rig.add_child(body)
```

- **Spaceballs**: the kicker rig loads `who.glb` under `jarling_rig.gd`; gear equips on any
  standard body; podium scene gets `set_character(id)`.
- **Junk Yard Zap**: the zapper rig loads `who.glb`; JYZ tools go in the standard gear slots.
- **The Hill**: pixel game; `who.pixel` on the podium and as the player's front sprite.

Player colours (`Players.COLOR`) stay with the slot: rings, arrows, HUD, glows. Never colour a
character green or red to mean a player.
