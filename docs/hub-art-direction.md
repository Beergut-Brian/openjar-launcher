# Hub art direction: Jar Island at magic hour

Contestant: `feature/hub-fable52`. Screenshots: `handoff/shots/`. Report: `handoff/REPORT.md`.

## Concept

The launcher is a tiny grassy island floating above a sea of clouds at sunset, and **every game
you own is a giant glass jar** standing in a half circle on its stone plaza, with that game's
poster glowing inside like a firefly in a lantern. Your Jarling runs around the island; walk (or
hop) up to a jar and its lid lifts off, a beam of light shoots up and the ground ring turns your
colour; press A and your Jarling **jumps into the jar** and the game starts. When the game ends
the Jarling pops back out of the same jar. Open Jar Games, literally: the games live in jars and
you open one. Far off, more little islands with tiny glowing jars hint at games still to come.

## Mood words

Magic hour. Toy diorama. Lantern glow. Soft and round. Floating. Cosy, never empty. Bedtime-safe.

## Palette

| Role | Colour | Where |
| --- | --- | --- |
| Sky zenith | `#0D0F4D` indigo | top of the sky dome, a few stars |
| Sky high | `#45299E` violet | upper sky |
| Sky mid | `#EB548C` hot pink | band behind the trees |
| Horizon | `#FF9E4D` orange | horizon glow, far cloud tint |
| Sun | `#FFBD6B` | big soft disc, low behind the jars |
| Cloud light / shade | `#FFD1C2` / `#734DA8` | cloud sea and cloud puffs |
| Grass | `#4DA84D`, `#5CBD54` | island rings |
| Plaza stone | `#EDCCA8`, `#D1A899` | warm sandstone, catches the sun |
| Mosaic inlay | `#54C7DB` | ring target in the plaza centre (a quiet "stand here") |
| Leaves | `#2F9E5A` `#45B85C` `#6FCE52` `#38A86E` | sphere-cluster trees |
| String lights / toys | `#FFD23F` `#FF7AC8` `#5EF0C0` `#35B6FF` `#FF8A3D` `#A78BFF` | bulbs, fallback toys |
| Player 1 | `#3CC24A` green (exact) | P1 ground ring, the pad ring of the jar P1 stands at |
| Player 2 | `#E4393C` red (exact) | P2 ground ring, the pad ring of the jar P2 stands at |
| Dev jar lid | `#3A3F5C` slate + amber beacon | dev builds only |

Each jar takes its **accent colour from its own poster** (average of the saturated pixels), so the
lid, the glowing base and the jar's light all match the game. Green and red are reserved for the
players: nothing else in the scene uses those two exact colours as a glow.

## Lighting plan

- **Key:** one warm directional light (`#FFC48A`, energy 2.3) from behind the jars, so glass and
  Jarlings get a golden rim and long soft shadows fall toward the camera. The only shadow caster:
  2 PSSM splits, 36 m range, blur 2.6.
- **Sun disc:** drawn by the sky shader a little lower than the real light, so the sun sits in
  frame without the shadows getting long and blocky.
- **Fill:** one cool violet directional light (`#B9B4FF`, 0.75, no shadows) from the camera side,
  so faces are never dark.
- **Jar lights:** one small omni (range 7, no shadows) per jar in the jar's accent colour: the
  plaza in front of each jar is washed in that game's colour.
- **Ambient:** from the sky (static shader, radiance baked once), energy 1.0.
- **Post:** ACES tonemap, glow (bulbs, posters, pads, beam bloom), thin depth fog tinted pink plus
  height fog below the island so the cloud sea melts into the horizon.
- **Not used:** SDFGI, VoxelGI, SSAO, SSR, volumetric fog, any second shadow caster.

## Camera plan

- **Boot (2.6 s):** wide establishing pose, high and back `(0, 10.5, 27)`, FOV 52: the whole
  island, cloud sea and far islands. Input already works during it.
- **Play:** glides down into a low follow camera behind the lead Jarling (FOV 46), looking toward
  the jar arc and the sun. Look-at leads toward the focused jar, so hopping feels like a pan.
- **Two players:** frames the midpoint and pulls back with the distance between them; nobody can
  leave the frame because the island edge stops them first.
- **Launch and return:** the camera holds its frame on the jar while the Jarling jumps in, and
  is in the same place when it pops back out (a push-in is on the wish list).
- No camera control for the player. No cuts. Nothing a 5-year-old can get lost in.

