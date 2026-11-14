# Open Jar Games (the launcher)

The front door to every Open Jar game on the living-room TV. One Steam tile, "Open Jar Games",
opens on Jar Island: a floating island at magic hour with one giant glass jar per installed game,
each holding a tiny animated world. You walk your character up to a jar and jump in; when the game
quits, you pop back out of the same jar.

Built in Godot 4 (`.godot-version`) by Hermes and the agent lanes. Design doc: `GAME.md`. What's
built and verified: `PLAN-STATUS.md` and `docs/launch-checklist.md`.

## Play

Either pad drives it; the first pad is player 1 (green ring), a second pad drops in as player 2
(red ring) by pressing a button or pushing the stick, and drops out by going away (unplugged or asleep).

| Input | Does |
| --- | --- |
| Left stick / D-pad (keys: WASD for P1, arrow keys for P2) | Walk anywhere on the island; all the way over runs |
| (walk up to a jar) | It comes into focus: a tick, the jar bounces, its lid lifts |
| A (Space; P2 Enter) | At a jar: jump in and play that game (the A button shows over your head). Anywhere else: a happy cheer |
| B (Shift; P2 Ctrl) | Solo: switch save profile (you become that profile's character). Two players: a cheer |
| Select / Back (Tab, or `/` for keyboard P2) | Change your character in place; it says its catchphrase |
| Hold LB + RB for 1 s | Show or hide the `(dev)` builds (their jars wear a charcoal lid), for this run only |
| Hold Start (Esc) 1.5 s | Quit to Steam. A door badge fills while held; a tap only ticks |
| Hold Start 2 s while Smash Party runs | Close it and come home (browser games have no quit a kid can reach) |

The first boot of each day plays the intro (the roster tumbles out of a big jar); A skips it.
The build's version (`vX.Y.Z`, the release tag) sits quietly in the bottom-right corner.

## Games it shows

Every `~/Games/openjar/<folder>/openjar.json` (or `$OPENJAR_ROOT/<folder>/`), written by each game's
release workflow. Format: `docs/contracts.md`, "Launcher". A game can ship its own jar world
(`store/jar.tscn` or `store/jar.glb`); without one it gets a generated diorama with its poster.
The launcher reads disk only, never the network. Smash Party (a browser game) is installed by
`kiosk/smash-party/install.sh`; see `docs/smash-party.md`.

## Run, test, export

```
godot --path .                                                                         # run it
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode   # tests
godot --headless --path . --export-release "Linux" build/game.x86_64                  # export
OPENJAR_ROOT=$PWD/tests/fixtures/hub_8 godot --path . -- --demo                        # demo tour, fixture jars
scripts/tools/shots.sh res://scenes/main.tscn 1,3,6 .scratch/shots                     # real frames (HUB_DEMO scripts: hub.gd)
scripts/tools/soak.sh 1800 .scratch/soak/soak.tsv 10                                   # 30-minute soak with a monitor log
```

On a `v*` tag, `.github/workflows/release.yml` tests, stamps the tag into `config/version`, exports,
writes `build/openjar.json` (`dev: true` for `-dev` tags) and attaches the zip to a GitHub Release.

## Players and colours

Player 1 is always green, player 2 always red; the rings stay with the player, whoever they are.
Characters come from `openjar-characters` (`data/roster.json`, `assets/characters/`, synced by
`scripts/tools/sync_characters.sh`); picks are shared with every Open Jar game and remembered per
profile. Asset credits: `assets/CREDITS.md`.
