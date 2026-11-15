## `-- --bench`: the built-in benchmark (launcher-igpu-1). The hub plays ROUTE, a fixed two-player walk
## that keeps both Jarlings at opposite ends of the jar row most of the time, so the one camera stays on
## its widest shot (the whole plaza, every jar, the residents, the fireflies: the busiest picture the hub
## has), and crosses them over the middle in between. After WARMUP s (shaders, the first sounds) it
## times SECONDS s of real frames (wall clock, not the engine's clamped delta), prints a line every
## REPORT_EVERY s and a final summary, then quits with code 0:
##   BENCH t=5 fps=58.9 low1=44.1 ms=16.98 max_ms=24.70
##   BENCH avg=58.7 low1=43.0 tier=low frames=3522 seconds=60 adapter=Mesa Intel(R) HD Graphics 530 (SKL GT2) (Intel)
## low1 = the 1% low: 1000 / the mean of the slowest 1% of frame times. `--bench-seconds=N` shortens it
## (tests). Picks go to the demo file, power is a dry run (a scripted run, see hub.gd).
class_name BenchRun
extends Node

const FLAG := "--bench"
const SECONDS_FLAG := "--bench-seconds="
const SECONDS := 60.0
const WARMUP := 2.0
const REPORT_EVERY := 5.0
## Two players; every 6 s they swap ends of the row (jar 0 and the last jar: go clamps 99 to it),
## with a middle crossing in between. Times are from the hub's start (the bench never plays the intro).
const ROUTE := "follow;0.2:p2;0.4:go:0;0.4:go2:99;6:go:99;6:go2:0;12:go:2;12:go2:3;15:go:0;15:go2:99;" \
		+ "21:go:99;21:go2:0;27:go:0;27:go2:99;33:go:3;33:go2:2;36:go:99;36:go2:0;42:go:0;42:go2:99;" \
		+ "48:go:99;48:go2:0;54:go:1;54:go2:4;57:go:0;57:go2:99"

signal finished(summary: String)

var seconds := SECONDS
var warmup := WARMUP
var tier := ""
var adapter := ""
var lines: PackedStringArray = []       # everything printed, for tests
var summary := ""
## How the run ends; tests swap in their own. Default: Audio.quit(0).
var quit_fn: Callable
var _hub: Node
var _last_usec := 0
var _t := 0.0                           # timed seconds so far (after the warm-up)
var _warm := 0.0
var _next_report := REPORT_EVERY
var _all: PackedFloat32Array = []
var _window: PackedFloat32Array = []
var _done := false


static func wanted(args: PackedStringArray) -> bool:
	return args.has(FLAG)


static func seconds_from(args: PackedStringArray) -> float:
	for a in args:
		if a.begins_with(SECONDS_FLAG):
			return maxf(0.1, float(a.trim_prefix(SECONDS_FLAG)))
	return SECONDS


## {avg, low1, ms, max_ms} for frame times in ms. avg = frames / time; low1 = 1000 / mean of the worst 1%.
static func stats(ms: PackedFloat32Array) -> Dictionary:
	if ms.is_empty():
		return {"avg": 0.0, "low1": 0.0, "ms": 0.0, "max_ms": 0.0}
	var total := 0.0
	for m in ms:
		total += m
	var sorted := ms.duplicate()
	sorted.sort()
	var n := maxi(1, int(ceil(sorted.size() * 0.01)))
	var worst := 0.0
	for i in n:
		worst += sorted[sorted.size() - 1 - i]
	worst /= n
	var mean := total / ms.size()
	return {"avg": 1000.0 / mean if mean > 0.0 else 0.0, "low1": 1000.0 / worst if worst > 0.0 else 0.0,
			"ms": mean, "max_ms": sorted[sorted.size() - 1]}


func setup(hub: Node, run_seconds: float = SECONDS) -> void:
	_hub = hub
	seconds = run_seconds
	name = "Bench"
	process_mode = Node.PROCESS_MODE_ALWAYS
	tier = str(hub.get("graphics_tier")) if hub and hub.get("graphics_tier") != null else GraphicsTier.current
	adapter = GraphicsTier.adapter_text()
	if not quit_fn.is_valid():
		quit_fn = func() -> void: Audio.quit(0)


func _ready() -> void:
	_say("BENCH start tier=%s seconds=%d warmup=%.0f adapter=%s window=%s" % [tier, roundi(seconds), warmup,
			adapter, str(get_viewport().get_visible_rect().size) if get_viewport() else "?"])


func _process(delta: float) -> void:
	if _done:
		return
	var now := Time.get_ticks_usec()
	var ms := (now - _last_usec) / 1000.0 if _last_usec > 0 else delta * 1000.0
	_last_usec = now
	if _warm < warmup:
		_warm += ms / 1000.0
		return
	_t += ms / 1000.0
	_all.append(ms)
	_window.append(ms)
	if _t >= _next_report:
		var s := stats(_window)
		_say("BENCH t=%d fps=%.1f low1=%.1f ms=%.2f max_ms=%.2f" % [roundi(_next_report), s.avg, s.low1, s.ms, s.max_ms])
		_window = PackedFloat32Array()
		_next_report += REPORT_EVERY
	if _t >= seconds:
		_finish()


func _finish() -> void:
	_done = true
	var s := stats(_all)
	summary = "BENCH avg=%.1f low1=%.1f tier=%s frames=%d seconds=%d adapter=%s" % [s.avg, s.low1, tier,
			_all.size(), roundi(seconds), adapter]
	_say(summary)
	finished.emit(summary)
	if quit_fn.is_valid():
		quit_fn.call()


func _say(line: String) -> void:
	lines.append(line)
	print(line)