## Layout sketch

```
                         sun (low, behind the jars)
            far island                         far island
   ~~~~~~~~~~~~~~~~~~~~~~~ cloud sea ~~~~~~~~~~~~~~~~~~~~~~~~~

          tree   [3] [4]   tree            [n] = game jar on a plinth
        [2]    string lights   [5]          o  = pad ring where you stand
     [1]   o   o   o   o   o      [6]
   [0]   o                    o     [7]    jars: arc radius 8.5 m
   tree o        (( O ))         o  tree   pads: arc radius 6.2 m
                 mosaic                    step: min(24 deg, 150 deg / (n-1))
          stone plaza, radius 7.4
     grass rings out to radius 12.6        walk limit: radius 10.6
                  P1  P2
                 ^ camera (looks at the arc)
```

Jars are sorted by folder name, left to right. 1 game: one jar dead centre. 2 games: a pair.
8 games: the full half circle. 0 games: one sleepy empty jar (lid on, dim, toy-less) so the
island never looks broken; A makes it wobble.

## How a game looks

A **jar on a plinth**, 3 m tall, about three Jarlings high: readable from anywhere on the island.

- **A tiny world inside** (the idea is from the other hub entry, branch `feature/hub-opus`): each
  jar is a snow globe of its game, on a slow turntable. A game ships its own as `"jar"` in its
  manifest (`store/jar.glb` or a self-contained `store/jar.tscn`, see `docs/contracts.md`); the hub
  strips lights, cameras, sounds and scripts, fits it to the jar and loops its animation.
- **No `jar` yet:** a generated diorama, one of eight (meadow, space, ocean, volcano, forest,
  castle, snow, candy), picked from the slug so it never changes and neighbours never match, and
  coloured from the game's accent. No text. If the game has a `grid` poster it stands at the back
  of the diorama as a small backdrop card, so the game is still recognisable.
- **Neither:** the diorama alone, coloured from the slug.
- **Accent:** lid, glowing base disc and jar light take the poster's dominant colour.
- **Dev build:** dark slate lid with an amber beacon bulb on top. Only present after the
  grown-up combo (hold LB+RB 1 s).
- **Idle:** the world turns slowly; a little faster when a Jarling stands at the jar.
- **Focused** (a Jarling stands on its pad): lid lifts and tilts, beam of light rises, jar light
  doubles, pad ring fills with **that player's colour**, jar does a squash-and-stretch bounce, a
  sound plays.

### The launch moment (2.3 s, `LaunchSequence`)

"The top of the jar spins off and we jump inside of it." One clock, seven beats, one sound each;
everything on screen is posed from the clock, so it plays the same every time.

| Time | Beat | What you see | Cue |
| --- | --- | --- | --- |
| 0.0 | rattle | the Jarling crouches, the jar squashes, shakes and glows brighter, the lid chatters | `jar_rattle` |
| 0.5 | lid pop | the jar springs tall, the lid spins off high into the sky, the Jarling flinches | `intro_pop` |
| 0.8 | leap | stretch, a somersault over the rim, the camera tips up to follow | `jarling_jump` |
| 1.25 | lid lands | on the friend's head as a hat (or on the plaza if the friend is far away) | `lid_land` |
| 1.3 | splash | the Jarling drops through the mouth, shrinking; sparkles burst out | `jar_splash` |
| 1.45 | dive | it lands tiny in the world and waves; the camera goes over the rim and down after it; Jeff and Chuck cheer | `launch` |
| 2.3 | go | the tiny world fills the screen, a flash of the jar's colour, the game starts | (the game's own) |

A during the animation does nothing: the game starts once, on the last beat. Nothing is fast, dark
or loud enough to startle: the jar's glow settles as the camera goes in, and the flash is a pastel.

**Return:** the screen clears, the Jarling pops back out of the jar with sparkles (`jar_pop_out`),
lands on its pad, and the lid drops out of the sky and lands on the jar with a `lid_bonk`.

## Interaction flow

1. Boot straight into the island: no logo screen, no menu. Wide shot, music, the Jarling you
   were last time is already standing at the jar you last played. **A at once = play again.**
2. **Stick left/right = hop to the next jar** (a quick dash with a squash; hold to keep hopping;
   a wobble at either end). This is the five-year-old path: flick, flick, A.
