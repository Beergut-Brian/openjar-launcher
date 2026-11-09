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

- **Poster inside:** the game's `store/grid.png` (600x900) on a standing card, unshaded and
  slightly emissive, so it reads at dusk and blooms a little. No text is added by the hub.
- **No art yet:** a chunky toy shape (ball, ring, wedge and friends) in a palette colour
  spins slowly in the jar instead; neighbours never share a toy.
- **Accent:** lid, glowing base disc and jar light take the poster's dominant colour.
- **Dev build:** dark slate lid with an amber beacon bulb on top. Only present after the
  grown-up combo (hold LB+RB 1 s).
- **Idle:** the poster bobs and sways a few degrees inside the glass; a toy spins.
- **Focused** (a Jarling stands on its pad): lid lifts and tilts, beam of light rises, jar light
  doubles, pad ring fills with **that player's colour**, jar does a squash-and-stretch bounce, a
  sound plays.
- **Launch:** Jarling cheers, arcs up and drops into the jar mouth, jar flashes white, the game
  starts. **Return:** Jarling pops out, jar bounces.

## Interaction flow

1. Boot straight into the island: no logo screen, no menu. Wide shot, music, the Jarling you
   were last time is already standing at the jar you last played. **A at once = play again.**
2. **Stick left/right = hop to the next jar** (a quick dash with a squash; hold to keep hopping;
   a wobble at either end). This is the five-year-old path: flick, flick, A.
3. **Any other stick direction = walk freely.** Walk near a jar and it opens for you.
4. **A:** at a jar → jump in and launch. Anywhere else → a happy cheer hop (never nothing).
5. **B (solo) = be the other Jarling.** That is the profile pick: two characters, no names. The
   other Jarling tags along behind you as a friend. Remembered for next time; the Jarling that
   jumps in decides which save the game opens (`--profile=p1|p2`).
6. **Second controller presses anything:** the tag-along friend becomes Player 2 on the spot
   (P1 is Jeff with the green ring, P2 is Chuck with the red ring). Either can launch.
7. **Start:** back to Steam. **LB+RB held 1 s:** dev jars appear / disappear.

Every one of these plays a sound (`ui_move`, `ui_confirm`, `ui_back`, `ui_toggle`, `launch`,
`player_join`) and moves something.

## Performance plan (60 fps, 1080p, GTX 1060, Forward+)

Budget 16.6 ms. Expected cost on a 1060, by reasoning (not yet measured on the target):

| Item | Count | Reasoning |
| --- | --- | --- |
| Triangles | about 150 to 200 k | two Jarlings at about 30 k each are the bulk; jars are 1.5 k lathes; trees and clouds are low-segment spheres. A 1060 draws several million per frame at 60 |
| Draw calls | about 250 with 8 jars | bulbs are one MultiMesh, fireflies one CPUParticles3D; opaque set meshes could be merged later if needed |
| Shadows | 1 directional, 2 splits, 4096 atlas | the single biggest cost, about 1.5 to 2 ms; everything else is shadowless |
| Lights | 2 directional + up to 10 small omnis | omnis are clustered, range 7, no shadows, each touches few pixels |
| Transparency | jar glass (8), beams (1 to 2), pads | one layer each, no refraction, no screen-texture read |
| Post | glow + ACES + depth/height fog | about 1 ms; fog is the analytic kind, not volumetric |
| MSAA | 2x | glass edges and string lights need it; about 1 ms |
| Sky | static shader | no `TIME`, so the radiance map is built once at boot |
| Skinning | 2 skeletons | negligible |

Total estimate: 5 to 7 ms GPU, leaving more than half the frame spare. If a profile on the real
box says otherwise the order to cut is: shadow atlas 4096 → 2048, MSAA off + FXAA, omni count.
Cold start: no threaded loading needed; jar posters are loaded straight from disk
(`Image.load_from_file`, 600x900 each). The hub prints `launcher: interactive ... after N ms`.

## What next, with more time

- **Jars that show the game, not just its poster:** `hero.png` as a banner flag on the lid and
  `clip.mp4` playing inside the focused jar.
- **A crowd:** three or four generic Jarlings from the avatar kit (`build_jarling.py --seed N`)
  wandering, sitting on the island edge, waving when you pass.
- **More than 10 games:** a second, raised terrace behind the first arc (the layout maths already
  isolates this in `HubLayout`); today 9+ jars start to crowd.
- **Launch moment:** camera dives into the jar after the Jarling, white-out, then the game.
- **Life:** jar lids rattle now and then for a game you have not played in a while; kites; a
  slow day-to-night drift across a play session; a hot-air balloon that carries new installs in.
- **Sound:** footsteps on stone vs grass, a glassy "tunk" for jars, per-jar hum on focus, Jarling
  barks from the voice packs.
- **Kid test:** watch a real 5-year-old; tune hop speed, the sideways-push threshold and whether
  B-to-swap is discovered without help.
