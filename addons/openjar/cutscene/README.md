# cutscene: CutscenePlayer

Data-driven cutscenes: letterbox, camera moves, walking/hopping actors, a voiced line with a
picture bubble per beat, items passed between actors, fades, host calls; A skips (state-changing
steps still run). Game-agnostic: no autoload is named in code; the game implements a duck-typed
host. Format, host interface and API: the addon's `docs/cutscene-format.md`.

* `cutscene_player.gd`: `CutscenePlayer` (Control). Needs `picto_bubble/`.
* `demo/`: `sample.json`, `sample_lines.json`, `cutscene_demo.tscn` (a minimal host).

```gdscript
CutscenePlayer.scene_dir = "res://data/cutscenes/"      # the defaults; change before play()
var cp := CutscenePlayer.new()
cp.host = self                                          # implements cutscene_actor, cutscene_lock, ...
$CutsceneLayer.add_child(cp)                            # a CanvasLayer above the game
cp.finished.connect(func(id, skipped): ...)
cp.play(&"intro", {"focus": "p1"})
```

From The Hill's `scripts/gameplay/cutscene_player.gd` (origin/dev 4f38a74). Tests:
`tests/project/suites/test_cutscene.gd`.
