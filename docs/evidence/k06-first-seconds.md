# K-06 findings: the hub's slow first seconds on the GTX 1060 (launcher-k06-1, 2026-11-18)

## 1. What the box numbers show

The per-window lines in the brief (t=5 fps 102 / low1 48, t=10 87 / 55, t=15 83 / 54, then ~120 / ~100)
are word for word the **2026-11-17** run (`~/openjar/box-bench/out/launcher-bench-2026-11-17.out`,
`avg=112.6 low1=56.9 frames=6756`). They cannot come from the 2026-11-18 4K run: `frames=4477` in 60 s
is an average of 74.6 fps, and 15 s at ~90 plus 45 s at ~120 would be about 6750 frames. This worktree
has no copy of the 11-18 log, so its windows are unknown. Below, "the box run" means 11-17.

From the 11-17 windows (timed seconds; wall = timed + the 2 s warm-up; the hub's first frame comes just
before the warm-up starts):

| window (timed) | fps | mean ms | max ms | low1 |
| --- | --- | --- | --- | --- |
| 0-5   | 102.3 | 9.77  | 33.55 | 48.3 |
| 5-10  | 87.2  | 11.47 | 19.07 | 54.7 |
| 10-15 | 82.7  | 12.09 | 19.43 | 54.1 |
| 15-20 | 119.9 | 8.34  | 10.63 | 102.7 |
| 20-60 | 119.9 | 8.34  | 10.3-11.3 | 94-105 |

- Vsync is on (`high`), and the steady 8.34 ms says the output ran at 120 Hz.
- From 5 s to 15 s there is **no hitch**: the worst frame is 19 ms. What there is: about half the frames
  miss the 8.33 ms vblank and take 16.7 ms (a mean of 11.5 to 12 ms fits about 40 to 45 % of frames
  taking two vblanks). The GPU draws the same picture a bit **slower** for about 15 s, then at once it is
  fast enough again (from 15-20 the worst frame is 10.6 ms).
- The only real hitch is in 0-5: one or a few frames up to 33.6 ms.
- The 1%-low of the whole run is the worst 68 of 6756 frames. Nearly all of them are those 16.7 to 19 ms
  frames from the first 15 s, so low1 lands at 56.9 (about 17.6 ms). Without the slow phase it would be
  about 95.

So the slow phase is "each frame takes a bit too long for 15 s", not "a few long stalls". That rules out
the ordinary first-use costs as the main cause: a mesh, texture, sound or particle load on the main
thread shows up as a few long frames, not as 15 s of frames that are each 1 to 4 ms too slow.

## 2. What the launcher does in those seconds (measured here)

New opt-in tracer `--bench-trace` (`scripts/hub/bench_trace.gd`, class `BenchTrace`). Every second
it prints the pipeline compilations Godot counted (by kind), draw calls, primitives, objects, the
render CPU and GPU time, and the time all `_process` calls took that frame (the hub's own CPU work,
without the wait for the GPU). It also prints every frame over 20 ms. The lines start with `TRACE`, so
the box script's `grep BENCH` never sees them. It changes nothing the bench measures.

Local runs, Forward+ on lavapipe (software GPU), `hub_8` fixture, `--bench --graphics=high --bench-trace`,
user data in `.scratch/xdg`. The logs are `.scratch/trace-local-{1,2,3,4}.txt` (1 = cold shader cache,
2 to 4 = warm).

Hub setup steps, from engine start (warm run 4): `ready 1091, characters 1429 (+338), jars 1687 (+258),
first frame 4787 (+3100)`. Every setup step is finished **before** the first frame. The first frame is
driver pipeline work (lavapipe; see K-07).

