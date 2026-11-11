# picto_bubble: PictoBubble

Wordless picture speech bubbles drawn from a CanvasItem's `_draw()`: a rounded paper panel, a
tail down to the speaker, a row of pictures (procedural, no textures). Static helpers only.

```gdscript
func _draw() -> void:
	PictoBubble.draw(self, head_screen_pos, [&"shovel", &"face_happy"], alpha, scale)
	PictoBubble.picture(self, &"heart", centre, 22.0)            # one picture in a box of side 22
PictoBubble.size_for(n_pictures, scale) -> Vector2
```

Built-ins (`PictoBubble.BUILTIN`): shovel, heart, house, star, question, face_sheepish,
face_hopeful, face_happy, tree, rock, exclaim, zzz, sparkle, hardhat. Unknown ids draw a gold dot.

A game adds its own once at boot:

```gdscript
PictoBubble.register(&"deed", func(ci: CanvasItem, id: StringName, c: Vector2, s: float, a: float) -> void:
	var u := s / 22.0          # one design unit; pictures are drawn on a 22-unit box
	ci.draw_circle(c, 6.0 * u, Color(1, 0, 0, a)))
PictoBubble.register_prefix("vehicle:", func(ci, id, c, s, a) -> void:
	PictoBubble.texture_picture(ci, load("res://.../%s.png" % String(id).get_slice(":", 1)), Rect2(), c, s, a))
PictoBubble.has_picture(id)    # built-in or registered
```

Colours: `OUTLINE` 3a2a44, `PAPER` fffaf0, `GOLD` ffd23f, `PINK` ff8fb1, `SKIN` ffd9a8.
From The Hill's `scripts/gameplay/picto_bubble.gd` (origin/dev 4f38a74); its Hill-only pictures
(wall, ice, shaken_hill, deed, shaft, ruin:/home:/vehicle: sprites) are the game's to register.
Tests: `tests/project/suites/test_picto_bubble.gd`.
