## `-- --bench-trace`: what the renderer is doing while the hub runs (launcher-k06-1). Opt-in, for finding
## a frame-time problem on the box; it changes nothing the bench measures (BenchRun keeps its own clock and
## its own lines; these lines start with TRACE, so the box script's `grep BENCH` never sees them).
## Once a second for the first SECONDS s (then every 5 s):
##   TRACE s=3 frames=118 ms=8.47 max_ms=19.1 slow=0 process_max_ms=0.9 pso=+4 (canvas 0 mesh 0 surface 0 draw 0 spec 4) draws=212 prims=180311 objs=96 cpu_ms=1.20 gpu_ms=6.81
## and every frame over SLOW_MS: `TRACE slow t=3.412 ms=24.5 process_ms=0.8 pso=+2 draws=212 cpu_ms=... gpu_ms=...`.
## pso = the pipeline compilations Godot counted (Performance.PIPELINE_COMPILATIONS_*): a frame drawn
## while a new pipeline is still compiling uses the slower ubershader, so they line up with slow seconds.
class_name BenchTrace
extends Node

const FLAG := "--bench-trace"
const SECONDS := 30.0
const SLOW_MS := 20.0
const KINDS := [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
		Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW,
		Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]

var lines: PackedStringArray = []
var _t0 := 0
var _last := 0
var _sec := 0
var _frames := 0
var _sum := 0.0
var _max := 0.0
var _slow := 0
var _proc_max := 0.0
var _pso_sec: Array[int] = [0, 0, 0, 0, 0]
var _pso_last: Array[int] = [0, 0, 0, 0, 0]
var _rid := RID()
var _frame_start := 0


static func wanted(args: PackedStringArray) -> bool:
	return args.has(FLAG)


## The pipeline compilations so far, by kind (canvas, mesh, surface, draw, specialization).
static func compilations() -> Array[int]:
	var out: Array[int] = []
	for k: int in KINDS:
		out.append(int(Performance.get_monitor(k)))
	return out


func _ready() -> void:
	name = "BenchTrace"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000   # after the hub, so a frame's own work is in its numbers
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	_t0 = Time.get_ticks_usec()
	_pso_last = compilations()
	get_tree().process_frame.connect(func() -> void: _frame_start = Time.get_ticks_usec())
	_say("TRACE start pso=%s (counts so far: canvas mesh surface draw spec)" % [str(_pso_last)])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0 if _last > 0 else 0.0
	_last = now
	var pso := compilations()
	var new := 0
	for i in pso.size():
		var d := pso[i] - _pso_last[i]
		_pso_sec[i] += d
		new += d
	_pso_last = pso
	var t := (now - _t0) / 1000000.0
	# every node's _process this frame (the tree's process_frame signal comes just before the first one,
	# this node runs last): the hub's own CPU work, without the wait for the GPU
	var proc := (now - _frame_start) / 1000.0 if _frame_start > 0 else 0.0
	_proc_max = maxf(_proc_max, proc)
	if ms > 0.0:
		_frames += 1
		_sum += ms
		_max = maxf(_max, ms)
	if ms > SLOW_MS:
		_slow += 1
		_say("TRACE slow t=%.3f ms=%.1f process_ms=%.2f pso=+%d draws=%d cpu_ms=%.2f gpu_ms=%.2f" % [t, ms, proc, new,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.viewport_get_measured_render_time_cpu(_rid),
				RenderingServer.viewport_get_measured_render_time_gpu(_rid)])
	var every := 1 if t < SECONDS else 5
	if int(t) >= _sec + every:
		_sec = int(t)
		var n := 0
		for v in _pso_sec:
			n += v
		_say("TRACE s=%d frames=%d ms=%.2f max_ms=%.1f slow=%d process_max_ms=%.2f pso=+%d (canvas %d mesh %d surface %d draw %d spec %d) draws=%d prims=%d objs=%d cpu_ms=%.2f gpu_ms=%.2f" % [
				_sec, _frames, _sum / maxf(_frames, 1), _max, _slow, _proc_max, n, _pso_sec[0], _pso_sec[1], _pso_sec[2],
				_pso_sec[3], _pso_sec[4], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.viewport_get_measured_render_time_cpu(_rid),
				RenderingServer.viewport_get_measured_render_time_gpu(_rid)])
		_frames = 0
		_sum = 0.0
		_max = 0.0
		_slow = 0
		_proc_max = 0.0
		_pso_sec = [0, 0, 0, 0, 0]


func _say(line: String) -> void:
	lines.append(line)
	print(line)