Pipelines (Godot's own counters, the same whatever the GPU):

- 6 mesh pipelines before the hub's first frame (boot scene).
- **55 on the hub's first frame**: 28 surface, 26 specialization, 1 canvas.
- **0 after that**, in every run, for the full route (25 s in run 1, 20 s in runs 3 and 4): both ends of
  the row, the middle crossings, P2 joining, the first voice line, the residents and the fireflies.

The hub's own CPU work per frame (every `_process`, run 4):

- first frame 3.6 ms, then 1.3 to 1.7 ms in seconds 4 to 7 (P2 joins and the first voice line,
  `catchphrase.ogg`), then 0.4 to 0.6 ms for the rest of the run. Render CPU (culling and command
  building) is about 0.8 ms throughout.
- No frame does more than 3.6 ms of launcher work, and after the first second none does more than 1.7 ms.

Draw load grows a little as the two Jarlings walk apart and the camera widens (537 to 585 draw calls,
292k to 352k primitives). It is the same at second 30 as at second 10, so it cannot explain a slow
phase that ends at about 17 s.

## 3. Cause

The launcher's work in the first seconds is done by the first frame. The hub asks for no new
pipeline, loads nothing large and runs no heavy step after that. The slow phase on the 1060 is the GPU
drawing **the same frames slower** for about 15 s. The two engine or driver causes that fit:

1. **Godot's ubershader fallback** (4.4+, here 4.7.2). The 26 specialized pipelines the first frame
   asks for compile on worker threads, and until each one is ready Godot draws with the generic
   ubershader. That shader is slower on the GPU, and the compile threads take CPU time too. NVIDIA's
   compiler is slow on Godot's large scene shaders, so 55 pipelines on a few threads taking about 15 s is
   believable. When the last one is in, frames go straight back to 8.3 ms, which matches the cliff
   between the 10-15 and 15-20 windows. This is fast only when the Vulkan pipeline cache
   (`user://vulkan/pipelines.*.cache`, printed as `Startup PSO cache (N MiB)` with `--verbose`) is warm.
   On a lavapipe run here it is always 0.0 MiB, so this can't be tested on this machine.
2. **GPU clocks ramping** (NVIDIA PowerMizer) at the start. This is less likely, because a ramp-up would
   make frames get faster, not slower then fast at once.

Both are outside the launcher's code. As the brief says, I am stopping here and reporting, not
widening the change.

The 0-5 window's single 33 ms frame fits the same picture: an early frame that waits on a pipeline the
ubershader path can't cover, or the first voice line's stream starting up. The tracer prints that frame
with its pipeline count and its CPU time.

## 4. What was not done, and why

- No prewarm pass. The pipelines are already requested on the hub's first frame, so a throwaway pass
  during boot would start the same background compiles at most about 1 s earlier. It would not shorten
  a 15 s compile. Holding the picture until the compiles finish would change what the kid sees and
  would add to cold start (K-07), and Godot has no API that reports when the background compiles are
  done.
- No change to `data/graphics.json`, the bench, its route, warm-up or maths, NS-1..3 or the emulator jar.

## 5. What the box trace will settle (one run, two if the first is slow)

Run the bench with `--verbose --bench-trace` twice, back to back (command in `handoff/REPORT.md`):

- `Startup PSO cache (N MiB)`: 0 or small on run 1 and larger on run 2 means the cache is being saved.
  Then run 2 should be smooth from the start. If it is, the hitch only happens on a cold cache. The
  launcher's lever would then be that the cache gets saved. The box service may never exit cleanly,
  and Godot otherwise saves only per `rendering/rendering_device/pipeline_cache/save_chunk_size_mb`,
  3 MB by default. That would be a one-line project setting for a follow-up, once the box shows it.
- `TRACE s=` lines in the slow seconds: `process_max_ms` around 1 ms and `pso=+0` while `gpu_ms` stays
  high and then drops at the cliff means the GPU or engine compile phase, as described above. A
  `pso=+N` later in the run, or a large `process_max_ms`, would point back at the launcher, at the
  second it happens.
- The 4K run (11-18) is a different question. With `canvas_items` stretch the 3D renders at the
  **window** size, so a 3840x2160 output draws 4x the pixels of 1080p. An average of 74.6 means
  steady-state 4K load, not a first-second hitch. K-06's bar is "at 1080p". At 4K on `high`, the fix
  would be a `scaling_3d_scale` (for example 0.5 to render 1080p and upscale). That is a `high` value
  change, which this lane was told not to make without asking. It is listed here for Gary and Kaden.
