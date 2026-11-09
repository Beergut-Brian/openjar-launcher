# Launcher look: how to reproduce it

No generative model was used for the launcher. The whole look is drawn from code, so the "prompt
pack" is the generator:

```
python3 art/gen/build.py        # Python 3 + Pillow; ~15 s
```

It rebuilds every launcher PNG and SVG, `scenes/ui/theme.tres`, the shader materials, the visual
`scenes/launcher/*.tscn` files and the mock screens, all from the palette named in
`art/gen/config.py` (one line). To try palette A or B, change `PALETTE` to `"candy_pop"` or
`"warm_toybox"` and re-run. The fixed colours (player green/red, Jeff/Chuck costume colours) come
straight from the palette JSON, unchanged.

## Style rules the code follows

- Flat vector shapes, no gradients inside shapes. Sky = five flat tiers, darkest at the top.
- "Sticker" outlines: every group of touching parts gets one merged ink outline
  (`Scene.outlined()` draws all outlines first, then all fills).
- Outline weight: about 4.5% of an object's height (jar), 7 px on 240 px figures, 14 px on faces.
- Round caps and joins everywhere; letters are thick round strokes with a cloud-white shine dot
  and a drop shadow in the darkest sky tier.
- Dark costume parts (Chuck's hat and shirt) get an inner rim line in the palette's slate (stone).
- Squash-and-stretch on everything that moves: intro AnimationPlayer keys, bobbing floaters
  (`assets/shaders/bob.gdshader`).
- Only the logo has text. Everything else is shapes, icons and colour.

## Files

| Generator | Makes |
| --- | --- |
| `art/gen/vec.py` | the shape kit (SVG + Pillow from the same points) |
| `art/gen/letters.py` | the wordmark letters (O P E N J A R G M S B C) |
| `art/gen/logos.py` | jar icon, logo options A/B/C |
| `art/gen/sprites.py` | Jeff/Chuck stand-ins, faces, dev badge, card tiles, sky layers, glow ring |
| `art/gen/scenes.py` | intro / card / picker scenes, background nodes, AnimationPlayer keys |
| `art/gen/mocks.py` | Pillow mock screens of the launcher (no display here) |
