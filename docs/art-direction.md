# Art direction

## House style (every Open Jar game)

The rendering technique changes per game; these rules do not.

- Chunky silhouettes readable from 10 feet. Every character identifiable by outline alone.
- Big faces, big eyes, exaggerated expressions. Emotion is the feedback channel.
- Saturated, high-contrast palette: 5 to 7 hues per game drawn from a master palette
  (Hermes proposes three, Kaden picks, unless Kaden specified one up front).
- Player 1 is green (`#3cc24a`), Player 2 is red (`#e4393c`), in every game, carried by the
  character's costume accents, not by a separate skin.
- Thick outlines or strong rim light so things pop off the background.
- Squash-and-stretch on everything that moves. Juice over fidelity.
- Zero on-screen text in gameplay. Icons, colour, sound and animation carry meaning.
- Humour is physical: wobbling, bonking, flying hats, exaggerated reactions.
- Nothing scary. Goofy enemies, pops and boings, no blood.

## Characters

Recurring characters come from `openjar-characters` (submodule at `addons/openjar/characters/`).
Each has a bible, a look sheet, a voice pack and prompt packs. Universal characters can be used
anywhere; player-locked characters (Jeff = P1, Chuck = P2) only on their side.
New characters are proposed in the design sprint and approved by Kaden before any art is made.

## This game

- Technique:
- Palette (file in `art/`):
- Reference feel:
- Characters used:
- Tile or model scale:
- Outline weight / rim light:

## Asset pipeline

- 2D sprites and textures: ComfyUI on the Proxmox GPU server with this game's prompt pack in
  `art/prompts/`. Clean and palette-snap before anything enters `assets/`.
- Pixel art: generated roughs cleaned in Aseprite; hero characters hand-drawn or heavily cleaned.
- 3D: image-to-mesh for props, cleaned in Blender; hero characters modelled or heavily cleaned.
  Export `.glb` with flat materials.
- Placeholders ship first: coloured boxes with the final size and pivot, named exactly as the
  final asset will be, so Gameplay never waits on Art.
- Every asset gets a line in `assets/CREDITS.md`. Generated art must not depict or imitate
  recognisable characters, brands or artists.
