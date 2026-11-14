# Open Jar Games (launcher)

> Build 0. The front door to every game on the TV. Born from `openjar-template`, shipped through
> the same Release pipeline, so it is also the template's first end-to-end test.

## Pitch
The TV box's home screen: the box boots straight into it, full screen, and a box service starts it
again if it ever exits (no Steam; producer note 2026-11-14 below). It opens on a big, loud, fun animation: the jar opens, the
roster of characters tumbles out (Jeff and Chuck for now), the logo lands with a thump. Then a
row of game cards. Pick one, it launches. When the game quits, you are back here.

## Players
- Either pad drives the launcher. No P1/P2 distinction here except the profile picker.
- Profile picker: two faces, no names. Picks which `--profile=` the game gets.
- You are your character: each held Jarling is that player's pick from the shared roster (the same
  picks every Open Jar game uses, remembered per profile). Change it in place with Select. Rings stay
  P1 green, P2 red, whoever you are.

## Controls
Kaden, 2026-11-10: "On the launcher, I want to be able to run around." The hub is free roam; there
is no shortcut that runs you to a jar.

| Input | Does |
| --- | --- |
| Left stick / D-pad / arrow keys | Walk anywhere on the island, any direction; all the way over runs |
| (walk up to a jar) | It comes into focus: `ui_move`, the jar bounces, its lid lifts and your pad lights |
| A | At a jar in focus: jump in and launch it. Anywhere else: a happy cheer |
| B | Solo: switch save profile (you stay put and become that profile's pick). Two players: a cheer |
| Select / Back (Tab or `/` on keys) | Change your character in place: poof, the next one pops out, its name over your head. Two players: the other's pick is skipped |
| Hold LB + RB for 1 s | Toggle showing the `(dev)` builds (their jars wear a dark lid). Every launcher start shows main-branch (stable) games only; the toggle lasts for that run (Kaden 2026-11-10) |
| Start (hold 1.5 s) | Opens the power menu: Back (focused), Sleep (a moon), Shut down (the power sign; hold A on it until its ring fills). Pictures, no words. B or a Start tap closes it. A badge with an open door shows while held and its ring fills; a tap only ticks. Never while Select is held (Select + Start is the games' solo gesture) |
| (P2's pad goes away) | P2 drops out: a "bye-bye" blip, their Jarling hops and tags along again |

## Core loop
Intro (skippable after first viewing) → profile picker (remembers last pick, one press to confirm)
→ card row → launch → on exit, back to the card row with the last card highlighted.

## Progression
None. The roster in the intro grows as `openjar-characters` grows; the card row grows as games
are installed.

## Camera
Fixed 2D UI at 1080p.

## Art direction
- Technique: 2D, flat vector shapes with the house-style thick outlines; the intro animation is
  Godot `AnimationPlayer` over sprites, not video. Characters in the intro are their library
  reference renders.
- Palette: the Open Jar master palette (the maker profile proposes three, Kaden picks). This is
  where the master palette is born.
- Cards: 600x900 grid art from each game's `store/grid.png`, a looping clip (`store/clip.mp4`)
  or animated art on highlight, a small dev badge when showing dev builds.
- Logo: "Open Jar Games" wordmark and a jar icon. Original design.

## Audio
- Intro: a short, loud sting (jar pop, tumble, logo thump). Characters bark as they land.
- UI: `ui_move`, `ui_confirm`, a soft loop under the card row.

## Lanes for this game
| Lane | Active | Definition of done |
| --- | --- | --- |
| Systems | yes | Reads `~/Games/openjar/*/openjar.json`, launches binaries with `--profile=`, returns on exit, remembers last card, dev toggle |
| Gameplay | no | |
| Design / Art | yes | Intro animation, logo, card layout, theme (which becomes the `openjar-addons` theme), profile faces |
| Content | no | |
| Audio | yes | Intro sting, UI cues, loop |
| Reviewer | yes | |

## First playable
Launcher boots on the TV (the box's home screen since 2026-11-14), shows the intro once, shows cards for whatever is
installed (Smash Party via its kiosk shortcut counts), launches one, comes back. Tag `v0.1.0`.

## Out of scope
- Downloading or updating games (that is `openjar-tv/update.sh`).
- Settings screens. There is nothing to set.
- Anything a kid has to read.

## Decisions made without Kaden
- 2026-11-14 (Gary): Select + Start held for 2 s is the playtest solo gesture of the games, so in the hub, while Select is held, Start does nothing: no quit, no other action, and the Select that came with it does not change the character. Quitting stays on Start held alone (or Escape). A Start press without Select is unchanged. While a command game runs, Select + Start is left to the game (the hub's home hold ignores it). Kaden can reverse this in chat.
- 2026-11-14 (Gary): FR-3 decided. In the hub the D-pad and stick only walk (the standing rule), so the D-pad never cycles the chooser; the chooser stays on Select, on the joined player's own pad. There is no ready state, so B has nothing to un-ready (A at a jar launches; B during a launch is a refusal). Kids never meet a menu, and the walking rule stays simple. Kaden can reverse this in chat.
- 2026-11-09 (Gary): a game without its own `jar` world keeps its poster as a small card behind the generated diorama, so games stay tell-apart-able until each ships its jar.
- 2026-11-09 (Gary): the spun-off lid landing on the other Jarling's head is a one-time joke; it's back on the jar when you return.
- 2026-11-09 (Gary): P1 keeps the profile Jarling they picked, P2 gets the other; the ring colour shows the player (green P1, red P2).
- 2026-11-09: palette check "green vs red under deuteranopia" is advisory, not a gate. The fixed P1/P2 colours are settled; they still differ by lightness and silhouette. Revisit only if a player turns out to be colour-blind.
- 2026-11-09: dark costume parts (Chuck's hat and shirt) get an inner rim line in the palette's stone colour, since no outline can contrast with near-black.
- 2026-11-09: launcher reads manifests from disk rather than calling GitHub; keeps it offline-safe.
- 2026-11-09: intro plays on the first boot of each local day only (date kept in the launcher's
  Save as `launcher.intro_date`), and A always skips it. This is the proposal from Open questions.
- 2026-11-09: card row clamps at the ends instead of wrapping; pressing past an end still plays
  `ui_move` and wobbles the end card, so the input is never silent.
- 2026-11-09: B on the card row opens the profile picker (B in the picker goes back). That is the
  only way back to the picker after boot.
- 2026-11-09: no games installed shows one empty grey card; A on it plays `ui_back` and wobbles.
- 2026-11-09: Start works from every launcher screen (intro, picker, cards), not only the card row.
  Ignored while a game runs. (It left the launcher then; since 2026-11-14 it opens the power menu, NS-1.)
- 2026-11-09: last card is remembered by `slug`, not position, so installs/removals do not shift it.
- 2026-11-09: while a game runs the launcher minimises its own window and restores it (fullscreen,
  foreground) when the game exits, so two fullscreen windows never fight for the TV. Switch:
  `MINIMIZE_WHILE_RUNNING` in `scenes/launcher/launcher.gd` (default `true`; `false` = only hide).
  It never touches the game's display mode. Untested on the TV.
- 2026-11-09: A in the profile picker holds the picked (happy) face for 0.35 s before the card row.
- 2026-11-09: fallback card tiles never repeat on neighbouring cards; a game keeps its own tile
  unless the card next to it already has it.

- 2026-11-10 (free roam): the stick is fully analogue; a small tilt walks slowly, most of the way walks
  at 4.4 m/s, and the last 15 % of tilt (or the D-pad / keys) ramps up to a 7 m/s run. Starting and
  stopping take about a tenth of a second, so it never feels icy.
- 2026-11-10 (free roam): a jar is in focus when you are within 1.7 m of the strip from its stand pad to
  the jar itself (so walking up to the front or bumping its side both count), and it stays in focus
  until you are 0.6 m further out, so it never flickers at the edge.
- 2026-11-10 (free roam): jars are solid. The row of plinths is one smooth curved wall you slide along,
  so running sideways along the row never gets stuck between two jars.
- 2026-11-10 (free roam): with the hop gone, nothing wobbles at the ends of the row any more; the
  island edge just stops you. `--demo` (and `HUB_DEMO=tour`) walks a tour from jar to jar, never pressing A.

- 2026-11-10 (chooser): the in-line character chooser is on **Select / Back** (View on an Xbox pad;
  Tab for keyboard P1, `/` for keyboard P2). Kaden: "It can just be a part of the ready up screen";
  the hub has no ready screen, so the chooser lives on your Jarling. A, B, Start and LB+RB are taken;
  X and Y are face buttons right next to A that a 5-year-old mashes, while Select is the small
  centre button that kids rarely press by accident. Each press is one step, presses during the
  0.4 s swap are ignored, so even mashing it never strobes. Read per pad, so one pad's Select never
  changes the other player.
- 2026-11-10 (chooser): solo, the tag-along friend is nobody's pick in play, so cycling onto its
  character trades with it (it becomes your old one). With two players the other's pick is skipped;
  with only two characters in the roster that means nobody is free: a head shake and a low sound.
- 2026-11-10 (chooser): a resident (Jeff, Chuck) who is the same character as either held Jarling
  is hidden, so nobody is on screen twice. With today's roster of two that hides both residents.
- 2026-11-10 (chooser): the hint ("Select  Change") fades in on the floor in front of your ring after
  you stand still for 1.4 s and vanishes when you move; the name tag shows for 1.5 s after a swap.
  Stand-in sound `intro_pop` until characters have recorded barks.
- 2026-11-10 (chooser): B (profile swap) keeps you where you stand and re-pops your Jarling as that
  profile's pick. Both profiles start as Jeff + Chuck, so until someone changes one, B looks like a
  pop in place.

- 2026-11-10 (gap-close): Start has to be **held 1.5 s** (was one press; since 2026-11-14 the hold opens the
  power menu, NS-1, where it used to leave the launcher). A
  five-year-old finds Start fast; a tap now only ticks and shows the door badge, which shrinks away on
  release. Mashing never adds up (each release starts over). Still ignored while a game runs. Kaden
  can ask for one-press back. This leaves three buttons that matter (stick, A, Select); B (a profile
  swap you undo with another B) and LB+RB (hidden, held) are harmless.
- 2026-11-10 (gap-close): the intro is the roster tumbling out of a big jar: the jar rattles, the lid
  pops, every playable character arcs out and lands in rows in front of it saying a happy bark (at most
  three voices at once; the last one says its catchphrase), the logo drops in with a thump, everyone
  cheers, then they hop back in and the jar poofs away into the hub's camera glide. About 8 s with 22
  characters; the stream speeds up as the roster grows so it stays under 9 s. First boot of the day
  only; A skips at any time. The logo is the Art lane's option A stand-in until Kaden picks (V-01).
- 2026-11-10 (gap-close): the chooser hint is a picture (the pad's small Select button next to round
  swap arrows in the player's colour), not words. With no pad, a Tab or slash keycap.
- 2026-11-10 (gap-close): the launching character shouts a bark as it leaps into the jar (ready, cheer
  or join) and another when it pops back out (win, join or cheer), on its player's voice.
- 2026-11-10 (gap-close-2): Smash Party (the browser game) is a jar until its Godot rebuild ships. It
  opens full screen in a kiosk browser window with a profile of its own (Chromium-family first, then
  Firefox), never the system browser, so closing the window is the game ending and the hub comes back.
  Install and details: `docs/smash-party.md`. Its jar holds a toy car looping past a crate stack.
- 2026-11-10 (gap-close-2): a browser game has no quit a kid can reach, so while one runs, holding
  Start for 2 s closes it and you come home (a short press is still the game's own pause). Godot
  games are never closed this way. Start still held when the hub comes back does not start the
  launcher's own quit hold.
- 2026-11-10 (launch-ready): when P2's pad goes away their Jarling hops and goes back to tagging along,
  with its own sound (`player_leave`, two falling blips), so dropping out is never silent. The chooser's
  swap has its own sound too (`chooser_swap`, a puff and a "ta!"), no longer the jar's `intro_pop`.
- 2026-11-10 (launch-ready): if the Start hold completes during the launch animation, the game is never
  started behind it (2026-11-14: the power menu opens and the jump is called off at GO; the Jarling pops
  back out).
- 2026-11-10 (launch-ready): the build's version (the release tag, stamped into `config/version` by
  release.yml) sits small and faint in the bottom-right corner, for grown-ups; local builds say
  `v0.0.0-local`. The dev builds' lid is charcoal and nearly matte, so it reads dark in the sunset.

## Producer note 2026-11-14: no Steam on the TV box (Kaden; supersedes the Steam tile sections)

Kaden, live chat 2026-11-14:

> "Steam will not run on the TV box. Only our games and some emulators."
> D1 a: no Steam, the box boots straight into the launcher. D2: "emulators through RetroDECK, as a jar
> in the launcher."

This supersedes every "Steam tile" and "quit to Steam" above and in `PLAN-STATUS.md` (C-01, C-15, K-02).
The launcher is the box's home screen: it starts at login, full screen, and a box service restarts it if
it ever exits. There is nothing to quit to, so:

- **NS-1, power menu.** Holding Start 1.5 s (the same hold and door badge) opens a small menu instead of
  quitting: **Back** (focused when it opens, so an accident is one A away), **Sleep** (a moon:
  `systemctl suspend`), **Shut down** (the power sign: `systemctl poweroff`, only after A is held on it
  1.5 s while a ring fills; let go early and nothing happens). Big round pictures, nothing to read. Left /
  right move, A picks, B or a fresh Start tap goes back; every press has a sound. Works on every launcher
  screen (intro, hub, mid-launch: the jump is called off), ignored while a game runs (K-02). The power
  calls go through one seam, `PowerActions` (`scripts/launcher/power_actions.gd`); test and demo runs are
  dry runs. Sleep closes the menu first, so the box wakes up in the hub.
- **Dev-only escape.** `--allow-quit` on the command line (or `OPENJAR_ALLOW_QUIT=1`) adds a fourth button
  (the badge's open door) that exits the process with code 0 and logs `launcher: dev quit`. For desktop
  testing only; never on the TV (the box service would start it again anyway).
- **NS-2, emulator jar.** RetroDECK is a jar: a manifest with `command` (e.g.
  `["flatpak", "run", "net.retrodeck.retrodeck"]`), no `binary`, and `"profiles": false`. It launches,
  hides the hub while it runs and brings it back when the process exits, exactly like a game, and the
  Start 2 s home hold closes it like any `command` game. `"profiles": false` means none of the launcher's
  own arguments are passed (no `--profile=`, no `--p1-char=` / `--p2-char=`), only the command and the
  manifest's `args`. With no `jar` of its own it gets the stock **Retro Games** world: a plain chunky game
  cartridge built from pixel blocks with a little pixel heart on its label, on a pixel-checker floor (no
  logos, no "RetroDECK", no words).
- **NS-3.** No "quit to Steam" left in the UI, hints or docs.

## Playtest 2026-11-12 changes (Kaden; these supersede the sections above)
Kaden: "Players should be able to walk around independently. Right now we're stuck together. Either
player can launch a game." and "Dev mode shows multiple versions of the game. It should only show the
dev version." (`playtests/2026-11-12.md`)

- **Each player walks on their own.** Every pad is its own player the moment it does anything: its
  first button press **or its first stick push** joins it (first pad P1 green, next P2 red). A kid who
  only ever pushes the stick still gets their own Jarling; two pads never drive the same one. Each
  Jarling moves on its own player's stick only: no tag-along, tether, leash or shared centre. The
  camera frames both wherever they are (it pulls back, it never pulls them in).
- **Nobody is pulled over.** Coming back from a game, the one who jumped in pops back out where they
  stood; the other player is never moved. The dev toggle moves nobody either.
- **Either player launches.** Whoever walks up to a jar and presses A jumps in and launches it, P1 or
  P2; the game gets that Jarling's profile and both players' picks, as before.
- **The Jarling nobody holds yet** (solo play, or P2's pad went away) stands and waits where it is,
  with no ring. It never follows, drags or blocks the active player. This replaces "tags along" in the
  Controls table and the decisions above; solo B (profile swap) and Select (trade with the waiting
  friend) work as before.
- **Dev view: one jar per game.** With LB+RB held 1 s, each game shows exactly one jar: its dev build
  (dark lid) if one is installed, else its stable build. Never two jars for the same game. A game is
  known by its manifest `slug` (CI gives both builds the repo name; a hand-written dev slug ending
  `-dev` counts as the same game). The toggle still lasts for one launcher run only.

## Open questions
- Logo and jar design: Kaden approves the Art lane's three options.
- Should the intro play every boot or only the first boot of the day? Proposal: first boot of the day, skippable always.