3. **Any other stick direction = walk freely.** Walk near a jar and it opens for you.
4. **A:** at a jar → jump in and launch. Anywhere else → a happy cheer hop (never nothing).
5. **B (solo) = be the other Jarling.** That is the profile pick: two generic kit Jarlings, a
   grown-up (`p1`, blue cap) and a kid (`p2`, yellow bobble hat), no names. The other one tags
   along behind you as a friend. Remembered for next time; the Jarling that
   jumps in decides which save the game opens (`--profile=p1|p2`).
6. **Second controller presses anything:** the tag-along friend becomes Player 2 on the spot
   (P1 keeps the Jarling they picked, P2 holds the other; the ring under each is the player's
   colour, green for P1 and red for P2). Either can launch.
   **Jeff and Chuck** are player-locked characters, so they are never a profile: they live on the
   island as residents, Jeff on the left (P1's side) and Chuck on the right, and cheer when someone
   jumps into a jar or a second player joins.
7. **Start:** back to Steam. **LB+RB held 1 s:** dev jars appear / disappear.

Every one of these plays a sound (`ui_move`, `ui_confirm`, `ui_back`, `ui_toggle`, `player_join`,
and the launch cues above) and moves something.

## Performance plan (60 fps, 1080p, GTX 1060, Forward+)

Budget 16.6 ms. Expected cost on a 1060, by reasoning (not yet measured on the target):

| Item | Count | Reasoning |
| --- | --- | --- |
| Triangles | about 150 to 200 k | four Jarlings at about 30 k each are the bulk (two profiles, Jeff, Chuck); jars are 1.5 k lathes; a tiny world is a few hundred to 5 k (the contract's cap); trees and clouds are low-segment spheres. A 1060 draws several million per frame at 60 |
| Draw calls | about 400 with 8 jars (each tiny world is 10 to 25 small meshes) | bulbs are one MultiMesh, fireflies one CPUParticles3D; opaque set meshes could be merged later if needed |
| Shadows | 1 directional, 2 splits, 4096 atlas | the single biggest cost, about 1.5 to 2 ms; everything else is shadowless |
| Lights | 2 directional + up to 10 small omnis | omnis are clustered, range 7, no shadows, each touches few pixels |
| Transparency | jar glass (8), beams (1 to 2), pads | one layer each, no refraction, no screen-texture read |
| Post | glow + ACES + depth/height fog | about 1 ms; fog is the analytic kind, not volumetric |
| MSAA | 2x | glass edges and string lights need it; about 1 ms |
| Sky | static shader | no `TIME`, so the radiance map is built once at boot |
| Skinning | 4 skeletons | negligible |

Total estimate: 5 to 7 ms GPU, leaving more than half the frame spare. If a profile on the real
box says otherwise the order to cut is: shadow atlas 4096 → 2048, MSAA off + FXAA, omni count.
No SDFGI, no volumetric fog, no reflection probes, one shadowed light.

**What I would bake** once the island stops changing: the sun's shadows and bounce on the static
set (ground, plinths, trees, floating islets) into one LightmapGI, so the real-time shadow map only
has to cover the Jarlings and lids (one split, 2048); the trees, clouds and islets merged into one
mesh per material (about 150 fewer draw calls); and the eight jar omnis replaced by a baked glow
on the plinth plus emission, keeping a live omni only on the focused jar.

Cold start: no threaded loading needed; jar posters and jar worlds are loaded straight from disk
(`Image.load_from_file`, `GLTFDocument`), a few ms each at the contract's size cap. The hub prints `launcher: interactive ... after N ms`.

## What next, with more time

- **Jar worlds from the real games:** a Blender template and a one-page guide so each game's art
  lane can make its `store/jar.glb` in an afternoon; `clip.mp4` on the backdrop card of the focused jar.
- **A crowd:** three or four generic Jarlings from the avatar kit (`build_jarling.py --seed N`)
  wandering, sitting on the island edge, waving when you pass.
- **More than 10 games:** a second, raised terrace behind the first arc (the layout maths already
  isolates this in `HubLayout`); today 9+ jars start to crowd.
- **The lid hat:** let the friend keep wearing the lid until the game comes back.
- **Life:** jar lids rattle now and then for a game you have not played in a while; kites; a
  slow day-to-night drift across a play session; a hot-air balloon that carries new installs in.
- **Sound:** footsteps on stone vs grass, a glassy "tunk" for jars, per-jar hum on focus, Jarling
  barks from the voice packs.
- **Kid test:** watch a real 5-year-old; tune hop speed, the sideways-push threshold and whether
  B-to-swap is discovered without help.
